#!/usr/bin/env python3
"""CLI tool to parse and display binlog binary log files."""

import argparse
import struct
import sys
from datetime import datetime, timezone, timedelta

# File header
FILE_HDR_FMT = '<IIBBxx'  # fileType, magicCode, major, minor, 2 reserved
FILE_HDR_SIZE = struct.calcsize(FILE_HDR_FMT)
MAGIC_FILE_TYPE = 0xA0A0A0A0
MAGIC_CODE = 0x1A2B3C4D

# Block header: size(u32) blockType(u8) rsrv(u8) numOfEvents(u16)
BLK_HDR_FMT = '<IBBH'
BLK_HDR_SIZE = struct.calcsize(BLK_HDR_FMT)

# Source PDU fixed part: id, severity, fmtStrSize, fileStrSize, line, numOfParas
SRC_PDU_FMT = '<IIIIII'
SRC_PDU_SIZE = struct.calcsize(SRC_PDU_FMT)

# Args PDU fixed part: clock(u64), id(u32), size(u32)
ARGS_PDU_FMT = '<QII'
ARGS_PDU_SIZE = struct.calcsize(ARGS_PDU_FMT)

BLOCK_SOURCE = 0
BLOCK_ARGS = 1

# ArgumentType enum → (struct format, size). None for STRING (variable).
ARG_TYPES = {
    0:  ('<?', 1),   # BOOL
    1:  ('<b', 1),   # CHAR
    2:  ('<b', 1),   # INT8
    3:  ('<B', 1),   # UINT8
    4:  ('<h', 2),   # INT16
    5:  ('<H', 2),   # UINT16
    6:  ('<i', 4),   # INT32
    7:  ('<I', 4),   # UINT32
    8:  ('<f', 4),   # FLOAT
    9:  ('<d', 8),   # DOUBLE
    10: ('<q', 8),   # INT64
    11: ('<Q', 8),   # UINT64
    12: ('<Q', 8),   # POINTER
    13: None,        # STRING (null-terminated)
}

SEVERITY_NAMES = ['EMERG', 'ALERT', 'CRIT', 'ERROR', 'WARN', 'NOTICE', 'INFO', 'DEBUG']


def parse_source_pdu(data, offset):
    """Parse one StreamSourcePdu, return (source_info_dict, bytes_consumed)."""
    eid, sev, fmt_sz, file_sz, line, n_paras = struct.unpack_from(SRC_PDU_FMT, data, offset)
    pos = offset + SRC_PDU_SIZE
    fmt_str = data[pos:pos + fmt_sz].split(b'\x00', 1)[0].decode('utf-8', errors='replace')
    pos += fmt_sz
    file_str = data[pos:pos + file_sz].split(b'\x00', 1)[0].decode('utf-8', errors='replace')
    pos += file_sz
    param_types = list(data[pos:pos + n_paras])
    pos += n_paras
    return {
        'id': eid, 'severity': sev, 'fmt': fmt_str,
        'file': file_str, 'line': line, 'param_types': param_types,
    }, pos - offset


def decode_args(payload, param_types):
    """Decode raw argument payload using type list from SourcePdu."""
    values = []
    off = 0
    for t in param_types:
        spec = ARG_TYPES.get(t)
        if spec is None:  # STRING
            end = payload.find(b'\x00', off)
            if end < 0:
                end = len(payload)
            values.append(payload[off:end].decode('utf-8', errors='replace'))
            off = end + 1
        else:
            fmt, sz = spec
            if off + sz > len(payload):
                break
            val = struct.unpack_from(fmt, payload, off)[0]
            if t == 12:  # POINTER
                val = f'0x{val:x}'
            values.append(val)
            off += sz
    return values


def format_message(fmt_str, values):
    """Apply C-style printf format string with decoded values."""
    try:
        return fmt_str % tuple(values)
    except (TypeError, ValueError):
        # Fallback: just list values
        return f'{fmt_str} | args={values}'


def parse_file(filepath):
    """Parse binlog file, yield (clock_ns, severity, file, line, message) tuples."""
    with open(filepath, 'rb') as f:
        data = f.read()

    if len(data) < FILE_HDR_SIZE:
        print(f'Error: file too small ({len(data)} bytes)', file=sys.stderr)
        return

    ft, mc, major, minor = struct.unpack_from(FILE_HDR_FMT, data, 0)
    if ft != MAGIC_FILE_TYPE or mc != MAGIC_CODE:
        print(f'Error: invalid file header (fileType=0x{ft:08x} magic=0x{mc:08x})', file=sys.stderr)
        return

    source_db = {}
    pos = FILE_HDR_SIZE

    while pos + BLK_HDR_SIZE <= len(data):
        blk_size, blk_type, _, n_events = struct.unpack_from(BLK_HDR_FMT, data, pos)
        blk_payload_start = pos + BLK_HDR_SIZE
        blk_end = pos + 4 + blk_size  # size excludes first 4 bytes

        if blk_end > len(data):
            break

        if blk_type == BLOCK_SOURCE:
            off = blk_payload_start
            for _ in range(n_events):
                if off >= blk_end:
                    break
                info, consumed = parse_source_pdu(data, off)
                source_db[info['id']] = info
                off += consumed

        elif blk_type == BLOCK_ARGS:
            off = blk_payload_start
            for _ in range(n_events):
                if off + ARGS_PDU_SIZE > blk_end:
                    break
                clock, eid, payload_sz = struct.unpack_from(ARGS_PDU_FMT, data, off)
                off += ARGS_PDU_SIZE
                payload = data[off:off + payload_sz]
                off += payload_sz

                src = source_db.get(eid)
                if src is None:
                    continue
                values = decode_args(payload, src['param_types'])
                msg = format_message(src['fmt'], values)
                yield clock, src['severity'], src['file'], src['line'], msg

        pos = blk_end


def main():
    p = argparse.ArgumentParser(description='Parse binlog binary log files')
    p.add_argument('file', help='binlog file path (e.g. ttilog.0.00)')
    p.add_argument('-n', '--count', type=int, default=0, help='show first N events (0=all)')
    p.add_argument('--tail', type=int, default=0, help='show last N events')
    p.add_argument('-s', '--severity', help='min severity filter (e.g. WARN, INFO, DEBUG)')
    p.add_argument('-g', '--grep', help='filter messages containing this substring')
    p.add_argument('--file-filter', help='filter by source file name substring')
    p.add_argument('--raw', action='store_true', help='output without timestamp formatting')
    p.add_argument('--stats', action='store_true', help='show event statistics instead of log lines')
    p.add_argument('--tz', type=int, default=8, help='timezone offset in hours (default: 8 for CST)')
    args = p.parse_args()

    sev_threshold = 7
    if args.severity:
        name = args.severity.upper()
        if name in SEVERITY_NAMES:
            sev_threshold = SEVERITY_NAMES.index(name)
        else:
            print(f'Unknown severity: {name}. Use: {", ".join(SEVERITY_NAMES)}', file=sys.stderr)
            sys.exit(1)

    tz = timezone(timedelta(hours=args.tz))

    if args.stats:
        stats = {}
        for clock, sev, fname, line, msg in parse_file(args.file):
            key = (fname, line, sev)
            if key not in stats:
                stats[key] = {'count': 0, 'fmt': msg[:80]}
            stats[key]['count'] += 1
        print(f'{"Count":>8}  {"Severity":<7}  {"File:Line":<30}  Message')
        print('-' * 90)
        for (fname, line, sev), info in sorted(stats.items(), key=lambda x: -x[1]['count']):
            sev_name = SEVERITY_NAMES[sev] if sev < len(SEVERITY_NAMES) else str(sev)
            print(f'{info["count"]:>8}  {sev_name:<7}  {fname}:{line:<20}  {info["fmt"]}')
        return

    results = []
    for clock, sev, fname, line, msg in parse_file(args.file):
        if sev > sev_threshold:
            continue
        if args.grep and args.grep not in msg:
            continue
        if args.file_filter and args.file_filter not in fname:
            continue

        if args.raw:
            ts = str(clock)
        else:
            dt = datetime.fromtimestamp(clock / 1e9, tz=tz)
            ts = dt.strftime('%H:%M:%S.') + f'{dt.microsecond:06d}'

        sev_name = SEVERITY_NAMES[sev] if sev < len(SEVERITY_NAMES) else str(sev)
        entry = f'[{ts}] [{sev_name:<6}] [{fname}:{line}] {msg}'

        if args.tail:
            results.append(entry)
            if len(results) > args.tail:
                results.pop(0)
        else:
            print(entry)
            if args.count:
                args.count -= 1
                if args.count <= 0:
                    break

    if args.tail:
        for entry in results:
            print(entry)


if __name__ == '__main__':
    main()
