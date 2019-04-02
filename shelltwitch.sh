#!/bin/bash
set -e #exit on error

## VARIABLES
clientid="YOUR_CLIENTID_HERE"
streamers=("streamer1" "streamer2" "streamerN")
cachedir="$HOME/.cache/shelltwitch"
#make notify-send work, get environment vars
export DBUS_SESSION_BUS_ADDRESS="$(tr '\0' '\n' < /proc/$(pidof -s pulseaudio)/environ | grep "DBUS_SESSION_BUS_ADDRESS" | cut -d "=" -f 2-)"
export DISPLAY="$(cat /proc/$(pidof -s pulseaudio)/environ | grep "^DISPLAY=" | sed 's/DISPLAY=//')"

main() {
    printf "shelltwitch\n--------------------\n"
    printf "updating...\r"
    update
    buildui
}

update() {
    for streamer in "${streamers[@]}"; do
        jsonData=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login=$streamer")
        #if the twitch api says the streamer is live, add them to oStreamers[]
        if [[ "$(echo "$jsonData" | grep -Po '"type":.*?[^\\]",')" == '"type":"live",' ]]; then
            oStreamers+=("$streamer")
        fi
    done
}
getMetadata() {
    #get some metadata like the stream title or what game is being played
    gameid=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"game_id":.*?[^\\]",' | sed 's/^"game_id":"//i' | sed 's/",$//i')
    game=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/games?id=$gameid" | grep -Po '"name":.*?[^\\]",' | sed 's/^"name":"//i' | sed 's/",$//i')
    title=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"title":.*?[^\\]",' | sed 's/^"title":"//i' | sed 's/",$//i')
}

buildui() {
    if [[ -z "${oStreamers[*]}" ]]; then #no streamer is online
        printf "no one is streaming :(\n"
        exit 0
    fi
    for (( i=0; i<${#oStreamers[@]}; i++)) ; do #for each online streamer print info
        getMetadata "${oStreamers[$i]}"
        printf "\e[0;32monline\e[0m  %s is playing %s\n%s\n\n" "${oStreamers[$i]}" "$game" "$title"
    done
}

shouldNotify() {
    for ((i=0; i<${#oStreamers[@]}; i++)) ; do
        if ! [ $(grep -o "${oStreamers[$i]}" < "$cachedir"/live ) ]; then #if streamer is online and notification not already sent, send it
            getIcon "${oStreamers[$i]}"
            /usr/bin/notify-send  -a "shelltwitch" -t 3 -i "$cachedir/${oStreamers[$i]}.png" "${oStreamers[$i]} is live" "https://twitch.tv/${oStreamers[$i]}"
            echo "${oStreamers[$i]}" >> "$cachedir"/live #save that a notification was sent to cachefile
        fi
    done
}

getIcon() {
    #get icon url from the twitch api and curl that image into cachedir
    if [ ! -f "$cachedir"/"$1".png ]; then
        streamerIcon=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/users?login=$1" | grep -Po '"profile_image_url":".*?[^\\]",' | sed 's/^"profile_image_url":"//i' | sed 's/",$//i')
        curl -s "$streamerIcon" > "$cachedir"/"$1".png
    fi
}

prepNotify() {
    update
    readarray cachedLivestreams < "$cachedir"/live #read streams that were detected as live last time into cachedLivestreams[]
    for ((i=0; i<${#cachedLivestreams[@]}; i++)) ; do
    #if a streamer is no longer in oStreamers[] but still in the cachefile
    #aka if they went offline remove them from the cachefile on the next check (if run via cron)
        if ! [ $(grep -o "${cachedLivestreams[$i]}" <<< "${oStreamers[*]}" ) ]; then
            cutThis="$(printf "%q" ${cachedLivestreams[$i]})"
            sed -i "/$cutThis/d" "$cachedir"/live #remove them from the cachefile
        fi
    done
}

#check if cachefile and cachedir exist
if [ ! -d "$cachedir" ]; then
    touch "$cachedir"
fi
if [ ! -f "$cachedir"/live ]; then
    touch "$cachedir"/live
fi

case $1 in
    cron)
        prepNotify
        shouldNotify ;;
    *)
        main ;;
esac
