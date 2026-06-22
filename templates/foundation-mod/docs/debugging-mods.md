# Debugging Mods

Lua development environments can be configured to debug Foudation mods.

## Debuggee script

The first step in debugging a mod is to setup the chosen debugger in the VM. This cannot be done by the mod scripts themselves as it requires escaping the sandbox they operate in; the required setup must be placed in a special `moddev` folder in the game's user files `(%USERPROFILE%\Documents\Polymorph Games\Foundation)`.

When the game starts and creates the lua VM, all scripts in this folder are loaded without any of the restrictions imposed on regular mod files. While this allows changing the lua environment to make mod development easier (such as by inserting a debugger), it also allows potentially unsafe scripts to run. **Mods should not use this folder for anything other than debugging, and should not require files in this folder in order to run properly.**

## ZeroBrane Studio

[ZeroBrane Studio](https://studio.zerobrane.com/ "https://studio.zerobrane.com/") supports attaching to a running environment out of the box with the MobDebug library, which in turn depends on luasocket.

While ZeroBrane Studio includes a version of luasocket, the IDE (and the libraries it includes) is only provided in 32-bit. Thus, a 64-bit version of the DLL is provided with the Foundation installation, to be able to connect to the debugger server. In addition, the lua environment has to be configured with a short debuggee script.

```lua
local zbs = "<path/to/zerobrane>"
package.path = package.path .. ";" .. zbs .. "/lualibs/?/?.lua;" .. zbs .. "/lualibs/?.lua"
package.cpath = package.cpath .. ";mods/libs/?.dll" -- DLL is in the folder <path/to/foundation.exe>/mods/libs/socket
require("mobdebug").start()
```

The path information (required for lua to find the required libraries) can also be configure with the `LUA_PATH` and `LUA_CPATH` environment variables.

ZeroBrane Studio's debugger server should also be enabled before launching the game. This will allow the IDE to connect to the lua VM when the game starts and enable debugging features.
