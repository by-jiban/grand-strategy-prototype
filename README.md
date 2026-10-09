# Grand Strategy Prototype

A real-time 2D grand strategy game prototype for Asia-Pacific, inspired by Supreme Ruler and Age of History. Built with Godot 4.7 for Android, Linux and Windows.

**Status:** early prototype (v0.0.1). Expect bugs and missing features.

## What works
- Main menu and loading screen
- Touch-friendly map: drag to pan, pinch or scroll to zoom, tap to select
- Country selection with population and GDP info
- Game clock with pause and 10 speed levels
- Country data loaded from `data/countries.json`

## Download
Get the latest build from the [Releases](../../releases) page:
- **Windows:** unzip and run `GrandStrategy.exe` (Windows may show a SmartScreen warning; click "More info" then "Run anyway")
- **Linux:** extract the `.tar.gz`, then run `chmod +x GrandStrategy.x86_64` and `./GrandStrategy.x86_64`
- **Android:** install the `.apk` (allow installing from unknown sources). This is a debug build for testing.

## Controls
| Action | Mouse | Touch |
|---|---|---|
| Pan | drag | one finger drag |
| Zoom | scroll wheel | pinch |
| Select country | click | tap |
| Pause / speed | Space, + / - | top bar buttons |

## Run from source
Open the project folder in Godot 4.7 and press F5.

## Credits
Made with [Godot Engine](https://godotengine.org).
