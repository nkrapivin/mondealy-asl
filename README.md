# mondealy-asl
Mondealy ASL script

This script can only be used with Mondealy 1.0.3 or newer.

[See this page for the usage guide!](https://www.speedrun.com/Mondealy/guides/gps2j)

Set the following launch parameters: `--livesplit`

The timer is automatically started as soon as the prologue room starts and the menu room ends.

The splits are automatically performed during chapter changes *and* when the credits are shown.

The timer is automatically reset when you exit to the main menu.

# Structure

If the `--livesplit` launch parameter is specified,

the game allocates a buffer with the following structure:

```c
typedef uint8_t char8_t; // UTF-8 char
struct MondealyHeapBuffer {
    char8_t bufferMagic[32]; // "-+=*(&!@#$%^Mondealy^%$#@!&)*=+-" look for this on the heap.
    char8_t gameVersion[32]; // as in the menu, for example "1.0.0l"
    char8_t buildConfig[32]; // usually "steam_full", but can also be "pc_gog" or "vk_play"
    double storyStage; // STAGES.story_stage
    double chapter; // STAGES.chapter
    double playTime; // STAGES.play_time aka IGT, in floating-point seconds (with frame fractions)
    double fpsSetting; // current Target FPS / FPS Limit setting, usually 60.0, this is NOT the "Real FPS".
    char8_t roomName[64]; // as returned by room_get_name(room), updated in Room Start
    // roomName is updated constantly, do not read the entire thing, only read until you hit a null byte.
    // extra data will go here...
};
```

The buffer is initialized when the game has finished initializing, and is updated at the end of all timer updates.

The actual memory size of the buffer is 2048 bytes to keep it aligned as nicely as possible.

To find the buffer itself, you will have to scan all memory pages of `Mondealy.exe` and look for the `bufferMagic`,

once you find it, save the address and I suggest that you sleep for a second or two to skip a few frames.

Then you can use the structure above to fetch data from the buffer, it's recommended that you do so at periodic intervals (use `fpsSetting` to approximate the needed refresh rate).

