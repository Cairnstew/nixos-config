#!/usr/bin/env python3
"""Fix GAB's Styles Pack's crash-on-`register` bug.

Usage: gabstylespack.py <com/gablabit/gabstylespack/GabStylesPack.class>

GabStylesPack v0.4.0's <init> does:
    modEventBus.addListener(this::commonSetup);          // correct (FML lifecycle)
    NeoForge.EVENT_BUS.register(this);                    // BUG: crashes mod loading
The `NeoForge.EVENT_BUS.register(this)` call is wrong: the class has no
@SubscribeEvent-annotated methods, so NeoForge throws
`IllegalArgumentException: ... has no @SubscribeEvent methods, but register was
called anyway` and mod loading aborts (server AND client).

The FML common-setup wiring via `addListener` is already sufficient, so the fix
is to NOP out the three instructions that implement the bogus register call
(getstatic NeoForge.EVENT_BUS; aload_0; invokeinterface register) from the
constructor's Code attribute. NOPing (not shrinking) preserves byte offsets, so
the LineNumberTable / LocalVariableTable stay valid and no stack-map rewriting
is needed (net stack effect of the removed block is zero).

Fails loudly if the exact instruction sequence is not found exactly once, so an
upstream recompile that changes the bytecode is caught instead of silently
shipping an unpatched (still-crashing) jar.
"""
import struct
import sys

path = sys.argv[1]

with open(path, "rb") as f:
    data = bytearray(f.read())


def u2(buf, off):
    return struct.unpack_from(">H", buf, off)[0]


def u4(buf, off):
    return struct.unpack_from(">I", buf, off)[0]


def read_utf8(buf, off):
    """buf[off] is the byte length of a CONSTANT_Utf8; return (string, next_off)."""
    n = u2(buf, off)
    return buf[off + 2:off + 2 + n].decode("utf-8", "replace"), off + 2 + n


# Parse the constant pool into a lookup table.
assert data[:4] == b"\xca\xfe\xba\xbe", "not a class file"
off = 8  # magic + minor + major
cp_count = u2(data, off)
off += 2
utf8 = {}  # index -> utf8 string
cp = {}    # index -> tag
i = 1
while i < cp_count:
    tag = data[off]
    if tag == 1:
        s, off = read_utf8(data, off + 1)  # length field starts after the tag byte
        utf8[i] = s
    elif tag in (7, 8, 16, 19, 20):  # Class, String, MethodType, Module, Package
        off += 3
    elif tag == 15:  # MethodHandle
        off += 4
    elif tag in (3, 4, 9, 10, 11, 12, 17, 18):
        off += 5
    elif tag in (5, 6):  # Long, Double
        off += 9
        i += 1
    else:
        sys.stderr.write(f"unknown constant pool tag {tag} at constant #{i}\n")
        sys.exit(1)
    cp[i] = tag
    i += 1


def skip_attrs(buf, off):
    """Skip an attributes array; buf[off] = attributes_count. Returns next_off."""
    n = u2(buf, off)
    off += 2
    for _ in range(n):
        alen = u4(buf, off + 2)
        off += 6 + alen
    return off


off += 6  # access_flags + this_class + super_class
interfaces_count = u2(data, off)
off += 2 + interfaces_count * 2

fields_count = u2(data, off)
off += 2
for _ in range(fields_count):
    off += 6
    off = skip_attrs(data, off)

methods_count = u2(data, off)
off += 2

code_attr = None  # (start_index_of_code_bytes_into_data, code_length)
for _ in range(methods_count):
    _, name_idx, _, attrs_count = struct.unpack_from(">HHHH", data, off)
    off += 8
    name = utf8.get(name_idx)
    for _ in range(attrs_count):
        name_a = u2(data, off)
        alen = u4(data, off + 2)
        attr_name = utf8.get(name_a)
        body = off + 6
        if attr_name == "Code" and name == "<init>":
            # Code attr: max_stack(2) max_locals(2) code_length(4) code...
            code_length = u4(data, body + 4)
            code_attr = (body + 8, code_length)
        off += 6 + alen

if code_attr is None:
    sys.stderr.write(
        "could not find Code attribute of <init> in GabStylesPack.class; "
        "re-review upstream class\n"
    )
    sys.exit(1)

code_body, code_length = code_attr
code = data[code_body:code_body + code_length]

# Target block in the constructor (9 bytes, bytecode offsets 16..24):
#   getstatic (0xB2) NeoForge.EVENT_BUS          -> b2 00 11 (cp#17 Fieldref)
#   aload_0   (0x2A)                              -> 2a
#   invokeinterface (0xB9) IEventBus.register(Object) -> b9 00 17 02 00
#                                                       (cp#23 InterfaceMethodref)
PAT = bytes.fromhex("b2") + b"\x00\x11" + bytes.fromhex("2a") + \
    bytes.fromhex("b9") + b"\x00\x17" + b"\x02\x00"

hits = []
p = 0
while True:
    idx = code.find(PAT, p)
    if idx == -1:
        break
    hits.append(idx)
    p = idx + 1

if len(hits) != 1:
    sys.stderr.write(
        f"expected exactly one bogus register block in GabStylesPack <init>, "
        f"found {len(hits)}; re-review upstream bytecode\n"
    )
    sys.exit(1)

hit = hits[0]
# Sanity-check referenced pool entries are a Fieldref + an InterfaceMethodref.
field_idx = u2(code, hit + 1)
ifm_idx = u2(code, hit + 5)
if cp.get(field_idx) != 9 or cp.get(ifm_idx) != 11:
    sys.stderr.write(
        f"register block at {hit}: unexpected refs "
        f"(field cp#{field_idx} tag={cp.get(field_idx)}, "
        f"ifm cp#{ifm_idx} tag={cp.get(ifm_idx)}); re-review upstream bytecode\n"
    )
    sys.exit(1)

# NOP out bytes [hit, hit+9): getstatic(3) aload_0(1) invokeinterface(5)
for k in range(hit, hit + 9):
    data[code_body + k] = 0x00

with open(path, "wb") as f:
    f.write(data)

sys.stderr.write(
    f"gabstylespack: NOPed bogus register block at <init>+{hit} "
    f"(getstatic+aload_0+invokeinterface)\n"
)
