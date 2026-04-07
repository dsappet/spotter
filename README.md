# Spotter

A World of Warcraft addon that scrapes live minimap blips (with **Find Minerals** active), converts them to map coordinates via HereBeDragons-2.0, and points the native WoW floating 3D waypoint arrow at the nearest ore node.

Toggle with `/ore` or the minimap button.

## What's in the box

| File | Purpose |
| --- | --- |
| `Spotter.toc` | Addon manifest |
| `embeds.xml` | Loads HereBeDragons (pulled in by the packager) |
| `Core.lua` | Events, SavedVariables, scan ticker, slash commands |
| `Scanner.lua` | Minimap blip scrape + pixel→world coord conversion |
| `Waypoint.lua` | `C_Map.SetUserWaypoint` + `C_SuperTrack` plumbing |
| `MinimapButton.lua` | Draggable minimap button (no LibDBIcon dep) |
| `.pkgmeta` | BigWigs packager config + HereBeDragons external |

## Slash commands

| Command | Effect |
| --- | --- |
| `/ore` | Toggle tracking |
| `/ore on` / `/ore off` | Force on/off |
| `/ore clear` | Clear the active waypoint |
| `/ore scan` | One-shot scan; prints found blips with distances and zone coords |
| `/spotter ...` | Alias for `/ore` |

Minimap button: **left-click** toggles, **right-click** clears the waypoint, **drag** repositions.

---

## Local development

### Requirements

- A retail WoW install
- `bash`, `curl`, `svn`, `git` (for the packager and the HereBeDragons external)
- Optional but strongly recommended in-game: **BugSack + BugGrabber** (catches Lua errors), **ViragDevTool** (interactive table browser)

### One-time setup

Clone the repo, then build the addon locally so HereBeDragons gets pulled into `Libs/`:

```bash
git clone <this-repo> ~/dev/spotter
cd ~/dev/spotter
curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -dlz
```

Packager flags:

- `-d` skip CurseForge upload (no API token needed)
- `-l` skip `@localization@` keyword replacement
- `-z` skip building the release zip

This produces `.release/Spotter/` containing your source plus `Libs/HereBeDragons/`. That folder is exactly what end-users would install.

Re-run that command any time you want to refresh externals (HBD updates rarely — practically just once at setup, and again when a WoW patch breaks something).

### Symlink into the AddOns folder

Symlink the **packager output**, not the repo source — that way your repo stays clean and the game loads the same layout end-users will see.

**macOS / Linux:**

```bash
ln -s "$PWD/.release/Spotter" "/Applications/World of Warcraft/_retail_/Interface/AddOns/Spotter"
```

**Windows (PowerShell, admin):**

```powershell
New-Item -ItemType Junction `
  -Path "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Spotter" `
  -Target "C:\path\to\spotter\.release\Spotter"
```

### The inner loop

1. Edit a `.lua` file in your editor.
2. In game, type `/reload` (bind it to a macro for speed).
3. Watch BugSack (or chat) for errors.
4. `/ore scan` to verify behavior.

You only need to **re-run the packager** when you change `.toc`, `embeds.xml`, `.pkgmeta`, or want fresh externals. `.lua` edits are picked up by `/reload` directly.

You only need to **relog** if the addon breaks hard enough to taint the load order (rare).

### Turn on Lua errors

Default WoW silently swallows errors. Either:

```text
/console scriptErrors 1
```

…for the built-in popup, or install **BugSack + BugGrabber** for stack traces and a browsable error history. Without one of these you'll waste hours wondering why nothing happens.

### Live debugging

- `/dump <expr>` — pretty-print any Lua value, e.g. `/dump Minimap:GetNumChildren()`
- `/run <stmt>` — execute a one-liner. Handy snippet for inspecting what the blip filter sees:

  ```text
  /run for i=1,Minimap:GetNumChildren() do local c=select(i,Minimap:GetChildren()) print(i, c:GetName(), c:GetObjectType(), c:IsVisible()) end
  ```

- **ViragDevTool** — interactive table browser. Invaluable for poking at frames, the addon namespace, `SpotterDB`, etc.
- `/ore scan` — Spotter's own fastest feedback loop; reports candidate blip count, distances, and zone coords.

### SavedVariables

`SpotterDB` is written to disk on logout/reload at:

```text
_retail_/WTF/Account/<ACCOUNT>/SavedVariables/Spotter.lua
```

Open it to verify defaults serialized correctly. Delete it to reset state.

### Linting

```bash
luarocks install luacheck
luacheck . --std max+lua51 --no-max-line-length
```

A `.luacheckrc` at the repo root with WoW globals (`Minimap`, `C_Map`, `C_SuperTrack`, `C_Timer`, `CreateFrame`, `LibStub`, `GetCVar`, `GetPlayerFacing`, `UiMapPoint`, `GameTooltip`, `GetCursorPosition`, `SpotterDB`, `SLASH_SPOTTER1`, `SLASH_SPOTTER2`, `SlashCmdList`) saves you from listing them every run.

### Suggested commit cadence

Small, focused commits make it much easier to bisect when the minimap blip-detection heuristic breaks on a new client patch. Good split points: scan loop, rotation math, button drag, waypoint dedupe, etc.

---

## How blip detection works

`Scanner.lua` iterates `Minimap:GetChildren()` and keeps **anonymous** Buttons/Frames — named children (`MinimapBackdrop`, zoom buttons, etc.) are UI chrome, and the player arrow is its own frame.

For each candidate:

1. Pixel offset from minimap center → yards via the canonical minimap zoom table.
2. Rotated by `GetPlayerFacing()` if `rotateMinimap` CVar is on.
3. Added to `HBD:GetPlayerWorldPosition()` to get a world coordinate.
4. Converted back to zone coords via `HBD:GetZoneCoordinatesFromWorld` so rotated zones (Azshara etc.) Just Work.

The scanner assumes only **Find Minerals** is active. If you have multiple tracking types enabled, the picked nearest may be a herb / vein / fish.

Blip-scraping is the historically-fragile part of any addon like this — expect to iterate on `IsLikelyTrackingBlip` once you see what the live minimap actually exposes on your client build.

## Waypoint API note

The native floating 3D arrow uses `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`. `C_Navigation` is the *query* side (`GetDistance`, `GetTargetState`) for whatever is currently being supertracked — not where you set the waypoint.
