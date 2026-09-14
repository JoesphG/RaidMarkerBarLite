<!--
Source for the CurseForge project description. There is no API for it, so it
is pasted by hand into the Description editor with the format set to Markdown.
-->

**Every raid marker one click away, in combat too.**

RaidMarkerBar is a movable row of the eight target markers, a clear button, a
ready check and a pull countdown. It carries no libraries and no dependencies,
and the marker buttons are secure action buttons, so they keep working when the
fight has started and a marker is what you actually need.

## Features

- **Works in combat.** The buttons run on macro text through Blizzard's secure
  action button template, so placing a marker mid-pull is never blocked.
- **Target and world markers from one button.** Plain click sets the target
  marker; Shift-click (or Ctrl, or Alt) drops the world marker of the same
  colour. `/rmb swap` reverses the two.
- **Clear, ready check and pull timer** sit after the markers. The countdown
  length is yours to set, and a right click on the button cancels a running
  pull.
- **Shows itself when it matters.** Always, only in a group, or only in a raid.
  In a raid without lead or assist the bar dims instead of hiding, because a
  row vanishing mid-pull is worse than a grey row.
- **Options panel** in Blizzard's Settings window, over the same settings the
  slash commands write.

## Commands

| Command | Effect |
| --- | --- |
| `/rmb` | List these commands |
| `/rmb config` | Open the options panel |
| `/rmb lock` | Toggle the drag handle |
| `/rmb size <12-64>` | Button size |
| `/rmb spacing <0-20>` | Gap between buttons |
| `/rmb vertical` | Stack the buttons in a column |
| `/rmb show <always\|group\|raid>` | When the bar is on screen |
| `/rmb swap` | Swap the plain-click and modifier actions |
| `/rmb mod <shift\|ctrl\|alt>` | The modifier that places the other marker |
| `/rmb extras` | Toggle the ready check and countdown buttons |
| `/rmb countdown <3-60>` | Pull timer seconds |
| `/rmb reset` | Back to defaults |
| `/rmb status` | Why can I not see it |

The bar starts locked. `/rmb lock` shows a drag handle, and unlocking while
solo forces the bar on screen so there is something to drag.

## Support

Bugs and ideas go to the
[issue tracker on GitHub](https://github.com/JoesphG/RaidMarkerBar/issues).
`/rmb status` prints where the bar is and why it is or is not showing, which
is usually the whole diagnosis.

Source: [github.com/JoesphG/RaidMarkerBar](https://github.com/JoesphG/RaidMarkerBar) — MIT licensed.
