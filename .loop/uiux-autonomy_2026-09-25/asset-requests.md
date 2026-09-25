# Image-asset requests (owner-fulfilled, not headless)

The headless loop appends a request here and marks the corresponding ticket `blocked_on_asset`
in VISION.md when it needs new raster art that plain SwiftUI/SF Symbols can't produce. The
owner's interactive Claude Code session fulfills each request via claude-in-chrome against the
owner's own logged-in chatgpt.com session, drops the chosen file at
`.loop/uiux-autonomy_2026-09-25/assets/<slot-name>.png`, and marks it fulfilled below. Format:

## <slot-name> — requested <date>
- Need: <what image, subject, mood>
- Size/aspect: <e.g. 1024x1024, square icon / 3:2 illustration>
- Style reference: <DESIGN.md dial values, existing asset to match, palette>
- Target: <asset catalog imageset path>
- Status: requested | fulfilled (file: assets/<slot-name>.png)

(none yet)
