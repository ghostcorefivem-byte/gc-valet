gc-valet
NPC Valet Delivery + Admin Impound System for QBCore

A lightweight, server-authoritative valet script that delivers a player's stored vehicle right to them via an NPC driver. Includes a full admin impound layer to keep the city clean — track every valet-spawned vehicle, auto-impound abandoned ones, manually impound by plate, or wipe every empty car in the city with one command.

Built for QBCore. Uses ox_lib for the menu UI and oxmysql for database access.

Features
NPC valet delivery — vehicle + driver spawn nearby, drives to the player, hands over the keys, NPC walks off and despawns
Live vehicle blip on the map while the valet is en route (color-coded by vehicle class)
ox_lib context menu listing every vehicle in the player's garage, grouped by class with emoji icons
Money check — deducts from cash first, then falls back to bank
Server-authoritative ownership validation — a player can never valet a vehicle they don't own
qb-vehiclekeys integration — keys handed over automatically on delivery
Fuel support — sets fuel on delivery for both LegacyFuel and ps-fuel
Full impound system:
Tracks every valet-spawned vehicle by netId + plate
Heartbeat ping every 30 seconds while a player is seated
Auto-impounds abandoned vehicles (configurable idle threshold)
/impound [plate] — admin manual impound
/wipecars — admin command that sweeps the entire city for empty vehicles and removes them
/listvehicles — prints all tracked valet vehicles to console with idle times
Admin-locked commands via Ace permissions (admin group by default)
90-second delivery timeout — if the NPC can't reach the player, the vehicle is left nearby and keys are still handed over
Debug mode toggles in both client and server for troubleshooting
Requirements
qb-core
ox_lib
oxmysql
qb-vehiclekeys (optional but recommended — keys are auto-given on delivery)
LegacyFuel or ps-fuel (optional — for fuel restoration on delivery)
Uses the standard QBCore player_vehicles table — no new tables required.
Credits
Built and maintained by gc-scripts.

Powered by QBCore, ox_lib, and oxmysql.

License
Free to use and modify for your own server. Redistribution allowed with credit.
