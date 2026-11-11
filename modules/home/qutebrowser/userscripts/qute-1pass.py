#!/usr/bin/env python3
"""Fill the current page's login form from 1Password.

qutebrowser has no browser-extension API (it is a QtWebEngine/Chromium
embedded browser), so the 1Password *browser extension* cannot be installed.
This userscript is the native equivalent: it queries the 1Password CLI (`op`)
and injects the chosen item's credentials into the page with `:jseval`.

Bound in the generated config.py as:

    config.bind("<Ctrl-Shift-p>", "spawn --userscript qute-1pass.py")
    c.aliases["1pass"] = "spawn --userscript qute-1pass.py"

so it can be triggered by key or typed as `:1pass` / `:1pass <title-or-url-fragment>`.

Requirements on PATH: `op` (1Password CLI v2 wired to the desktop app),
`wofi` (item picker), `wl-copy` (clipboard).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import urllib.parse

QUTE_URL = os.environ.get("QUTE_URL", "")
QUTE_FIFO = os.environ.get("QUTE_FIFO", "")

# Injected into the page. Kept as one line (qutebrowser commands are
# newline-delimited). React/Vue controlled inputs need the native value setter
# plus input/change events, otherwise the framework overwrites what we set.
FILL_JS = """(() => {
  const u = __USERNAME__, p = __PASSWORD__;
  const visible = (el) => {
    const s = el.ownerDocument.defaultView.getComputedStyle(el);
    return s.display !== 'none' && s.visibility !== 'hidden' &&
           s.opacity !== '0' && el.offsetWidth > 0 && el.offsetHeight > 0;
  };
  const set = (el, v) => {
    const d = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value');
    if (d && d.set) { d.set.call(el, v); } else { el.value = v; }
    el.dispatchEvent(new Event('input', {bubbles: true}));
    el.dispatchEvent(new Event('change', {bubbles: true}));
  };
  const inputs = Array.from(document.querySelectorAll('input')).filter(visible);
  const pw = inputs.find((i) => i.type === 'password');
  const user = inputs.find((i) =>
    i.type === 'email' || i.type === 'text' ||
    (i.getAttribute('autocomplete') || '').includes('username'));
  let n = 0;
  if (user && u) { set(user, u); n += 1; }
  if (pw && p) { set(pw, p); n += 1; }
  if (pw) { pw.focus(); }
  return n;
})()"""


SETUP_HINT = (
    'Enable "Integrate with 1Password CLI" in the 1Password app '
    "(Settings \u2192 Developer) plus Linux system authentication "
    "(Settings \u2192 Security), or run 'op account add' once in a terminal."
)

OP_TIMEOUT = 30

# NixOS installs the CLI as a setgid wrapper: the app integration socket is
# only accessible to the onepassword-cli group, and a plain `op` from the user
# profile can shadow the wrapper in GUI session PATHs.
NIXOS_WRAPPER = "/run/wrappers/bin/op"


def op_binary():
    """Resolve the 1Password CLI binary."""
    override = os.environ.get("QUTE_ONEPASS_OP")
    if override:
        return override
    if os.path.exists(NIXOS_WRAPPER):
        return NIXOS_WRAPPER
    return shutil.which("op") or "op"


def run(argv, stdin=None, timeout=OP_TIMEOUT):
    try:
        return subprocess.run(
            argv, input=stdin, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(
            argv, 124, "", "timed out after {}s (waiting for terminal input?)".format(timeout))


def accounts_configured(stdout):
    try:
        accounts = json.loads(stdout or "[]")
    except ValueError:
        return False
    return isinstance(accounts, list) and bool(accounts)


def fifo(command):
    """Send a command to qutebrowser."""
    if not QUTE_FIFO:
        print(command)
        return
    try:
        fd = os.open(QUTE_FIFO, os.O_WRONLY | os.O_NONBLOCK)
    except OSError:
        return
    try:
        os.write(fd, (command + "\n").encode())
    except OSError:
        pass
    finally:
        os.close(fd)


def notify(kind, text):
    # Single-quoted qutebrowser argument: strip the quote character instead of
    # trying to escape it through qutebrowser's command splitter.
    safe = text.replace("'", "\u2019").replace("\n", " ")
    fifo("message-{kind} '{text}'".format(kind=kind, text=safe))


def pick(choices):
    """Return the value for the chosen label, or None.

    One candidate is used directly; otherwise wofi is the picker.
    """
    if not choices:
        return None
    if len(choices) == 1:
        return choices[0][1]
    if not shutil.which("wofi"):
        return None
    labels = [label for label, _ in choices]
    proc = run(
        ["wofi", "--dmenu", "--insensitive", "--prompt", "1Password"],
        stdin="\n".join(labels),
    )
    selected = proc.stdout.strip()
    for label, value in choices:
        if label == selected:
            return value
    return None


def copy_to_clipboard(text):
    """Copy text, without waiting on wl-copy's forked daemon.

    wl-copy forks and the daemon inherits stdout; with a capture pipe that
    keeps the pipe open and the call never returns.
    """
    if not shutil.which("wl-copy"):
        return
    try:
        subprocess.run(
            ["wl-copy"], input=text, text=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        pass


def op_error(proc):
    lines = [line for line in (proc.stderr or "").strip().splitlines() if line]
    return lines[-1] if lines else "op exited with status {}".format(proc.returncode)


def host_of(url):
    try:
        return (urllib.parse.urlparse(url).hostname or "").lower()
    except ValueError:
        return ""


def sameness(a, b):
    a = a[4:] if a.startswith("www.") else a
    b = b[4:] if b.startswith("www.") else b
    return a == b or a.endswith("." + b) or b.endswith("." + a)


def item_matches(item, host):
    for url in item.get("urls") or []:
        item_host = host_of(url.get("href") or "")
        if item_host and sameness(item_host, host):
            return True
    return False


def main():
    if not QUTE_URL:
        notify("error", "1Password: no page URL")
        return 1
    host = host_of(QUTE_URL)
    if not host:
        notify("error", "1Password: cannot determine page host")
        return 1
    op = op_binary()
    if not (os.path.exists(op) if os.path.isabs(op) else shutil.which(op)):
        notify("error", "1Password: `op` CLI not found on PATH")
        return 1

    # `op item list` prompts for an account on the terminal when none is
    # configured, which a userscript cannot answer; check first instead.
    accounts = run([op, "account", "list", "--format", "json"], timeout=15)
    if accounts.returncode != 0 or not accounts_configured(accounts.stdout):
        notify("error", "1Password: the CLI has no account configured.")
        notify("info", SETUP_HINT)
        return 1

    listed = run([op, "item", "list", "--categories", "Login", "--format", "json"])
    if listed.returncode != 0:
        notify("error", "1Password: " + op_error(listed))
        return 1
    try:
        items = json.loads(listed.stdout or "[]")
    except ValueError:
        notify("error", "1Password: could not parse `op item list` output")
        return 1

    matches = [item for item in items if item_matches(item, host)]
    pool = matches or items

    # `:1pass <text>` (alias) passes the text as argv — filter by title or URL.
    query = " ".join(sys.argv[1:]).strip()
    if query:
        needle = query.lower()
        pool = [
            item
            for item in items
            if needle in (item.get("title") or "").lower()
            or any(
                needle in (url.get("href") or "").lower()
                for url in item.get("urls") or []
            )
        ]
        if not pool:
            notify("error", '1Password: no item matches "{}"'.format(query))
            return 1

    choices = []
    for item in pool:
        title = item.get("title") or item.get("id") or "?"
        vault = (item.get("vault") or {}).get("name") or ""
        label = "{} [{}]".format(title, vault) if vault else title
        choices.append((label, item.get("id")))

    item_id = pick(choices)
    if not item_id:
        notify("info", "1Password: no item selected")
        return 0

    got = run([op, "item", "get", item_id, "--format", "json"])
    if got.returncode != 0:
        notify("error", "1Password: " + op_error(got))
        return 1
    try:
        item = json.loads(got.stdout)
    except ValueError:
        notify("error", "1Password: could not parse `op item get` output")
        return 1

    fields = {}
    for field in item.get("fields") or []:
        key = field.get("id") or field.get("label")
        if key:
            fields[key] = field.get("value")

    title = item.get("title") or item_id
    username = fields.get("username") or ""
    password = fields.get("password") or ""
    if not password:
        notify("error", '1Password: no password field in "{}"'.format(title))
        return 1

    js = FILL_JS.replace("__USERNAME__", json.dumps(username))
    js = js.replace("__PASSWORD__", json.dumps(password))
    fifo("jseval " + " ".join(js.split()))

    copy_to_clipboard(password)

    otp = run([op, "item", "get", item_id, "--otp"])
    if otp.returncode == 0 and otp.stdout.strip():
        copy_to_clipboard(otp.stdout.strip())
        notify("info", '1Password: filled "{}" \u2014 2FA code copied to clipboard'.format(title))
    else:
        notify("info", '1Password: filled "{}" \u2014 password copied to clipboard'.format(title))
    return 0


if __name__ == "__main__":
    sys.exit(main())
