# CatchIT

Fishing helper and item destroyer for WoW Forever (and the other clients the two source addons supported).

- **Fishing**: Cast and Interact key (casts, and while fishing interacts with the bobber; set it on the Keybinds tab or in Key Bindings > CatchIT), Cast with Lure key (casts, does nothing while fishing), Apply Lure (both keys put a lure on the pole first when it has none), soft target while fishing, Auto Loot (optionally opening the caught clams and containers, or all containers of the bags), Hide Nameplates, Enhance Sounds (optionally keeping only the sounds of the bobber).
- **Statistics**: sessions (a pause of up to 5 minutes keeps one going) and catches by location, `/catchit stats`, Reset Session and Reset All buttons, and a small Session Panel while fishing (End ends the session).
- **Destroyer** (UI and lists from Dejunk): the *Destroy Next Item* keybind destroys items from the Global list (all characters) or the Profile list (current character). Nothing outside the lists is ever destroyed, and there is no confirmation (Safe Destroy is always off).
- Open the settings with the minimap icon or `/catchit`. `/catchit bind cast KEY catch KEY destroy KEY` (any of the pairs) sets the keys of Cast with Lure, Interact with Mouseover and Destroy Next Item (WoW key names such as `NUMPAD9`); the CatchIT app types it in one line on its button *Set keys in WoW*.

## Install

CatchIT (the app) installs and updates this addon by itself: it offers it when the game runs and reloads the interface.
By hand: download `CatchIT-addon-<version>.zip` from Releases and unzip it into `<WoW>\<flavor>\Interface\AddOns`
(the folder `CatchIT` goes there).

Each release has `addon-manifest.ini` (version, file name, size and SHA256 of the zip), which CatchIT reads.

Saved variables: `CatchITDB` (account wide, profile lists are stored per character inside it) and `CatchITStatsDB` (statistics, per character).

## Credits

CatchIT is built on Dejunk and inspired by BetterFishing. Thank you to their authors:

- **BetterFishing** by Yuyuli (https://www.curseforge.com/wow/addons/betterfishing): the idea of one key that casts and then interacts with the bobber, and of the fishing options. The fishing part of CatchIT is its own code.
- **Dejunk** by moody (https://github.com/moody/Dejunk): the destroyer, its lists and the UI. MIT License, see `LICENSE.Dejunk`.
