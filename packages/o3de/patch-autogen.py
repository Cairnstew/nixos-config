#!/usr/bin/env python3
"""Patch LyAutoGen.cmake to skip AutoGen during configure."""
import re, sys

with open(sys.argv[1]) as f:
    c = f.read()

# Replace the execute_process block (AutoGen call) with a stub
old = re.compile(
    r'execute_process\s*\('
    r'[\s\S]*?'
    r'RESULT_VARIABLE AUTOGEN_RESULT\s*\)'
)
new = (
    'message(STATUS "Nixpkgs: AutoGen skipped")\n'
    '        set(AUTOGEN_OUTPUTS "")\n'
    '        set(AUTOGEN_ERROR "")\n'
    '        set(AUTOGEN_RESULT 0)'
)
c = old.sub(new, c)

# Replace the FATAL_ERROR check with a skip block
old_fatal = re.compile(
    r'if\(NOT AUTOGEN_RESULT EQUAL 0\)\s*'
    r'message\([A-Z_]+\s+"AutoGen.*?\)\s*'
    r'endif\(\)'
)
c = old_fatal.sub(
    'if(NOT AUTOGEN_RESULT EQUAL 0)\n'
    '            message(STATUS "Nixpkgs: AutoGen result ${AUTOGEN_RESULT}")\n'
    '        endif()',
    c
)

# Guard the add_custom_command and target_sources with a check on AUTOGEN_OUTPUTS
# so they don't error when outputs are empty
c = c.replace(
    '        string(STRIP "${AUTOGEN_OUTPUTS}" AUTOGEN_OUTPUTS)',
    '        string(STRIP "${AUTOGEN_OUTPUTS}" AUTOGEN_OUTPUTS)\n'
    '        if(AUTOGEN_OUTPUTS)'
)
c = c.replace(
    '        target_sources(${ly_add_autogen_NAME} PRIVATE ${AUTOGEN_OUTPUTS})\n'
    '    endif()\n'
    '\n'
    'endfunction()',
    '        target_sources(${ly_add_autogen_NAME} PRIVATE ${AUTOGEN_OUTPUTS})\n'
    '        endif()\n'
    '    endif()\n'
    '\n'
    'endfunction()'
)

with open(sys.argv[1], 'w') as f:
    f.write(c)
