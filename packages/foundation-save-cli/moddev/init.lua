-- moddev/init.lua
-- Foundation runtime Lua TCP server for foundation-save-cli
-- Gives the CLI remote code execution in the running Foundation game.
--
-- Protocol (line-based, newline-terminated):
--   PING              → PONG <game_version>
--   EVAL <b64 code>   → OK <b64 result> | ERR <b64 error>
--   QUIT              → (disconnect, no response)
--
-- Requires luasocket (bundled with Foundation for ZeroBrane Studio).

local socket = require("socket")
local mime   = require("mime")

local HOST = "127.0.0.1"
local PORT = 27105

-- ── helpers ───────────────────────────────────────────────────

local function b64(s)   return (mime.b64(s, #s)) end

local function unb64(s)
    return (mime.unb64(s:gsub("%s+", "")))
end

local function eval(code)
    local fn, err = loadstring(code)
    if not fn then return nil, err end
    local ok, val = pcall(fn)
    if not ok then return nil, val end
    return tostring(val) or "nil"
end

-- ── client handler ────────────────────────────────────────────

local function handle(client)
    client:settimeout(5)
    local line, err = client:receive("*l")
    if not line then client:close(); return end

    local cmd, arg = line:match("^(%S+)%s*(.*)$")
    cmd = cmd or line
    arg = arg or ""

    if cmd == "PING" then
        local ver = (Game and Game.version) or "unknown"
        client:send("PONG " .. tostring(ver) .. "\n")

    elseif cmd == "EVAL" then
        local code = unb64(arg)
        if code == "" then
            client:send("ERR empty\n")
        else
            local res, err_msg = eval(code)
            if err_msg then
                client:send("ERR " .. b64(err_msg) .. "\n")
            else
                client:send("OK " .. b64(res) .. "\n")
            end
        end

    elseif cmd == "QUIT" then
        -- graceful disconnect

    else
        client:send("ERR unknown command\n")
    end

    client:close()
end

-- ── server setup ──────────────────────────────────────────────

local server, err = socket.tcp()
if not server then
    print("[moddev] Failed to create socket: " .. err)
    return
end

server:settimeout(0)  -- non-blocking poll
local ok, err = server:bind(HOST, PORT)
if not ok then
    print("[moddev] Failed to bind " .. HOST .. ":" .. PORT .. " — " .. err)
    server:close()
    return
end
server:listen(1)
print("[moddev] Server ready on " .. HOST .. ":" .. PORT)

-- ── update hook ───────────────────────────────────────────────
-- Foundation calls mod:onUpdate(dt) each frame if defined.
-- Chain to any existing handler so we don't break other mods.

local _onUpdate = mod.onUpdate

function mod:onUpdate(dt)
    if _onUpdate then _onUpdate(self, dt) end
    while true do
        local client = server:accept()
        if not client then break end
        handle(client)
    end
end
