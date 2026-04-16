# 👻 GC-Valet - FiveM QBCore Valet Script (NPC Delivery + Impound)

A lightweight, server-authoritative FiveM QBCore valet script that delivers vehicles via NPC drivers with a full admin impound system.

Designed for real servers — optimized, secure, and beginner-friendly with full setup included.

---

## 🚀 Features

* 🚗 NPC valet delivery — vehicle drives to the player and hands over keys
* 🗺 Live map blip while delivery is in progress
* 📋 ox_lib menu showing all player vehicles
* 💸 Smart payment system (cash → bank fallback)
* 🔒 Server-side ownership validation (cannot exploit vehicles)
* 🔑 qb-vehiclekeys integration (auto key handoff)
* ⛽ Fuel support (LegacyFuel & ps-fuel)

---

## 🧹 Full Impound System

* Tracks every valet vehicle (netId + plate)
* Auto-impounds abandoned vehicles
* `/impound [plate]` — manually impound
* `/wipecars` — remove all empty vehicles
* `/listvehicles` — view tracked vehicles in console

---

## ⚙️ Additional Features

* 👮 Admin-restricted commands (Ace permissions)
* ⏱ Delivery timeout fallback (vehicle still delivered)
* 🛠 Debug mode for troubleshooting
* ⚡ Fully optimized and server-controlled

---

## 📦 Dependencies

* qb-core
* ox_lib
* oxmysql

### Optional:

* qb-vehiclekeys (recommended)
* LegacyFuel or ps-fuel

✔ Uses default `player_vehicles` table (no SQL needed)

---

## 🟢 Quick Start (2 Minutes)

1. Drag `gc-valet` into your `resources` folder
2. Add to your `server.cfg`:

   ```
   ensure gc-valet
   ```
3. Make sure dependencies are installed
4. Restart your server

Done ✅

---

## 🎮 Commands

### Player

* `/valet` — open valet menu and request vehicle

### Admin

* `/impound [plate]` — impound vehicle
* `/wipecars` — clear empty vehicles
* `/listvehicles` — list tracked vehicles

---

## 🛠 Troubleshooting

### ❌ Vehicle not delivering

* Check dependencies (ox_lib, qb-core)
* Make sure player owns the vehicle

---

### ❌ Commands not working

* Check ACE permissions
* Ensure script is started

---

## 🧠 Notes

* Fully server-authoritative (secure against exploits)
* Built for performance and real server use
* Beginner-friendly with full guide included

---

## 💻 GC Scripts

Clean. Optimized. Beginner-friendly.

If you need help, open a ticket and provide details (errors, screenshots, etc.).
Discord:https://discord.gg/WZtT8VBm

---

⭐ If you like this script, consider leaving a star or buy me a coffee — it helps a lot! 😊
link: buymeacoffee.com/ghostcorescripts

Enjoy 👻✨
