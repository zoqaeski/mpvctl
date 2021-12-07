#!/usr/bin/env zsh
# This script requires:
# - that the directory $XDG_RUNTIME_DIR exist 
# + that the programs socat and jq be installed for writing to and reading from
#   the MPV JSON IPC pipe

# Parts of this script were adapted from https://github.com/Duncaen/mpvctl, but
# I'm intending to add a few more features to my version.

# The socket is put in the XDG_RUNTIME_DIR so it won't be accessible to anyone else
readonly socket="$XDG_RUNTIME_DIR/mpv.socket"
readonly progname=$0
readonly urlregex='^(http|https|ytdl|smb|bd|bluray|dvd|dvdnav|dvdread|tv|pvr|dvb|mf|cdda|lavf|av|file|fd|fdclose|edl)://'

# Run background jobs with normal priority
setopt no_bg_nice

# Options
local -a debug playlist mpvlog help
zparseopts -D d=debug -debug=debug \
    l=playlist -list=playlist \
    v=mpvlog -verbose=mpvlog \
    h=help -help=help 

# We need to check if an mpv instance with the socket open is running
local mpvpid=$(ps -x -o pid,command | grep $socket | grep -v grep | awk '{print $1}')

usage() {
    cat <<EOFUSAGE
$progname [options] <cmd> [ARGS...]
OPTIONS:
    -l, --list               Show playlist after performing COMMAND
    -d, --debug              Debug this script
    -v, --verbose            Log mpv output (to /tmp/mpv-DATE.txt)
    -h, --help               This help message

COMMANDS:
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

SAVING AND RELOADING THE PLAYLIST

To save the current playlist to a file, use:
    
    \$ mpvctl ls > FILENAME

To load a playlist from a file, use xargs:

    \$ xargs -d \\\\n -a FILENAME mpvctl add

EOFUSAGE
}

error() {
    printf "Error: %s\n" "$@"
    exit 1
}

local ipcmd
local ipc
local errmsg
# Send a command via the IPC interface
ipc-send() {
    # Cycle through command and arguments
    ipccmd="$1"
    args=""
    idx=0
    shift
    for a in "$@"; do
            [[ $(( idx=idx+1 )) -le "$#" ]] && args="$args, "
            case "${a}" in
                    true|false|[0-9]*) args="${args}${a}" ;;
                    *) args="${args}\"${a}\""
            esac
    done

    # Send the command to mpv, and store the output in $ipc
    ipc=$(printf '{ "command": [ "%s" %s ] }\n' "$ipccmd" "$args" | socat - $socket 2>&1) 
    # If socat can't connect, don't return an error: mpv might not be accepting connections yet
    [[ $? -eq 0 ]] && errmsg=$(echo $ipc | jq -r 'if .error != "success" then .error else empty end')

    [[ -n $errmsg ]] && error $errmsg 
    [[ -n $debug ]] && echo $ipc
}

local formatlist
list() {
    ipc-send 'get_property' 'playlist'
    if [[ -n $formatlist ]] ; then
        echo $ipc | jq -r '.data | ([keys[] as $k | .[$k] | .index=$k]) | map((.index | tostring) + (if .playing == true then " ▶ " else " " end) + .filename + "") | .[]'
    else
        echo $ipc | jq -r '.data | ([keys[] as $k | .[$k] | .index=$k]) | map(.filename) | .[]'
    fi
}

# Basic sanity check.
# If the argument is a URL that mpv recognises, pass it through, otherwise
# use the full path of the file if it is readable. It won't stop you from
# sending mpv files or URLs it doesn't know how to play, but it will ensure
# those files can be passed
local sanefilename
check() {
    if [[ $1 =~ $urlregex ]]; then
        sanefilename="$1"
    elif [[ -r $1:a ]] ; then
        sanefilename="$1:a"
    fi
}

# Append file names to the playlist
append() {
    opt="$1"
    [ -n "$opt" ] && shift

    # Basic sanity check of each file passed through
    local -a files
    for f in $argv ; do
        check $f
        files+=($sanefilename)
        unset sanefilename
    done

    for f in $files ; do
        ipc-send 'loadfile' "$f" "$opt"
    done
}

main() {
    cmd="$1"
    [ -n "$cmd" ] && shift
    
    if [[ -n $help[1] ]] || [[ $cmd = "usage" ]] ; then
        usage
        exit 0
    fi

    
    if [[ -z $mpvpid ]] && [[ ! $cmd = "add" ]] ; then
        error "MPV is not running!"
    fi

    # Initiate mpv if it is not already running
    if [[ -z $mpvpid ]] ; then
        echo "Starting new instance…"
        if [[ -n $mpvlog ]] ; then
            mpv --no-terminal --force-window --input-ipc-server=$socket --playlist-start=0 --idle=once --log-file=/tmp/mpv-$(date '+%Y%m%dT%H%M%S').txt & mpvpid=$!
        else 
            mpv --no-terminal --force-window --input-ipc-server=$socket --playlist-start=0 --idle=once & mpvpid=$!
        fi
        local connected=1
        while [[ $connected -ne 0 ]] ; do
            ipc-send 'get_property' 'mpv-version'
            echo $ipc | grep -v "Connection refused" - 
            connected=$?
            sleep 0.25
        done
    fi

    case $cmd in
        # Start playing
        # $1 skips to index on playlist
        play)
            if [[ "$1" ]] ; then
                ipc-send 'set_property' 'playlist-pos' "$1"
            fi
            ipc-send 'set_property' 'pause' 'false'
        ;;
        # Pause
        pause)
            ipc-send 'set_property' 'pause' 'true'
            ;;
        # Exit mpv
        stop) 
            ipc-send 'quit'
            ;;
        # Play next item in playlist
        next)
            ipc-send 'playlist-next'
            ;;
        # Play previous item in playlist
        prev|previous)
            ipc-send 'playlist-prev'
            ;;
        # Seek by $1 seconds
        seek)
            ipc-send 'seek' "$1" "$2"
            ;;
        # Switch playlist items
        move)
            ipc-send 'playlist-move' "$1" "$2"
            ;;
        # Remove item
        # With no argument, removes current item from playlist
        remove)
            if [[ -z "$1" ]] ; then
                ipc-send 'playlist-remove' 'current'
            else
                ipc-send 'playlist-remove' "$1"
            fi
            ;;
        # Remove all but current item
        clear)
            ipc-send 'playlist-clear'
            ;;
        # Show current playlist
        ls|list)
            unset playlist
            unset formatlist
            list
            ;;
        pls|playlist)
            unset playlist
            formatlist=1
            list
            ;;
        # Add item(s) to playlist
        add|append) 
            append "append-play" $argv 
            ;;
        # Replace currently playing items
        rep|replace)
            append "replace" $1
            shift
            for file in $argv ; do
                append "append" "$file"
            done
        ;;
        # Show properties
        prop)
            for p in $argv ; do
                ipc-send "get_property" "$p" 
                echo $ipc | jq '.data'
            done
            ;;
        *)
            usage
            exit 1
            ;;
    esac

    # Print playlist if started with -l or --list
    if [[ -n $playlist[1] ]] ; then
        formatlist=1
        list
    fi
}

if [[ -n $debug[1] ]] ; then
    setopt xtrace
fi

main "$@"
exit 0
