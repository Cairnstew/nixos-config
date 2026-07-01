import socket
import base64
import struct


class FoundationIPCError(Exception):
    pass


class FoundationIPC:
    def __init__(self, host="127.0.0.1", port=27105):
        self.host = host
        self.port = port
        self._sock = None

    def connect(self) -> bool:
        if self._sock:
            return True
        try:
            self._sock = socket.create_connection(
                (self.host, self.port), timeout=5
            )
            return True
        except ConnectionRefusedError:
            self._sock = None
            raise FoundationIPCError(
                f"Foundation not running on {self.host}:{self.port}. "
                "Make sure the game is running and moddev/init.lua is deployed."
            )
        except OSError as e:
            self._sock = None
            raise FoundationIPCError(f"Connection failed: {e}")

    def disconnect(self):
        if self._sock:
            try:
                self._sock.close()
            except OSError:
                pass
        self._sock = None

    def _send_recv(self, payload: str) -> str:
        if not self._sock:
            raise FoundationIPCError("Not connected")
        try:
            self._sock.sendall((payload + "\n").encode("utf-8"))
            resp = self._sock.recv(65536).decode("utf-8", errors="replace").strip()
            return resp
        except socket.timeout:
            raise FoundationIPCError("Timed out waiting for response")
        except OSError as e:
            raise FoundationIPCError(f"Socket error: {e}")

    def ping(self) -> str:
        resp = self._send_recv("PING")
        if resp.startswith("PONG "):
            return resp[5:]
        raise FoundationIPCError(f"Unexpected PING response: {resp}")

    def eval(self, lua_code: str) -> str:
        encoded = base64.b64encode(lua_code.encode("utf-8")).decode("ascii")
        resp = self._send_recv(f"EVAL {encoded}")
        if resp.startswith("OK "):
            raw = base64.b64decode(resp[3:])
            return raw.decode("utf-8", errors="replace")
        elif resp.startswith("ERR "):
            raw = base64.b64decode(resp[4:])
            msg = raw.decode("utf-8", errors="replace")
            raise FoundationIPCError(f"Lua error: {msg}")
        elif resp == "ERR empty":
            raise FoundationIPCError("Empty Lua code rejected by server")
        raise FoundationIPCError(f"Unexpected EVAL response: {resp}")

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, *args):
        self.disconnect()
