# NickChanger — bankroll.su Script (adding more soon)
 
Changes your in-game CS2 name with an animated prefix that shows next to your real Steam name in the scoreboard and tab.
 
## What it looks like
 
```
⠋ Example | YourSteamName
⠙ eXample | YourSteamName
⠹ exAmple | YourSteamName
```
 
Two animations run at the same time:
- A spinning loader symbol cycles before your prefix
- A wave effect rolls through your prefix one capital letter at a time
## Setup
 
1. Save the script as `lav.lua` inside `c:\bankroll.su`
2. Open the file and change this line at the top to whatever you want:
```lua
   local YOUR_NAME = "lavlua"
```
3. Load the script in bankroll
4. Toggle **Nick Changer** in the menu to turn it on and off
## Customization
 
All tweakable values are at the top of the file:
 
| Variable | What it does | Default |
|---|---|---|
| `YOUR_NAME` | The prefix shown before your Steam name | `"lavlua"` |
| `ANIM_FRAMES` | The spinner symbols that cycle before the name | braille spinner |
| `ANIM_SPEED` | How fast the spinner cycles (seconds per frame) | `0.15` |
| `WAVE_SPEED` | How fast the wave rolls through your name (seconds per step) | `0.2` |
 
To make the wave faster, lower `WAVE_SPEED`. To change the spinner swap out the symbols in `ANIM_FRAMES`, for example:
```lua
local ANIM_FRAMES = { "★", "☆" }
```
 
## Behaviour
 
- Enabling the script saves your current Steam name and applies the animated name on top
- Disabling it restores your original Steam name automatically
- Only updates the name when something actually changes, so it won't spam the console
