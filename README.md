# RaidMarkerBarLite

A standalone raid marker bar for World of Warcraft: the eight target markers,
a clear button, a ready check and a pull countdown in one movable row.

No libraries, no dependencies, no `OnUpdate`. Two files and one saved-variable
table.

## Features

- **Works in combat.** The marker buttons are secure action buttons driven by
  macro text, so Blizzard's own code places the marker and combat lockdown
  never applies.
- **Target and world markers from one button.** A plain click sets the target
  marker; a modifier click (Shift by default) drops the matching world marker.
  `/rmb swap` reverses that.
- **Clear, ready check and pull timer** sit after the markers. The countdown
  length is a setting; right-clicking the button cancels a running pull.
- **Shows itself when it matters.** Always, only in a group, or only in a raid,
  via a secure state driver. In a raid without lead or assist the bar dims
  rather than hides.
- **Options panel** under Blizzard's Settings, over the same settings the slash
  commands write, so the two cannot disagree.

## Commands

| Command | Effect |
| --- | --- |
| `/rmb` | List these commands |
| `/rmb config` | Open the options panel |
| `/rmb lock` | Toggle the drag handle |
| `/rmb size <12-64>` | Button size |
| `/rmb spacing <0-20>` | Gap between buttons |
| `/rmb vertical` | Toggle orientation |
| `/rmb show <always\|group\|raid>` | When the bar is on screen |
| `/rmb swap` | Swap the plain-click and modifier actions |
| `/rmb mod <shift\|ctrl\|alt>` | The modifier that places the other marker |
| `/rmb extras` | Toggle the ready check and countdown buttons |
| `/rmb countdown <3-60>` | Pull timer seconds |
| `/rmb reset` | Back to defaults |
| `/rmb status` | Why can I not see it |

`/raidmarkerbar` works anywhere `/rmb` does.

The bar is locked by default. `/rmb lock` shows a drag handle; unlocking while
solo forces the bar on screen so there is something to drag.

## Installation

Download from CurseForge, or clone this repository into
`World of Warcraft/_retail_/Interface/AddOns/RaidMarkerBarLite`. There is no build
step and nothing to embed.

## Development

```
make check     # luacheck + stylua --check
make test      # lua5.1 tests/run.lua
make format    # stylua .
make package   # BigWigsMods packager, local zip, uploads nothing
```

The tests run the addon against a stubbed client under plain Lua 5.1; no game
needed.

## License

MIT — see [LICENSE](LICENSE).
