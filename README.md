# Survey Map Teleport

Elder Scrolls Online add-on that adds a **Call to Zone** option to the inventory right-click menu for **opened** survey and treasure maps. Selecting it teleports you to that map's zone using [Beam Me Up](https://www.esoui.com/downloads/info2143-BeamMeUp-TeleporterFastTravel.html).

## Requirements

- [Beam Me Up](https://www.esoui.com/downloads/info2143-BeamMeUp-TeleporterFastTravel.html)
- [LibCustomMenu](https://www.esoui.com/downloads/info1146-libcustommenu.html) (same library used by Tamriel Trade Centre for inventory context menus)

## Installation

1. Copy the `SurveyMapTeleport` folder into your ESO add-ons directory, for example:
   `Documents/Elder Scrolls Online/live/AddOns/SurveyMapTeleport/`
2. Enable **Survey Map Teleport**, **Beam Me Up**, and **LibCustomMenu** on the character select add-ons screen.

## Usage

1. Open your inventory (or bank).
2. Right-click an **opened** survey report or treasure map (not a sealed survey container).
3. Choose **Call to Zone**.

Beam Me Up will port you the same way as its slash commands or zone list: to a group/friend/guild member in that zone when possible. If no one is available and recall would cost gold, it jumps to your **preferred house** for that zone (set in Beam Me Up: Houses list → right-click → *Set as preferred house*, or `/bmu/house/set/zone`). Otherwise it uses a wayshrine (if *Show zones without players or houses* is enabled in Beam Me Up).

## How it works

- Map detection follows Beam Me Up (`SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT` / `TROPHY_TREASURE_MAP`, plus localized name markers).
- Zone lookup uses `BMU.getDataMapInfo(itemId)` from Beam Me Up's `treasureAndSurveyMaps` table, with a name-based fallback via `BMU.getZoneIdFromZoneName`.
- Teleport uses `BMU.sc_porting(zoneId)`.

## License

Use and modify as you like for personal play. Beam Me Up is by its respective authors; this add-on only calls its public `BMU` API.
