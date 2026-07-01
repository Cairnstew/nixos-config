import struct
from pathlib import Path


def _walk_png(data: bytes, start: int) -> int:
    """Walk PNG chunks starting at `start` (where 0x89 PNG magic begins).
    Returns the offset of the first byte AFTER the last valid PNG chunk.
    """
    pos = start + 8  # skip 8-byte PNG signature
    while pos + 8 <= len(data):
        chunk_len = struct.unpack_from(">I", data, pos)[0]
        chunk_type = data[pos + 4 : pos + 8]
        chunk_end = pos + 12 + chunk_len  # len + type + data + CRC
        if chunk_end > len(data):
            break
        if chunk_type == b"IEND":
            return chunk_end
        pos = chunk_end
    return pos


class SaveFile:
    path: Path
    header: bytes  # 31 bytes, offsets 0x00-0x1e
    thumbnail: bytes  # PNG data, starts at offset 0x1f (byte 31)
    blob: bytes  # remaining binary data

    def __init__(self, path: Path, header: bytes, thumbnail: bytes, blob: bytes):
        self.path = path
        self.header = header
        self.thumbnail = thumbnail
        self.blob = blob

    @staticmethod
    def from_path(path: Path) -> "SaveFile":
        data = path.read_bytes()
        if len(data) < 32:
            raise ValueError(f"File too small: {len(data)} bytes (expected at least 32)")
        header = data[:31]
        png_magic = data[31]
        if png_magic != 0x89:
            raise ValueError(f"Invalid header: byte 31 is 0x{png_magic:02x}, expected 0x89 (PNG start)")
        png_end = _walk_png(data, 31)
        thumbnail = data[31:png_end]
        blob = data[png_end:]
        return SaveFile(path=path, header=header, thumbnail=thumbnail, blob=blob)

    def to_bytes(self) -> bytes:
        return self.header + self.thumbnail + self.blob

    def extract_thumbnail(self) -> bytes:
        if self.thumbnail[-4:] == b"IEND":
            return self.thumbnail
        return self.thumbnail + b"\x00\x00\x00\x00IEND\xae\x42\x60\x82"

    def inject_thumbnail(self, png_bytes: bytes) -> bytes:
        return self.header + png_bytes + self.blob

    def header_dict(self) -> dict:
        if len(self.header) < 28:
            return {"error": "header too short"}
        fields = struct.unpack_from("<IIII", self.header[:16])
        zlib_meta = self.header[16:28]
        return {
            "version": fields[0],
            "count": fields[1],
            "field_2": fields[2],
            "field_3": fields[3],
            "zlib_meta_hex": zlib_meta.hex(),
            "png_magic_byte": f"0x{self.header[30]:02x}" if len(self.header) > 30 else "N/A",
            "png_start_offset": 0x1f,
        }

    def info(self) -> dict:
        h = self.header_dict()
        return {
            "path": str(self.path),
            "size": self.path.stat().st_size,
            "header": h,
            "header_bytes": len(self.header),
            "thumbnail_size": len(self.thumbnail),
            "blob_size": len(self.blob),
        }
