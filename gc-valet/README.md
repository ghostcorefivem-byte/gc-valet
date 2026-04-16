# gc-valet

**NPC Valet Delivery + Admin Impound System for QBCore**

A lightweight, server-authoritative valet script that delivers a player's stored vehicle right to them via an NPC driver. Includes a full admin impound layer to keep the city clean — track every valet-spawned vehicle, auto-impound abandoned ones, manually impound by plate, or wipe every empty car in the city with one command.

Built for QBCore. Uses ox_lib for the menu UI and oxmysql for database access.

---

## Features

- **NPC valet delivery** — vehicle + driver spawn nearby, drives to the player, hands over the keys, NPC walks off and despawns
- **Live vehicle blip on the map** while the valet is en route (color-coded by vehicle class)
- **ox_lib context menu** listing every vehicle in the player's garage, grouped by class with emoji icons
- **Money check** — deducts from cash first, then falls back to bank
- **Server-authoritative ownership validation** — a player can never valet a vehicle they don't own
- **qb-vehiclekeys integration** — keys handed over automatically on delivery
- **Fuel support** — sets fuel on delivery for both `LegacyFuel` and `ps-fuel`
- **Full impound system:**
  - Tracks every valet-spawned vehicle by netId + plate
  - Heartbeat ping every 30 seconds while a player is seated
  - Auto-impounds abandoned vehicles (configurable idle threshold)
  - `/impound [plate]` — admin manual impound
  - `/wipecars` — admin command that sweeps the entire city for empty vehicles and removes them
  - `/listvehicles` — prints all tracked valet vehicles to console with idle times
- **Admin-locked commands** via Ace permissions (`admin` group by default)
- **90-second delivery timeout** — if the NPC can't reach the player, the vehicle is left nearby and keys are still handed over
- **Debug mode toggles** in both client and server for troubleshooting

---

## Requirements

- [`qb-core`](https://github.com/qbcore-framework/qb-core)
- [`ox_lib`](https://github.com/overextended/ox_lib)
- [`oxmysql`](https://github.com/overextended/oxmysql)
- [`qb-vehiclekeys`](https://github.com/qbcore-framework/qb-vehiclekeys) *(optional but recommended — keys are auto-given on delivery)*
- `LegacyFuel` **or** `ps-fuel` *(optional — for fuel restoration on delivery)*

Uses the standard QBCore `player_vehicles` table — no new tables required.

---

## Installation

1. Drop the `gc-valet` folder into your `resources/` directory.
2. Add this line to your `server.cfg` **after** qb-core, ox_lib, and oxmysql:

   ```
   ensure gc-valet
   ```

3. Make sure your admins have the `admin` ace permission (standard QBCore setup). Example:

   ```
   add_ace group.admin command allow
   add_principal identifier.license:XXXX group.admin
   ```

4. Restart your server. You should see these lines in console:

   ```
   [GC-VALET] Loaded! /valet — Cost: $250
   [GC-VALET IMPOUND] Loaded! /wipecars | /impound [plate] | /listvehicles
   ```

Done. That's the full install.

---

## Configuration

There are **three config blocks** to know about, each in a different file. Here's where to find them and what every setting does.

### 1. Server Config

**File location:** `gc-valet/server/server.lua` (at the very top of the file)

```lua
local Config = {
    ValetPrice   = 250,       -- Cost per valet call
    CommandName  = 'valet',   -- Command players use
    Debug        = false      -- Server-side debug logs
}
```

**`ValetPrice = 250`**
How much the player pays every time they call the valet. Raise or lower to whatever fits your server economy.

**`CommandName = 'valet'`**
The chat command players type. If you change it to `'car'` then players would type `/car` instead of `/valet`.

**`Debug = false`**
Flip to `true` when troubleshooting — prints `[VALET SERVER]` logs in console. Keep `false` in production.

---

### 2. Client Config

**File location:** `gc-valet/client/client.lua` (at the very top of the file)

```lua
local Config = {
    DeliveryRadius    = 30.0,                -- How far from player the vehicle spawns
    NPCModel          = 'a_m_m_business_01', -- Valet driver model (see NPC section below)
    DeliveryTime      = 30,                  -- Reserved
    BlipDuration      = 60000,               -- Reserved
    ArrivalDistance   = 12.0,                -- How close NPC must be to hand off the car
    DriveSpeed        = 18.0,                -- Lower = more accurate stop, higher = faster delivery
    Debug             = false                -- Client-side debug logs
}
```

**`DeliveryRadius = 30.0`**
Distance (in meters) from the player where the vehicle spawns. 30 = NPC spawns 30m away and drives to you. Lower = faster delivery but less realistic. Higher = more realistic but takes longer.

**`NPCModel = 'a_m_m_business_01'`**
The ped model used for the valet driver. See **"Changing the Valet NPC"** section below for how to pick a different one.

**`ArrivalDistance = 12.0`**
How close the NPC has to get to the player before it stops and hands over the keys. 12 = stops when within 12m of you.

**`DriveSpeed = 18.0`**
NPC driving speed. Lower values = NPC drives slower and stops more accurately. Higher = faster but might overshoot. 18 is a good balance.

**`Debug = false`**
Flip to `true` when troubleshooting — prints `[VALET DEBUG]` logs in console. Keep `false` in production.

---

### 3. Impound Config

**File location:** `gc-valet/server/impound.lua` (at the very top of the file)

```lua
local ImpoundConfig = {
    AutoImpoundInterval = 5 * 60 * 1000,
    AbandonedThreshold  = 300,
    DefaultGarage       = 'pillboxgarage',
    AdminPermission     = 'admin',
    Debug               = false
}
```

**`AutoImpoundInterval = 5 * 60 * 1000`**
How often the server checks for abandoned vehicles, in **milliseconds**. `5 * 60 * 1000` = 5 minutes. Lower it to check more often, raise it to reduce server load. Example: `10 * 60 * 1000` = every 10 minutes. See formula below to set any time you want.

**`AbandonedThreshold = 300`**
How many **seconds** a valet vehicle can sit empty before it auto-impounds. `300` = 5 minutes of the player not being seated in it. Raise it if your players complain about losing cars too fast (e.g. `600` = 10 min). See formula below.

**`DefaultGarage = 'pillboxgarage'`**
Fallback garage used when the system can't figure out where the vehicle originally came from. Must match a garage name that exists in your garage script's config.

**`AdminPermission = 'admin'`**
The ace permission group that can use `/impound`, `/wipecars`, and `/listvehicles`. Change to `'god'` or `'mod'` if you want a different staff tier to have access.

**`Debug = false`**
Flip to `true` when troubleshooting — prints detailed `[IMPOUND DEBUG]` logs to the server console showing tracking, heartbeats, and impound decisions. Keep `false` in production so the console stays clean.

---

## Time Formula (How to Change Minutes and Hours)

**I set the default to 5 minutes but you can change it to anything you want.** Here's how to calculate it.

### TIME FORMULA (milliseconds)

**Use for: `AutoImpoundInterval`**

```
minutes * 60 * 1000 = milliseconds

Every 1 minute    = 1 * 60 * 1000
Every 5 minutes   = 5 * 60 * 1000
Every 10 minutes  = 10 * 60 * 1000
Every 30 minutes  = 30 * 60 * 1000
Every 1 hour      = 60 * 60 * 1000
Every 2 hours     = 120 * 60 * 1000
Every 6 hours     = 360 * 60 * 1000
Every 12 hours    = 720 * 60 * 1000
Every 24 hours    = 1440 * 60 * 1000
```

### TIME FORMULA (seconds)

**Use for: `AbandonedThreshold`**

```
minutes * 60 = seconds

30 seconds        = 30
1 minute          = 1 * 60
5 minutes         = 5 * 60
10 minutes        = 10 * 60
30 minutes        = 30 * 60
1 hour            = 60 * 60
2 hours           = 120 * 60
```

**Example** — if you want the server to check every hour and only impound cars idle for 30 minutes:

```lua
AutoImpoundInterval = 60 * 60 * 1000,   -- check every 1 hour
AbandonedThreshold  = 30 * 60,          -- 30 minutes idle before impound
```

---

## Changing the Valet NPC

**File location:** `gc-valet/client/client.lua`

Find this line near the top:

```lua
NPCModel = 'a_m_m_business_01',
```

Change `a_m_m_business_01` to any valid GTA V ped model. The default is a guy in a business suit.

**Where to find ped model names:**

👉 [https://wiki.rage.mp/wiki/Peds](https://wiki.rage.mp/wiki/Peds)

That page has a full list of every ped model in the game. Copy the model name (like `s_m_y_valet_01` if you want an actual valet-looking NPC 😉) and paste it between the quotes.

**Fun fact:** GTA V literally has a ped model called `s_m_y_valet_01` that looks like a real valet driver — you might want to use that one!

---

## Changing Vehicle Icons on the Menu

**File location:** `gc-valet/server/server.lua`

Find the `VehicleIcons` table near the top of the file. It looks like this:

```lua
local VehicleIcons = {
    ['0'] = '🚗', ['1'] = '🚙', ['2'] = '🚐', ['3'] = '🚗',
    ['4'] = '🏎️', ['5'] = '🏎️', ['6'] = '🏎️', ['7'] = '🏎️',
    ['8'] = '🏍️', ['9'] = '🚙', ['10'] = '🚛', ['11'] = '🚚',
    ...
}
```

Each number is a vehicle class, and the emoji next to it shows up in the valet menu next to that vehicle type.

**How to change emojis:**

1. Press `Windows key + .` (period) on your keyboard — the Windows emoji picker will open
2. Search for any emoji you want
3. Replace the emoji in the code with your new one

**⚠️ FYI: Some emojis don't work in FiveM's UI.** If an emoji shows up as a weird box or question mark in-game, just pick a different one. Basic emojis (cars, planes, hearts, stars, fire, etc.) almost always work. Super new or obscure ones sometimes don't.

---

## Commands

### Player Commands

| Command | Description |
|---------|-------------|
| `/valet` | Opens the valet menu showing all vehicles in your garage. Select one and an NPC will deliver it to your location for $250. |

### Admin Commands *(requires `admin` ace permission)*

| Command | Description |
|---------|-------------|
| `/impound [plate]` | Impounds a specific vehicle by plate. Works on both valet-tracked and regular garage vehicles. |
| `/wipecars` | Scans the entire city and deletes every unoccupied vehicle. Occupied vehicles (with a real player in any seat) are safe. Any tracked valet vehicles that get wiped are returned to their garage in the DB. |
| `/listvehicles` | Prints a list of every currently tracked valet vehicle to server console with netId, plate, idle time, and garage. |

---

## How the Impound System Works

This is the part most people miss — the impound is not just a command, it's a full lifecycle system for valet-spawned vehicles.

### 1. Tracking

Every vehicle delivered by the valet gets registered in a server-side `TrackedVehicles` table keyed by its netId. Each entry stores:

- The plate
- The citizenid of the owner
- The original garage it came from
- A `spawnedAt` timestamp
- A `lastOccupied` timestamp (updated every 30s while a player is seated)

### 2. Occupied Heartbeat

While the owning player is sitting in the driver or passenger seat, the client sends a ping every 30 seconds. This keeps `lastOccupied` fresh so the vehicle is never flagged as abandoned while in use.

### 3. Auto-Impound Loop

Every 5 minutes (configurable — see the Time Formula section above), the server loops through every tracked vehicle. If `now - lastOccupied >= 300 seconds` (5 min idle), the vehicle is:

- Set back to `state = 1` in `player_vehicles` (in garage)
- Assigned back to its original garage
- Deleted from the world (broadcast to all clients)
- The owner — if online — gets a notification that their car was impounded

### 4. Manual Impound via `/impound [plate]`

Looks up the plate in the tracked table first. If found, impounds it using the full tracked flow (database + entity delete + player notify). If not found, falls back to a database-only update so you can "impound" any vehicle that exists in `player_vehicles`.

### 5. City Wipe via `/wipecars`

The server can't enumerate vehicles directly (no `GetGamePool` server-side), so the flow is:

1. Admin runs `/wipecars`
2. Server asks the admin's client (or a nearby player) to scan `GetGamePool('CVehicle')`
3. Client returns a list: `{ netId, plate, occupied (1/0) }` for every networked vehicle
4. Server processes the list — any entry with `occupied = 0` gets deleted
5. Tracked valet vehicles in that list are properly returned to their garage in the DB; untracked vehicles are just removed from the world (and if they exist in `player_vehicles` with `state = 0`, returned to garage too)
6. All online players get a broadcast notification: "X vehicles removed from the city"

**Occupied detection** checks every seat against every active player ped — if a real player is anywhere in the vehicle, it's considered occupied and skipped.

---

## Testing Commands

Quick sanity-check flow to make sure everything is wired up after install:

```
/valet              # Opens the menu. Pick any garaged vehicle.
                    # NPC should spawn within 30m, drive to you, hand keys.

/listvehicles       # After /valet, you should see your vehicle listed
                    # in server console with plate and idle time.

/impound ABC123     # Replace with an actual plate. Vehicle despawns,
                    # goes back to pillboxgarage (or its original garage).

/wipecars           # Sweeps every unoccupied vehicle in the city.
                    # Watch server console for the scan → process log.
```

### Enable Debug Mode for Troubleshooting

If something isn't working, flip these flags to `true`:

- `gc-valet/client/client.lua` → `Config.Debug = true` (valet delivery flow logs)
- `gc-valet/server/server.lua` → `Config.Debug = true` (menu + dispatch logs)
- `gc-valet/server/impound.lua` → `ImpoundConfig.Debug = true` (tracking + impound logs)

You'll get verbose `[VALET DEBUG]`, `[VALET SERVER]`, and `[IMPOUND DEBUG]` tags in console showing every step.

---

## Security Notes

This script was built server-authoritative from the ground up:

- **Ownership is validated server-side** on every valet request — a modded client can't valet a vehicle they don't own
- **Money is deducted server-side** before the delivery is dispatched
- **Admin commands check Ace permissions** on the server, not client trust
- **Net event arguments are type-checked** before being used
- **The impound world-scan** is sent to one specific client (the admin who ran the command) rather than broadcast — minimizing scan load

All critical state (tracked vehicles, database updates, impound decisions) lives on the server. The client is only responsible for visuals: spawning the entity, driving the NPC, rendering blips.

---

## Event Reference

### Client Events (triggered from server)

| Event | Purpose |
|-------|---------|
| `valet:client:showMenu` | Receives the menu options list and opens the ox_lib context menu |
| `valet:client:spawnDelivery` | Spawns the vehicle + NPC and starts the delivery sequence |
| `valet:client:vehicleImpounded` | Notifies the owner their vehicle was impounded |
| `valet:impound:deleteVehicle` | Deletes a specific netId vehicle from the world |
| `valet:impound:wipeNotify` | Broadcast notification after `/wipecars` |
| `valet:impound:requestScan` | Asks the client to scan `GetGamePool('CVehicle')` |

### Server Events (triggered from client)

| Event | Purpose |
|-------|---------|
| `valet:server:requestVehicle` | Player requested a vehicle from the menu — validates ownership and dispatches |
| `valet:impound:trackVehicle` | Registers a newly-delivered vehicle for tracking |
| `valet:impound:occupiedPing` | Heartbeat: player is still in the vehicle |
| `valet:impound:scanResult` | World-scan result from client for `/wipecars` |

> **Note:** If you run SecureServe, make sure these events are whitelisted.

---

## Credits

Built and maintained by **gc-scripts**.

Powered by QBCore, ox_lib, and oxmysql.

---

## License

Free to use and modify for your own server. Redistribution allowed with credit.
