#!/bin/bash
clientid="YOUR_CLIENTID_HERE"
streamers=("streamer1" "streamer2" "streamerN")

main() {
    printf "shelltwitch\n--------------------\n"
    update
    buildui
}

update() {
    for streamer in "${streamers[@]}"; do
        jsonData=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login="$streamer"")
        if [ "$(echo $jsonData | grep -Po '"type":.*?[^\\]",')" == '"type":"live",' ]; then
            oStreamers+=($streamer)
        fi
    done
}
getMetadata() {
    gameid=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login="$1"" | grep -Po '"game_id":.*?[^\\]",' | sed 's/^"game_id":"//i' | sed 's/",$//i')
    game=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/games?id="$gameid"" | grep -Po '"name":.*?[^\\]",' | sed 's/^"name":"//i' | sed 's/",$//i')
    title=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/streams?user_login="$1"" | grep -Po '"title":.*?[^\\]",' | sed 's/^"title":"//i' | sed 's/",$//i')
}

buildui() {
    for (( i=0; i<${#oStreamers[@]}; i++)) ; do
        getMetadata ${oStreamers[$i]}
        printf "\e[0;32monline\e[0m\t${oStreamers[$i]} is playing $game\n$title\n\n"
    done
}

shouldNotify() {
    for (( i=0; i<${#oStreamers[@]}; i++)) ; do
        if ! [ $(cat /tmp/shelltwitch/live | grep -o "${oStreamers[$i]}") ]; then
            sendNotification "${oStreamers[$i]}"
            echo "${oStreamers[$i]}" > /tmp/shelltwitch/live
        fi
    done
}

sendNotification() {
    if [ ! -f /tmp/shelltwitch/"$1".png ]; then
        streamerIcon=$(curl -s -H "Client-ID: $clientid" -X GET "https://api.twitch.tv/helix/users?login="$1"" | grep -Po '"profile_image_url":".*?[^\\]",' | sed 's/^"profile_image_url":"//i' | sed 's/",$//i')
        mkdir /tmp/shelltwitch
        curl -s "$streamerIcon" > /tmp/shelltwitch/"$1".png
    fi
    notify-send  -a "shelltwitch" -t 3 -i "/tmp/shelltwitch/"$1".png" "$1 is live" "https://twitch.tv/$1"
}

case $1 in
    cron)
        update
        shouldNotify ;;
    *)
        main ;;
esac
