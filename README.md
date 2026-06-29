# Spotter [DEPRECATED] - I never really got this working, seems impossible with the limitations of the WoW addon system. Probably whiy this addon doesn't exist already.

A World of Warcraft addon that points the native 3D waypoint arrow at the nearest known ore node, using GatherMate2's harvested node database for positions.

Toggle with `/ore` or the minimap button.

> **Status: shelved.** The core goal — "arrow points at live ore" — is not fully achievable via the WoW Lua API. See [Why this is hard](#why-this-is-hard) for the full technical breakdown. What Spotter *can* do is route you through known spawn points (same data GatherMate2/Routes use), auto-skipping empty ones as you arrive. It works, but it's closer to "guided farming route" than "ore detector."

## Requirements

- **GatherMate2** + **GatherMate2_Data** (or any data plugin that populates GatherMate2's database). Spotter reads GM2's mining node database for positions. Without it, Spotter has nothing to route to and will warn on startup.
- **HereBeDragons-2.0** is embedded and ships with the addon.

## Slash commands

| Command | Effect |
| --- | --- |
| `/ore` | Toggle tracking on/off |
| `/ore on` / `/ore off` | Force on/off |
| `/ore skip` | Reject current target (3 min cooldown), route to next closest |
| `/ore clear` | Clear the active waypoint |
| `/ore scan` | Print the 5 closest known nodes with distances |
| `/spotter ...` | Alias for `/ore` |

Minimap button: **left-click** toggles, **right-click** clears the waypoint, **drag** repositions.

## How it works

1. Every second, `Scanner.lua` queries GatherMate2's mining database for every known ore spawn point in the current zone.
2. Each spawn point's zone coordinates are converted to world coordinates via HereBeDragons, and the distance from the player is computed.
3. `Verifier.lua` filters out nodes that are on a respawn cooldown (recently visited/mined).
4. `Core.lua` picks the nearest eligible node and sets the native WoW user waypoint + supertrack arrow.
5. When you arrive within 15 yards, the node is auto-cooldown'd for 3 minutes and the arrow moves to the next closest node.
6. When you successfully mine (detected via `UNIT_SPELLCAST_SUCCEEDED`), the current target is cooldown'd immediately.
7. `/ore skip` lets you manually reject a target from a distance if you can see it's empty.

| File | Purpose |
| --- | --- |
| `Core.lua` | Events, SavedVariables, scan ticker, slash commands, mining detection |
| `Scanner.lua` | Queries GatherMate2's mining DB, computes distances via HBD |
| `Verifier.lua` | Respawn cooldown tracking |
| `Waypoint.lua` | `C_Map.SetUserWaypoint` + `C_SuperTrack` plumbing, ownership tracking |
| `MinimapButton.lua` | Draggable minimap button (no LibDBIcon dep) |
| `embeds.xml` | Loads HereBeDragons |
| `.pkgmeta` | BigWigs packager config + HereBeDragons external |

---

## Why this is hard

The dream feature is simple: "point an arrow at ore that's actually there right now." It turns out this is not possible in modern retail WoW (11.x / The War Within era) via the Lua addon API. Here's what we tried and why each approach failed.

### Approach 1: Read minimap tracking blips directly

**Idea:** When "Find Minerals" is active, ore nodes appear as yellow dots on the minimap. Read the pixel positions of those dots, convert to world coordinates, set a waypoint.

**Implementation:** Iterate `Minimap:GetChildren()`, find anonymous Button/Frame children that look like tracking blips, compute their pixel offset from the minimap center, convert to yards using the known minimap-zoom-to-yards table, de-rotate if `rotateMinimap` is on, add to the player's world position from HereBeDragons.

**Why it failed — three compounding problems:**

1. **Tracking blips are not Lua frames in modern retail.** We enumerated every child of `Minimap` while standing next to a visible ore node with Find Minerals active. Result: zero visible anonymous frames that correspond to tracking blips. The only visible anonymous child was a 40x40 Frame (likely an addon widget). Everything else was hidden 18x18 pool frames at offset (0,0). Blizzard moved tracking-blip rendering to the C++ minimap system sometime in the Dragonflight-TWW era. There is no Lua representation of tracking dots.

2. **Edge clamping.** Even in older client versions where blips *were* Lua frames, any node outside the visible minimap radius gets its blip "clamped" to the rim of the minimap circle. The pixel position no longer reflects the true distance — only the bearing is correct. This means the computed world position drifts with the player (always "minimap-radius yards away in that direction"), producing waypoints that jump and get farther as you move.

3. **No identity on blips.** Minimap children have no tooltip, no name, no texture you can reliably filter on to distinguish ore from herbs, quest POIs, group members, vignettes, or addon widgets. Any heuristic based on frame type, size, or texture is fragile and breaks across client patches.

**Verdict:** Dead end in modern retail. The data simply isn't exposed to Lua.

### Approach 2: Bearing-match blips against a known database

**Idea:** Use GatherMate2 for *positions* (exact, stable) and minimap blips for *presence confirmation* (is something actually there right now?). Don't trust blip positions at all — only compare the angular bearing of each blip to the bearing of each GM2 candidate. A match means "confirmed live." No match within minimap range means "suspect — probably empty."

**Why it failed:** Depends on Approach 1 working at least partially — we need to detect that blips *exist*, even if we don't trust their positions. Since tracking blips aren't Lua frames at all in modern retail, there are no bearings to compare. The verifier classified everything as "unverified" and fell through to pure-GM2 distance routing.

**Verdict:** Architecturally sound, but blocked by the same C++ rendering wall.

### Approach 3: Pure GatherMate2 database (current implementation)

**Idea:** Forget live detection entirely. GatherMate2's database contains coordinates of every ore node ever harvested by players, aggregated from millions of visits via Wowhead data imports. Route to the nearest known spawn point.

**Tradeoff:** GM2 knows where nodes *can* spawn, not where they *currently* are. Many entries point to valid spawn locations that happen to be empty right now (recently mined by someone else, or on a respawn timer). The waypoint will sometimes point at nothing.

**Mitigations:**
- Auto-cooldown on arrival (15 yds) so you cycle through empty spawns quickly
- Mining-event detection (`UNIT_SPELLCAST_SUCCEEDED`) for immediate cooldown + reroute
- `/ore skip` for manual rejection from a distance
- 3-minute cooldown matches typical ore respawn timers

**Verdict:** This is what ships. It's functional but the UX is "guided farming route through known spawn points" rather than "live ore detector." This is the same fundamental model that Routes, GatherMate2's own map pins, and FarmHud use — they all show *possible* locations, not confirmed-live ones.

### What would actually work (but doesn't exist)

- **A Blizzard API like `C_Minimap.GetTrackingPOIs()`** that returns world positions of active tracking blips. This API does not exist.
- **`C_Minimap.GetTrackingInfo()`** tells you *which tracking types are active* (Find Minerals = on/off) but gives zero information about where blips are.
- **`C_VignetteInfo`** gives exact world positions of vignettes (rares, treasures), but standard ore nodes are not vignettes.
- **Nameplate/unit APIs** don't cover resource nodes — they're world objects, not units.
- **GameTooltip scanning** works if the player mouses over a blip, but you can't programmatically trigger a mouseover on a specific tracking dot.

If Blizzard ever exposes tracking-blip positions via Lua, the bearing-match approach (Approach 2) would be the right architecture — GM2 for stable positions, blips for live confirmation.

---

## Local development

### One-time setup

```bash
git clone <this-repo> ~/dev/spotter
cd ~/dev/spotter
make build    # runs BigWigs packager, pulls HereBeDragons into .release/
make dev      # copies working dir + Libs into WoW AddOns folder
```

### The inner loop

1. Edit `.lua` files.
2. `make dev` to sync to the AddOns folder.
3. `/reload` in game.
4. `/ore scan` to verify behavior.

### Makefile targets

| Target | What it does |
| --- | --- |
| `make dev` | Copies working directory to WoW AddOns folder. No git dependency. Fast. |
| `make build` | Runs BigWigs packager (uses git). Produces `.release/Spotter/`. |
| `make deploy` | Rsyncs `.release/Spotter/` to WoW AddOns folder. |
| `make lint` | Runs luacheck. |
| `make clean` | Removes `.release/`. |

`make dev` copies directly from the working directory — uncommitted and untracked files are included. Use this for development. `make build` uses the BigWigs packager which reads from git — only committed/tracked files are included. Use this for release builds.

### Debugging

- `/console scriptErrors 1` or install **BugSack + BugGrabber** for Lua error visibility.
- `/dump <expr>` — pretty-print any Lua value.
- `/ore scan` — Spotter's built-in diagnostics.
- **ViragDevTool** — interactive table browser for inspecting frames, `SpotterDB`, etc.

### SavedVariables

`SpotterDB` is written to:

```
_retail_/WTF/Account/<ACCOUNT>/SavedVariables/Spotter.lua
```

Delete to reset state.
