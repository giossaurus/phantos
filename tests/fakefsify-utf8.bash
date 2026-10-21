#!/bin/bash -e
# fakefsify must import names that aren't ASCII, whatever the process's locale. The app runs in
# the C locale, and Alpine's ca-certificates ships a certificate named Főtanúsítvány.
#
# Usage: fakefsify-utf8.bash <fakefsify>

fakefsify=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 -I - "$work/root.tar" <<'EOF'
import io, sys, tarfile
with tarfile.open(sys.argv[1], 'w', format=tarfile.PAX_FORMAT, encoding='utf-8') as tar:
    data = b'certificate\n'
    file = tarfile.TarInfo('./certs/Főtanúsítvány.pem')
    file.size = len(data)
    tar.addfile(file, io.BytesIO(data))
    link = tarfile.TarInfo('./certs/988a38cb.0')
    link.type = tarfile.SYMTYPE
    link.linkname = 'Főtanúsítvány.pem'
    tar.addfile(link)
EOF

LC_ALL=C "$fakefsify" "$work/root.tar" "$work/fs"

[ "$(cat "$work/fs/data/certs/Főtanúsítvány.pem")" = certificate ] || { echo "file with a UTF-8 name is missing"; exit 1; }
# Names keep their bytes. libarchive decomposes them on Apple platforms (o + combining acute),
# and a Linux program asking for the composed name the archive had would find nothing.
python3 -I - "$work/fs" <<'EOF'
import sqlite3, sys
fs = sys.argv[1]
name = 'Főtanúsítvány.pem'.encode()
paths = {bytes(row[0]) for row in sqlite3.connect(f'{fs}/meta.db').execute('select path from paths')}
assert b'/certs/' + name in paths, f'path not stored as written: {paths}'
# fakefs stores a symlink as a regular file holding its target.
target = open(f'{fs}/data/certs/988a38cb.0', 'rb').read()
assert target == name, f'symlink target not stored as written: {target}'
EOF
echo ok
