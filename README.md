# mpvctl

Shell script to control a long-running mpv from the command line.


## OPTIONS

```
    -l, --list               Show playlist after performing COMMAND
    -d, --debug              Debug this script
    -v, --verbose            Log mpv output (to /tmp/mpv-DATE.txt)
```

## COMMANDS

```
    play [index]             Start playing
    pause                    Pause current file
    stop                     Stop and quit
    next                     Play next file
    prev(ious)               Play previous file
    seek <seconds>           Seek <seconds> in file
    move <index1> <index2>   Move <index1> to <index2> in playlist
    remove [index]           Remove current file or item <index> from playlist
    clear                    Clear all but currently playing files
    ls, list                 List the playlist
    pls, playlist            Show the playlist, showing indices and currently-playing item
    add <filenames...>       Add files to playlist
    replace <filenames...>   Replace playlist with files
    prop [...]               Get properties
```

## SAVING AND RELOADING THE PLAYLIST

To save the current playlist to a file, use:
```
mpvctl ls > FILENAME
```

To load a playlist from a file, use xargs:
```
xargs -d \\\\n -a FILENAME mpvctl add
```

