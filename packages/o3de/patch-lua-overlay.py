#!/usr/bin/env python3
"""Replace _np_import_find(Lua Lua) with pkg-config-based Lua 5.4 detection."""
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Find and replace the entire Lua overlay line
old_marker = '_np_import_find(Lua Lua)'

new = """\
if(NOT TARGET 3rdParty::Lua)
  find_package(PkgConfig QUIET)
  if(PkgConfig_FOUND)
    pkg_check_modules(LUA54 lua5.4 QUIET IMPORTED_TARGET)
  endif()
  if(NOT LUA54_FOUND)
    find_path(LUA54_INCLUDE_DIR lua.h PATH_SUFFIXES lua5.4 lua-5.4)
    find_library(LUA54_LIBRARY lua5.4 lua-5.4 lua)
  endif()
  if(LUA54_INCLUDE_DIR AND LUA54_LIBRARY)
    add_library(3rdParty::Lua INTERFACE IMPORTED GLOBAL)
    target_include_directories(3rdParty::Lua INTERFACE "${LUA54_INCLUDE_DIR}")
    target_link_libraries(3rdParty::Lua INTERFACE "${LUA54_LIBRARY}")
    message(STATUS "NixpkgsPackages: 3rdParty::Lua <- ${LUA54_LIBRARY}")
  elseif(LUA54_FOUND)
    add_library(3rdParty::Lua INTERFACE IMPORTED GLOBAL)
    target_include_directories(3rdParty::Lua INTERFACE "${LUA54_INCLUDE_DIRS}")
    target_link_libraries(3rdParty::Lua INTERFACE PkgConfig::LUA54)
    message(STATUS "NixpkgsPackages: 3rdParty::Lua <- lua5.4 ${LUA54_LINK_LIBRARIES}")
  else()
    add_library(3rdParty::Lua INTERFACE IMPORTED GLOBAL)
    message(STATUS "NixpkgsPackages: 3rdParty::Lua stubbed (lua5.4 not found)")
  endif()
endif()"""

# Replace from start of match to end of line (preserve the newline)
idx = content.index(old_marker)
eol = content.index('\n', idx)
content = content[:idx] + new + content[eol:]

# Remove the fallback if+stub+endif block (comes right after our replaced line)
# Since both blocks are guarded with if(NOT TARGET), the fallback is redundant but harmless.
# Still remove it to keep the file clean.
lines = content.split('\n')
for i in range(idx, len(lines)):
    if lines[i].startswith('if(NOT TARGET 3rdParty::Lua)'):
        # Remove this if block (3 lines: if, _np_stub, endif)
        del lines[i:i+3]
        break
content = '\n'.join(lines)

with open(path, 'w') as f:
    f.write(content)

print(f"Patched {path} for Lua 5.4")
