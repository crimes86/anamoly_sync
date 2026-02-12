# Anomaly Sync --- Full Game Specification

Updated: 2026-02-12

------------------------------------------------------------------------

## 1. Vision

Anomaly Sync is a 2D top-down space sandbox built in Godot 4, designed around:

- Massive-feeling instanced sector exploration
- Automatic proximity-based anomaly attunement with orbital mechanics
- Long-tail relic economy inspired by torrent seeding psychology
- Connected sector traversal inspired by The Infinite Black
- Cross-platform (PC + Mobile) from day one

The core fantasy:

> Discover anomalies early, survive the swarm, collect relics, and earn long-term credit when the meta shifts.

------------------------------------------------------------------------

## 2. Core Gameplay Loop

1. Player starts docked at Home Base (S_0_0).
2. Opens galaxy map overlay (M key) to plan route.
3. Navigates sector-by-sector via edge-jumping, consuming fuel.
4. Detects anomaly signal in a sector.
5. Flies near anomaly — ship is pulled into automatic orbit.
6. Survives escalating threats while sync progresses.
7. Completes sync — receives a Relic from the anomaly's family (specific relic + rarity is RNG).
8. Relic stored in Codex Vault.
9. Warps home (Q hold, 8 sec channel) to refuel, or continues exploring.
10. Relic generates long-term resonance credit when demand rises via recipes and meta shifts.

------------------------------------------------------------------------

## 3. World Structure

### 3.1 Galaxy Map

- 8x6 grid of sectors with connected traversal (all cardinal neighbors connected).
- ~20% of sectors are **void** (impassable empty space), creating chokepoints and interesting navigation.
- Void sectors never spawn adjacent to the starting sector.
- Fog of war on unexplored sectors (dimmed signal indicators).
- Map overlay (M key) toggleable during sector exploration, persists across sector transitions.
- Sector color indicators on map:
    - **Green dot** — Available anomaly, not yet synced by player
    - **Blue dot** — Player has synced this anomaly (global pool may still have syncs)
    - **Red dot** — Globally depleted (sync pool = 0)
    - **Gold border** — Home Base
    - **Blue border** — Connected jumpable sector
- Sector metadata:
    - Signal Strength (0.2–1.0 for anomaly sectors)
    - Stability (0.5–1.0)
    - Threat Index (unknown until entered)
    - Anomaly Family (FRACTAL, VOID, PULSE, DRIFT, ECHO)

### 3.2 Sector Instance

Each sector is a separate Godot scene. Contains:

- Player ship
- Central Anomaly (if sector has one; removed if not)
- NPC threats (future)
- Orbit ring zones (outer 320px, mid 180px, core 80px)
- Sector bounds: 1280x720

### 3.3 Home Base (S_0_0)

- Starting sector, never contains an anomaly.
- Station graphic at center with pulsing beacon and docking arms.
- **Fuel regeneration**: ~1.67/sec within 250px of station (~60 seconds for full tank).
- **Health regeneration**: 20 HP/sec within station radius.
- Warp (Q) from any sector returns player here.
- Game launches directly into home base.
- Gold border on galaxy map for visibility.

### 3.4 Void Sectors

- ~20% of grid cells are void — they don't render, can't be entered, and have no connections.
- Creates natural chokepoints, dead ends, and forces route planning.
- Never generated adjacent to home base.

------------------------------------------------------------------------

## 4. Navigation System (Inspired by The Infinite Black)

### 4.1 Sector Traversal

- Sectors are connected to all cardinal (N/S/E/W) non-void neighbors.
- Player traverses sector-by-sector, no direct warping to distant sectors.
- Each jump costs **8 fuel** (max fuel: 100).
- Creates routes and paths players follow to reach anomalies.

### 4.2 Edge-of-Sector Jumping

- Flying to the sector boundary (within 20px of edge) starts a **3-second channel**.
- Channel progress is visible on the HUD ("JUMPING EAST...").
- **Damage interrupts** the channel (knocks 30% off progress).
- Moving away from the edge cancels the channel.
- On completion, player transitions to the adjacent connected sector.
- Player spawns on the **entry side** of the new sector (jump south → spawn at top).

### 4.3 Jump Cooldown

- 2-second cooldown after arriving in a new sector before edge-jumping again.
- Prevents instant chain-jumping to escape danger.

### 4.4 Warp Home (Q Hold)

- 8-second channel, damage interrupts (knocks 25% off progress).
- Returns player to Home Base sector.
- Fuel is NOT instantly restored — must regen at station over ~60 seconds.

------------------------------------------------------------------------

## 5. Anomaly Mechanics

### 5.1 Auto-Attune

Triggered automatically when ship enters orbit radius.

```
sync_progress += (sync_rate * delta)
sync_rate = base_rate * distance_modifier * ship_modifier * stability_modifier
```

Progress decays (de-sync at 0.03/sec) when player leaves orbit radius. Once sync reaches 100%, it locks permanently.

### 5.2 Orbit Tiers

| Orbit Ring | Radius | Sync Multiplier | Risk Level |
|------------|--------|-----------------|------------|
| Outer      | 320px  | 0.6x            | Low        |
| Mid        | 180px  | 1.5x            | Medium     |
| Core       | 80px   | 3.0x            | High       |

Closer orbit = faster sync, higher danger.

### 5.3 Automatic Orbital Pull

When ship enters orbit range, gravitational forces pull it into a circular orbit:

| Tier  | Orbit Speed | Inward Pull | Escape Difficulty |
|-------|-------------|-------------|-------------------|
| Outer | 50          | 5           | Easy              |
| Mid   | 80          | 12          | Moderate          |
| Core  | 120         | 25          | Hard              |

- Ship orbits clockwise automatically.
- Player input at 85% effectiveness while in orbit — can steer or thrust outward to escape.
- Minimum orbit radius of 60px prevents uncontrollable spinning.
- Orbit speed scales with distance (tighter = proportionally slower for stability).

### 5.4 Anomaly Depletion

- Each anomaly has a **sync pool** (5–20 syncs depending on generation).
- Each successful sync (by any player) decrements the pool by 1.
- At 0, the anomaly is **globally depleted** — marked red on the map.
- Player can only sync each anomaly **once** (tracked via `player_synced` flag).

### 5.5 Anomaly State Persistence

- Sync state persists across sector transitions via GameState.
- Revisiting a synced anomaly shows sync bar at 100% (locked).
- HUD shows "[SYNCED]" or "[DEPLETED]" status.

------------------------------------------------------------------------

## 6. Combat System

### 6.1 Player Weapons

- Spacebar to shoot projectiles in facing direction.
- Fire rate: 0.2 seconds between shots.
- Projectile speed: 600, damage: 10, lifetime: 2 seconds.

### 6.2 Ship Stats

- Health: 100 HP
- Move speed: 300
- Collision layers: player (1), enemies (2), projectiles (3), anomaly zones (4)

### 6.3 Damage Effects

- Damage interrupts warp channel (−25% progress).
- Damage interrupts edge-jump channel (−30% progress).
- Ship destroyed → return to home base (no relic reward).

------------------------------------------------------------------------

## 7. Threat System (Milestone 3)

Threat waves spawn based on:

- Number of ships in sector
- Signal intensity
- Time elapsed

Damage interrupts warp-out charge (8 sec channel).

------------------------------------------------------------------------

## 8. Relic System

### 8.1 Relic Data Model

```
relic_id: string
family: string
rarity: int (1-5)
base_power: int
demand_multiplier: float
spotlight_tags: list[string]
```

### 8.2 Relic Drop Mechanics

- On sync completion, a relic is rolled from the **anomaly's family**.
- Family is deterministic (tied to the anomaly), specific relic + rarity is RNG.
- Rarity is weighted: lower rarity = higher drop chance (inverse weight).
- This allows targeted farming by family while keeping RNG excitement.

### 8.3 Relic Families

| Family  | Tags                    | Flavor               |
|---------|-------------------------|----------------------|
| FRACTAL | geometric, recursive    | Structural patterns  |
| VOID    | dark, entropic          | Entropy and barriers |
| PULSE   | energy, kinetic         | Energy transfer      |
| DRIFT   | temporal, passive       | Time manipulation    |
| ECHO    | resonant, harmonic      | Sound and resonance  |

Each family has 3 relics at rarity 1, 2, and 4-5.

### 8.4 Codex Vault

- Stores relics permanently.
- Shows: Rarity, Times synced globally, Current demand multiplier, Availability %
- Vault has capacity limit (starting 10, expandable via recipes).

------------------------------------------------------------------------

## 9. Long-Tail Demand System

Relics never expire.

Demand changes due to:

- **Recipe requirements** (primary driver) — recipes require specific relics, creating organic demand.
- Balance patches
- Weekly spotlight modifiers (family-wide multiplier)
- Meta rotations

Effective value formula:

```
effective_value = rarity_weight * demand_multiplier * base_power
```

Spotlight example: `active_spotlight = "FRACTAL"`, `multiplier = 2.0` — all FRACTAL relics produce double credit.

------------------------------------------------------------------------

## 10. Relay System (Future — Milestone 4)

Modeled after BitTorrent seeding psychology:

| Torrent Concept       | Anomaly Sync Equivalent              |
|-----------------------|--------------------------------------|
| Original source       | The anomaly (alive)                  |
| Downloading           | Syncing the anomaly directly         |
| Having the file       | Relic in your vault                  |
| Seeding to peers      | **Relaying** to other players        |
| Upload ratio/credit   | Resonance credit from relays         |
| Torrent health        | **Availability %** in Codex          |
| Dead torrent          | Relic unobtainable (no seeders)      |

Flow:

1. Anomaly spawns → early players sync directly (the "original source").
2. Anomaly depletes → direct sync is gone.
3. Players who hold the relic can **relay** (seed) it to others.
4. Relaying costs the receiver credit; the **seeder earns credit**.
5. Fewer seeders + high recipe demand = **massive seeder profit**.
6. A relic with zero holders is **extinct** — gone forever unless the anomaly respawns.

------------------------------------------------------------------------

## 11. Resonance Credit Economy

Players earn credit from:

- Sync completion (value based on relic rarity and demand)
- Relay contributions (future P2P)
- Passive relic demand spikes

Credit uses:

- Ship upgrades
- Vault expansion
- Cosmetic auras
- Sync efficiency modules

### 11.1 Recipes (Implemented)

Recipes create demand by requiring specific relics:

| Recipe               | Ingredients                        | Result                     |
|----------------------|------------------------------------|----------------------------|
| Sync Amplifier Mk1   | 3x Echo Fragment, 2x Pulse Spark  | +15% sync rate             |
| Hull Reinforcement    | 2x Void Membrane, 4x Drift Mote  | +25 max health             |
| Warp Stabilizer       | 1x Drift Anchor, 5x Fractal Shard| -2 sec warp charge time    |
| Vault Expansion       | 2x Fractal Lattice, 2x Echo Res. | +5 vault slots             |

------------------------------------------------------------------------

## 12. UI Specification

### HUD (In-Sector)

- Top Left: Sector ID, anomaly family, status ([SYNCED]/[DEPLETED]/HOME BASE)
- Top Left Row 2: Orbit tier indicator (CORE/MID/OUTER/OUT OF RANGE/DOCKED)
- Top Left Row 3: Fuel display
- Bottom Left: Sync progress bar
- Bottom Right: Hull health bar
- Bottom Right Row 2: Warp charge bar [Q]
- Top Center: Edge jump indicator + progress bar (hidden until active)
- Top Right: Credits display
- Center: Relic acquired popup (3 sec duration)

### Galaxy Map Overlay (M Key)

- Toggleable during exploration, persists across sector transitions.
- Shows full galaxy grid with connections, player position, fuel bar.
- Same color coding as full galaxy map.

### Galaxy Map (Full Screen — accessed from home base)

- Full grid view with connection lines.
- Fuel bar and status line at bottom.
- Click to select, double-click connected sector to jump.

### Codex Screen (Milestone 2)

- Relic list
- Filter by family
- Highlight trending relics
- Show simulated or real sync activity

------------------------------------------------------------------------

## 13. Godot Project Structure

```
res://
  scenes/
    galaxy_map.tscn + .gd       # Full-screen galaxy map
    sector.tscn + .gd           # Instanced sector scene
    ship.tscn + .gd             # Player ship
    anomaly.tscn + .gd          # Anomaly with orbital mechanics
    projectile.tscn + .gd       # Player bullet
    home_station.gd             # Home base station visual + regen
  ui/
    hud.tscn + .gd              # In-sector HUD
    map_overlay.tscn + .gd      # Toggleable galaxy map overlay
    map_overlay_panel.gd        # Map overlay drawing logic
    virtual_joystick.gd         # Mobile touch input
  systems/
    game_state.gd               # Autoload: sectors, connections, fuel, save/load
    relic_db.gd                 # Autoload: relic definitions, vault, RNG rolls
    demand_manager.gd           # Autoload: spotlight, recipes, demand calc
    attunement.gd               # Sync math: orbit tiers, de-sync, completion
    credit_ledger.gd            # Autoload: transaction logging
  data/
    relics.json                 # 15 relics across 5 families
    meta_config.json            # Spotlight config, 4 starter recipes
  assets/                       # Sprites, audio (future)
```

### Autoload Order

1. RelicDB
2. DemandManager
3. CreditLedger
4. GameState

------------------------------------------------------------------------

## 14. Prototype Milestones

### Milestone 1 (Current — Implemented)

- [x] Galaxy map with connected sector grid
- [x] Void sectors (~20%) for navigation variety
- [x] Sector-by-sector traversal with fuel cost
- [x] Edge-of-sector jumping with 3-sec channel
- [x] Ship movement, shooting, warp-out
- [x] Anomaly auto-attune with orbit tiers
- [x] Automatic orbital pull mechanics
- [x] Sync progress bar with de-sync on leaving orbit
- [x] Relic reward on sync (family-deterministic, rarity-RNG)
- [x] Anomaly state persistence (no re-syncing)
- [x] Anomaly depletion tracking
- [x] Home Base with station graphic, fuel/health regen
- [x] Map overlay (M key) with persistent toggle
- [x] Map color indicators (green/blue/red)
- [x] Fuel system with regen at home base (~60 sec full refuel)
- [x] Credit ledger and demand system
- [x] Recipe-driven demand

### Milestone 2

- [ ] Codex Vault UI screen
- [ ] Recipe crafting UI
- [ ] Manual meta shift toggle (spotlight rotation)
- [ ] Relic detail view with demand graph
- [ ] Ship upgrade application from crafted items

### Milestone 3

- [ ] Threat wave spawning system
- [ ] Enemy AI (patrol, chase, attack)
- [ ] Multiple enemy types
- [ ] Difficulty scaling by sector signal intensity
- [ ] Sound effects and ambient audio

### Milestone 4 (Networking & Relay)

- [ ] Server authoritative sector state
- [ ] Global anomaly depletion (shared sync pools)
- [ ] Relay system — seed relics to other players for credit
- [ ] Availability % tracking (torrent health)
- [ ] Relay marketplace / NPC relay market for single-player

### Milestone 5 (Polish)

- [ ] Sprite assets replacing polygon placeholders
- [ ] Particle effects for anomalies, warp, combat
- [ ] Mobile UI optimization (virtual joystick, touch fire)
- [ ] Cloud save system
- [ ] Tutorial / onboarding flow
- [ ] Anomaly respawn system (depleted anomalies reappear elsewhere)

------------------------------------------------------------------------

## 15. Cross-Platform Design Principles

- Use Godot Input Actions exclusively.
- Avoid heavy particle systems.
- UI built with anchors/containers.
- Avoid high network throughput.
- Simulate file size instead of real bandwidth use.
- Virtual joystick for mobile, keyboard/mouse for PC.

------------------------------------------------------------------------

## 16. Emotional Pillars

- Uncertainty when jumping sectors (what threats await?)
- Physical hierarchy via orbit rings (risk/reward of getting closer)
- Gravitational pull creating tension (locked in orbit while threats approach)
- Early arrival advantage (first to sync = guaranteed relic)
- Long-tail relic value (your old relic spikes in value from a meta shift)
- Route planning tension (fuel management, choosing paths through void gaps)
- Seeder pride (future: being the only source of a rare relic)

------------------------------------------------------------------------

End of Specification.
