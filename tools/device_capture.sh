#!/usr/bin/env bash
# device 화면 캡처 — SM F711N(폴더블)의 "Multiple displays" 경고 prefix 제거.
# 사용: bash tools/device_capture.sh <out_name>
set -e
ADB="/c/Users/tgkim/AppData/Local/Android/Sdk/platform-tools/adb.exe"
NAME="${1:-shot}"
OUT="test_screenshots/device/${NAME}.png"
mkdir -p test_screenshots/device
"$ADB" exec-out screencap -p > test_screenshots/device/_raw.bin 2>/dev/null
python -c "
d=open('test_screenshots/device/_raw.bin','rb').read()
i=d.find(b'\x89PNG\r\n\x1a\n')
open('$OUT','wb').write(d[i:] if i>=0 else d)
print('$OUT', 'png_offset', i, 'bytes', len(d)-(i if i>0 else 0))
"
