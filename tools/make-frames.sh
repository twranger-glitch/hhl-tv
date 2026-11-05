#!/usr/bin/env bash
# 把 images/*.mp4 轉成「圖片動畫 + 音訊」，給老 LG 電視播放（不經過電視的影片播放器）
# 產出：images/<檔名>.frames/{manifest.json, s001.jpg..., audio.mp3}
# 用法：tools/make-frames.sh [影片檔...]   （不給參數就處理 images/ 底下全部 mp4）
set -euo pipefail
FPS=8; W=854; H=480; COLS=3; ROWS=3; Q=11
files=("$@"); [ ${#files[@]} -eq 0 ] && files=(images/*.mp4)
for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  out="${f%.mp4}.frames"
  sha=$(sha256sum "$f" | cut -c1-16)
  if [ -f "$out/manifest.json" ] && grep -q "\"src\": \"$sha\"" "$out/manifest.json"; then
    echo "skip $f (up to date)"; continue
  fi
  echo "convert $f -> $out"
  rm -rf "$out"; mkdir -p "$out"
  ffmpeg -v error -i "$f" -vf "fps=$FPS,scale=$W:$H:force_original_aspect_ratio=decrease,pad=$W:$H:(ow-iw)/2:(oh-ih)/2,tile=${COLS}x${ROWS}" -q:v $Q "$out/s%03d.jpg"
  has_audio=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$f" | head -1)
  audio=""
  if [ -n "$has_audio" ]; then
    ffmpeg -v error -y -i "$f" -vn -ac 1 -ar 22050 -b:a 64k "$out/audio.mp3"; audio="audio.mp3"
  fi
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  sheets=$(ls "$out"/s*.jpg | wc -l)
  frames=$(python3 -c "import math;print(int(math.floor(float('$dur')*$FPS)))")
  cat > "$out/manifest.json" <<JSON
{"version": 1, "src": "$sha", "fps": $FPS, "w": $W, "h": $H, "cols": $COLS, "rows": $ROWS,
 "frames": $frames, "sheets": $sheets, "duration": $dur, "audio": "$audio"}
JSON
done
