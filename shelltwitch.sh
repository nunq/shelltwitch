#!/bin/bash
set -e #exit on error

## VARIABLES
CLIENTID="" #YOUR_CLIENTID
USER="" #YOUR_USERNAME
CACHEDIR="$HOME/.cache/shelltwitch"

main() {
    printf "shelltwitch\n--------------------\n"
    printf "updating...\r"
    update
    buildui
}

update() {
    mapfile -t streamers < "$CACHEDIR"/streamers
    for streamer in "${streamers[@]}"; do
        jsonData=$(curl -s -H "Client-ID: $CLIENTID" -X GET "https://api.twitch.tv/helix/streams?user_login=$streamer")
        #if the twitch api says the streamer is live, add them to oStreamers[]
        if [[ "$(echo "$jsonData" | grep -Po '"type":.*?[^\\]",')" == '"type":"live",' ]]; then
            oStreamers+=("$streamer")
        fi
    done
}
getMetadata() {
    #get some metadata like the stream title or what game is being played
    gameid=$(curl -s -H "Client-ID: $CLIENTID" -X GET "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"game_id":.*?[^\\]",' | sed 's/^"game_id":"//i' | sed 's/",$//i')
    game=$(curl -s -H "Client-ID: $CLIENTID" -X GET "https://api.twitch.tv/helix/games?id=$gameid" | grep -Po '"name":.*?[^\\]",' | sed 's/^"name":"//i' | sed 's/",$//i')
    title=$(curl -s -H "Client-ID: $CLIENTID" -X GET "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"title":.*?[^\\]",' | sed 's/^"title":"//i' | sed 's/",$//i')
}

updateCachedStreamers() {
    #clear cached streamers
    echo -n "" > "$CACHEDIR"/streamers
    USERID=$(curl -s -H "Client-ID: $CLIENTID" -X GET https://api.twitch.tv/helix/users?login="$USER"| grep -Po '"id":.*?[^\\]",' | sed 's/^"id":"//i' | sed 's/",$//i')
    mapfile -t streamers <<< $(curl -s -H "Client-ID: $CLIENTID" -X GET https://api.twitch.tv/helix/users/follows?from_id="$USERID" | grep -Po '"to_name":.*?[^\\]",' | sed 's/^"to_name":"//' | sed 's/",$//i')
    #cache followed streamers
    for streamer in "${streamers[@]}"; do
        echo "$streamer" >> "$CACHEDIR"/streamers
    done
}

buildui() {
    if [[ -z "${oStreamers[*]}" ]]; then #no streamer is online
        printf "no one is streaming :(\n"
        exit 0
    fi
    for ostreamer in "${oStreamers[@]}"; do #for each online streamer print info
        getMetadata "$ostreamer"
        printf "\e[0;32monline\e[0m  %s is playing %s\n%s\n\n" "$ostreamer" "$game" "$title"
    done
}

shouldNotify() {
    for ostreamer in "${oStreamers[@]}"; do
        if ! [ $(grep -o "$ostreamer" < "$CACHEDIR"/live ) ]; then #if streamer is online and notification not already sent, send it
            getIcon "$ostreamer"
            /usr/bin/notify-send -a "shelltwitch" -t 4500 -i "$CACHEDIR/$ostreamer.png" "$ostreamer is live" "https://twitch.tv/$ostreamer"
            echo "$ostreamer" >> "$CACHEDIR"/live #save that a notification was sent to cachefile
        fi
    done
}

getIcon() {
    #get icon url from the twitch api and curl that image into $CACHEDIR
    if [ ! -f "$CACHEDIR"/"$1".png ]; then
        streamerIcon=$(curl -s -H "Client-ID: $CLIENTID" -X GET "https://api.twitch.tv/helix/users?login=$1" | grep -Po '"profile_image_url":".*?[^\\]",' | sed 's/^"profile_image_url":"//i' | sed 's/",$//i')
        curl -s "$streamerIcon" > "$CACHEDIR"/"$1".png
    fi
}

prepNotify() {
    update
    readarray cachedLivestreams < "$CACHEDIR"/live #read streams that were detected as live last time into cachedLivestreams[]
    for cstream in "${cachedLivestreams[@]}"; do
    #if a streamer is no longer in oStreamers[] but still in the cachefile
    #aka if they went offline remove them from the cachefile on the next check (if run via cron)
        if ! [ $(grep -o "$cstream" <<< "${oStreamers[*]}" ) ]; then
            cutThis="$(printf "%q" $cstream)"
            sed -i "/$cutThis/d" "$CACHEDIR"/live #remove them from the cachefile
        fi
    done
}

#check cache and vars
if [[ -z $CLIENTID ]]; then echo "error: no client-id set"&&exit 1; fi
if [[ -z $USER ]]; then echo "error: no username set"&&exit 1; fi
if [[ -z $CACHEDIR ]]; then echo "error: no cache directory set"&&exit 1; fi
if [ ! -d "$CACHEDIR" ]; then mkdir -p "$CACHEDIR"; fi
if [ ! -f "$CACHEDIR"/live ]; then touch "$CACHEDIR"/live; fi
if [ ! -f "$CACHEDIR"/streamers ]; then touch "$CACHEDIR"/streamers; fi

case $1 in
    cron)
        #make notify-send work, get environment vars
        export DBUS_SESSION_BUS_ADDRESS="$(tr '\0' '\n' < /proc/$(pidof -s pulseaudio)/environ | grep "DBUS_SESSION_BUS_ADDRESS" | cut -d "=" -f 2-)"
        export DISPLAY="$(cat /proc/$(pidof -s pulseaudio)/environ | grep "^DISPLAY=" | sed 's/DISPLAY=//')"
        prepNotify
        shouldNotify ;;
    upcache)
        updateCachedStreamers ;;
    *)
        main ;;
esac
