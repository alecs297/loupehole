#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
source_icon="$repo_root/docs/assets/loupehole-logo.png"
output_dir="$repo_root/src/packaging/theos/generated/preference-resources"
python_bin="${PYTHON:-python3}"

if [ ! -f "$source_icon" ]; then
    echo "missing preference icon source: $source_icon" >&2
    exit 1
fi

mkdir -p "$output_dir"
rm -f "$output_dir"/LoupeholeIcon.png "$output_dir"/LoupeholeIcon@2x.png "$output_dir"/LoupeholeIcon@3x.png
rm -f \
    "$repo_root/src/packaging/theos/.theos/obj/LoupeholePreferences.bundle/LoupeholeIcon.png" \
    "$repo_root/src/packaging/theos/.theos/_/var/jb/Library/PreferenceBundles/LoupeholePreferences.bundle/LoupeholeIcon.png"

"$python_bin" - "$source_icon" "$output_dir" <<'PY'
import math
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageOps
except ImportError as exc:
    raise SystemExit("Pillow is required to generate masked PreferenceLoader icons") from exc

source = Path(sys.argv[1])
output_dir = Path(sys.argv[2])

base = Image.open(source).convert("RGBA")
resample = Image.Resampling.LANCZOS

def squircle_mask(size):
    supersample = 4
    canvas_size = size * supersample
    radius = canvas_size / 2.0
    exponent = 4.8
    samples = 720
    points = []
    for index in range(samples):
        theta = (index / samples) * 2.0 * 3.141592653589793
        cos_value = math.cos(theta)
        sin_value = math.sin(theta)
        x = (1 if cos_value >= 0 else -1) * (abs(cos_value) ** (2.0 / exponent))
        y = (1 if sin_value >= 0 else -1) * (abs(sin_value) ** (2.0 / exponent))
        points.append((radius + x * radius, radius + y * radius))

    mask = Image.new("L", (canvas_size, canvas_size), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask.resize((size, size), resample)

for scale, size in (("2x", 58), ("3x", 87)):
    icon = ImageOps.fit(base, (size, size), method=resample, centering=(0.5, 0.5))
    alpha = ImageChops.multiply(icon.getchannel("A"), squircle_mask(size))
    icon.putalpha(alpha)
    icon.save(output_dir / f"LoupeholeIcon@{scale}.png")
PY
