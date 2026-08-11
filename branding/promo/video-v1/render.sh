#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
build_dir="$script_dir/build"
output="$script_dir/skygrid-promo-download-hook-v1.mp4"

python3 "$script_dir/make_assets.py"

ffmpeg -hide_banner -loglevel warning -y \
  -loop 1 -framerate 30 -t 2.2 -i "$build_dir/scene-01-hook.png" \
  -loop 1 -framerate 30 -t 2.4 -i "$build_dir/scene-02-today.png" \
  -loop 1 -framerate 30 -t 2.2 -i "$build_dir/scene-03-friends.png" \
  -loop 1 -framerate 30 -t 2.5 -i "$build_dir/scene-04-grid.png" \
  -loop 1 -framerate 30 -t 2.7 -i "$build_dir/scene-05-cta.png" \
  -filter_complex "\
    [0:v]scale=1080:1920,zoompan=z='1+0.00011*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,trim=duration=2.2,setpts=PTS-STARTPTS[v0];\
    [1:v]scale=1080:1920,zoompan=z='1+0.00010*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,trim=duration=2.4,setpts=PTS-STARTPTS[v1];\
    [2:v]scale=1080:1920,zoompan=z='1+0.00012*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,trim=duration=2.2,setpts=PTS-STARTPTS[v2];\
    [3:v]scale=1080:1920,zoompan=z='1+0.00010*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,trim=duration=2.5,setpts=PTS-STARTPTS[v3];\
    [4:v]scale=1080:1920,zoompan=z='1+0.00008*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,trim=duration=2.7,setpts=PTS-STARTPTS[v4];\
    [v0][v1]xfade=transition=fade:duration=0.25:offset=1.95[x1];\
    [x1][v2]xfade=transition=fade:duration=0.25:offset=4.10[x2];\
    [x2][v3]xfade=transition=fade:duration=0.25:offset=6.05[x3];\
    [x3][v4]xfade=transition=fade:duration=0.25:offset=8.30,format=yuv420p[v]" \
  -map "[v]" -an -c:v libx264 -preset slow -crf 18 -movflags +faststart \
  "$build_dir/video-only.mp4"

ffmpeg -hide_banner -loglevel warning -y \
  -f lavfi -i "sine=frequency=220:duration=11:sample_rate=48000" \
  -f lavfi -i "sine=frequency=277.18:duration=11:sample_rate=48000" \
  -f lavfi -i "sine=frequency=329.63:duration=11:sample_rate=48000" \
  -f lavfi -i "sine=frequency=880:duration=0.34:sample_rate=48000" \
  -f lavfi -i "sine=frequency=1320:duration=0.18:sample_rate=48000" \
  -f lavfi -i "sine=frequency=660:duration=0.48:sample_rate=48000" \
  -f lavfi -i "sine=frequency=990:duration=0.52:sample_rate=48000" \
  -f lavfi -i "anoisesrc=color=pink:duration=11:sample_rate=48000" \
  -filter_complex "\
    [0:a]volume=0.20,lowpass=f=720,afade=t=in:st=0:d=1.0,afade=t=out:st=9.4:d=1.6[p0];\
    [1:a]volume=0.16,lowpass=f=720,afade=t=in:st=0:d=1.0,afade=t=out:st=9.4:d=1.6[p1];\
    [2:a]volume=0.12,lowpass=f=720,afade=t=in:st=0:d=1.0,afade=t=out:st=9.4:d=1.6[p2];\
    [3:a]volume=1.20,afade=t=out:st=0.05:d=0.29,adelay=2050[c0];\
    [4:a]volume=0.70,afade=t=out:st=0.02:d=0.16,adelay=4250[c1];\
    [5:a]volume=1.00,afade=t=out:st=0.06:d=0.42,adelay=6250[c2];\
    [6:a]volume=0.90,afade=t=out:st=0.08:d=0.44,adelay=8420[c3];\
    [7:a]volume=0.030,lowpass=f=1000,afade=t=in:st=0:d=1.2,afade=t=out:st=9.2:d=1.8[n];\
    [p0][p1][p2][c0][c1][c2][c3][n]amix=inputs=8:normalize=0,aecho=0.6:0.25:120:0.10,volume=10,alimiter=limit=0.75[a]" \
  -map "[a]" -ac 2 -c:a aac -b:a 192k "$build_dir/soundtrack.m4a"

ffmpeg -hide_banner -loglevel warning -y \
  -i "$build_dir/video-only.mp4" -i "$build_dir/soundtrack.m4a" \
  -map 0:v:0 -map 1:a:0 -c:v copy -c:a copy -shortest -movflags +faststart "$output"

echo "$output"
