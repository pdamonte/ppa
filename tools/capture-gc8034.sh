#!/usr/bin/env bash
set -euo pipefail

OUT_RAW="${1:-/tmp/gc8034-frame.raw}"
OUT_PNG="${2:-/tmp/gc8034-frame.png}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DEV="${MEDIA_DEV:-auto}"
WIDTH=3264
HEIGHT=2448
FRAME_SIZE=$((WIDTH * HEIGHT * 2))

need_root() {
	if [ "$(id -u)" -ne 0 ]; then
		echo "Run as root so /dev nodes can be created and V4L2 devices opened." >&2
		exit 1
	fi
}

create_dev_nodes() {
	local d name majmin maj min

	for d in /sys/class/video4linux/* /sys/class/media/*; do
		[ -e "$d/dev" ] || continue
		name="$(basename "$d")"
		majmin="$(cat "$d/dev")"
		maj="${majmin%:*}"
		min="${majmin#*:}"
		[ -e "/dev/$name" ] || mknod "/dev/$name" c "$maj" "$min"
		chmod 0660 "/dev/$name"
	done
}

detect_pipeline() {
	eval "$("${SCRIPT_DIR}/detect-camera-pipeline.py" \
		--media "$MEDIA_DEV" \
		--sensor 'gc8034|gcti8034')"
	echo "Using ${SENSOR_ENTITY} (${SENSOR_NODE}) -> ${CSI_ENTITY} (${CSI_NODE}) -> ${CAPTURE_ENTITY} (${CAPTURE_NODE})"
}

configure_pipeline() {
	media-ctl -d "$MEDIA_DEV" \
		-l "\"${CSI_ENTITY}\":${CSI_SOURCE_PAD} -> \"${CAPTURE_ENTITY}\":${CAPTURE_SINK_PAD} [1]"

	v4l2-ctl -d "$SENSOR_NODE" \
		--set-subdev-fmt "pad=${SENSOR_SOURCE_PAD},width=${WIDTH},height=${HEIGHT},code=0x300f"
	v4l2-ctl -d "$CSI_NODE" \
		--set-subdev-fmt "pad=${CSI_SINK_PAD},width=${WIDTH},height=${HEIGHT},code=0x300f"
	v4l2-ctl -d "$CSI_NODE" \
		--set-subdev-fmt "pad=${CSI_SOURCE_PAD},width=${WIDTH},height=${HEIGHT},code=0x300f"
	v4l2-ctl -d "$CAPTURE_NODE" \
		--set-fmt-video="width=${WIDTH},height=${HEIGHT},pixelformat=RG10"
}

capture_raw() {
	v4l2-ctl -d "$SENSOR_NODE" \
		--set-ctrl=analogue_gain=512,exposure=2246

	rm -f "$OUT_RAW"
	v4l2-ctl -d "$CAPTURE_NODE" \
		--stream-mmap=4 \
		--stream-count=3 \
		--stream-to="$OUT_RAW" \
		--stream-poll
}

convert_preview() {
	python3 - "$OUT_RAW" "$OUT_PNG" "$WIDTH" "$HEIGHT" "$FRAME_SIZE" <<'PY'
from array import array
from pathlib import Path
import sys
from PIL import Image

raw_path = Path(sys.argv[1])
png_path = Path(sys.argv[2])
w = int(sys.argv[3])
h = int(sys.argv[4])
frame_size = int(sys.argv[5])

data = raw_path.read_bytes()
if len(data) < frame_size:
    raise SystemExit(f"raw file is too small: {len(data)} bytes")

frame = data[-frame_size:]
vals = array("H")
vals.frombytes(frame)
samples = [v & 0x03ff for v in vals]
ordered = sorted(samples)
lo = ordered[int(len(ordered) * 0.01)]
hi = ordered[int(len(ordered) * 0.99)]
if hi <= lo:
    hi = lo + 1

pixels = [max(0, min(255, (s - lo) * 255 // (hi - lo))) for s in samples]
Image.frombytes("L", (w, h), bytes(pixels)).save(png_path)
print(png_path)
PY
}

need_root
create_dev_nodes
detect_pipeline
configure_pipeline
capture_raw
convert_preview
