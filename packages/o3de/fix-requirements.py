#!/usr/bin/env python3
"""Strip hashes and fix numpy pin in O3DE requirements.txt."""
import re, sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Bump numpy
content = content.replace("numpy==1.23.0", "numpy>=1.24.0")

# Remove --hash= lines (with optional trailing backslash)
content = re.sub(r'^(\s+)--hash=[^\n]*\\?\n?', '', content, flags=re.MULTILINE)

# Remove orphaned backslash continuation lines
content = re.sub(r'^[ \t]*\\\\\n', '', content, flags=re.MULTILINE)

# Collapse excessive blank lines
content = re.sub(r'\n{3,}', '\n\n', content)

with open(path, 'w') as f:
    f.write(content)
