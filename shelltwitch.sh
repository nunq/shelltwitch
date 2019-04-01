#!/bin/bash
set -e
clientid="YOUR_CLIENTID_HERE"
streamers=("streamer1" "streamer2" "streamerN")

main() {
    printf "shelltwitch\n--------------------\n"
    printf "updating...\r"
    update
    buildui
}

update() {
    for streamer in "${streamers[@]}"; do
        jsonData=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login=$streamer")
        if [[ "$(echo "$jsonData" | grep -Po '"type":.*?[^\\]",')" == '"type":"live",' ]]; then
            oStreamers+=("$streamer")
        fi
    done
}
getMetadata() {
    gameid=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"game_id":.*?[^\\]",' | sed 's/^"game_id":"//i' | sed 's/",$//i')
    game=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/games?id=$gameid" | grep -Po '"name":.*?[^\\]",' | sed 's/^"name":"//i' | sed 's/",$//i')
    title=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"title":.*?[^\\]",' | sed 's/^"title":"//i' | sed 's/",$//i')
}

buildui() {
    if [[ -z "${oStreamers[*]}" ]]; then
        printf "no one is streaming :(\n"
        exit 0
    fi
    for (( i=0; i<${#oStreamers[@]}; i++)) ; do
        getMetadata "${oStreamers[$i]}"
        printf "\e[0;32monline\e[0m  %s is playing %s\n%s\n\n" "${oStreamers[$i]}" "$game" "$title"
    done
}

shouldNotify() {
    for ((i=0; i<${#oStreamers[@]}; i++)) ; do
        if ! [ $(grep -o "${oStreamers[$i]}" < "$cachedir"/live ) ]; then
            getIcon "${oStreamers[$i]}"
            notify-send  -a "shelltwitch" -t 3 -i "$cachedir/${oStreamers[$i]}.png" "${oStreamers[$i]} is live" "https://twitch.tv/${oStreamers[$i]}"
            echo "${oStreamers[$i]}" >> "$cachedir"/live
        fi
    done
}

getIcon() {
    if [ ! -f "$cachedir"/"$1".png ]; then
        streamerIcon=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/users?login=$1" | grep -Po '"profile_image_url":".*?[^\\]",' | sed 's/^"profile_image_url":"//i' | sed 's/",$//i')
        curl -s "$streamerIcon" > "$cachedir"/"$1".png
    fi
}

prepNotify() {
    update
    readarray cachedLivestreams < "$cachedir"/live
    for ((i=0; i<${#cachedLivestreams[@]}; i++)) ; do
	if ! [[ ${oStreamers[*]} =~ "$i" ]]; then
	    sed -i "s/^$i//i" "$cachedir"/live
	fi
    done
}

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