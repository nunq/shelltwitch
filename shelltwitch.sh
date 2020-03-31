#!/bin/bash
set -e #exit on error

## VARIABLES
CLIENTID="" #YOUR_CLIENTID
CLIENTSECRET="" #YOUR_CLIENTSECRET
USER="" #YOUR_USERNAME
ENABLEDELAY="" #add 1s delay if online streamers >5 ? 1=yes, 0=no
CACHEDIR="$HOME/.cache/shelltwitch"

main() {
    printf "shelltwitch\n--------------------\nupdating...\r"
    update
    buildUi
}

update() {
    mapfile -t streamers < "$CACHEDIR"/streamers
    for streamer in "${streamers[@]}"; do
        jsonData=$(curl -s -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/streams?user_login=$streamer")
        #if the twitch api says the streamer is live, add them to oStreamers[]
        if [ "$(echo "$jsonData" | grep -Po '"type":.*?[^\\]",')" == '"type":"live",' ]; then
            oStreamers+=("$streamer")
        fi
    done
}

getMetadata() {
    #get some metadata like the stream title or what game is being played
    if [ "$ENABLEDELAY" == "1" ] && [ "${#oStreamers[@]}" -gt "5" ]; then sleep 1; fi
    gameid=$(curl -s -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"game_id":.*?[^\\]",' | sed 's/^"game_id":"//i;s/",$//i')
    if ! [ $(grep -o "$gameid" "$CACHEDIR"/gameids ) ]; then
        game=$(printf "%b" "$(curl -s -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/games?id=$gameid" | grep -Po '"name":.*?[^\\]",' | sed 's/^"name":"//i;s/",$//i')")
        if [ -n "$game" ]; then echo "$gameid: \"$game\"" >> "$CACHEDIR"/gameids; fi
    else
        game=$(grep -oP "(?<=$gameid: \").*?(?=\"$)" "$CACHEDIR"/gameids)
    fi
    if [ -z "$game" ]; then title="couldn't get game (rate limiting)"; fi
    title=$(printf "%b" "$(curl -s -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/streams?user_login=$1" | grep -Po '"title":.*?[^\\]",' | sed 's/^"title":"//i;s/",$//i')")
    if [ -z "$title" ]; then title="couldn't get stream title (rate limiting)"; fi
}

updateCachedStreamers() {
    #clear cached game ids
    echo -n "" > "$CACHEDIR"/gameids
    #clear cached streamers
    echo -n "" > "$CACHEDIR"/streamers
    USERID=$(curl -s -H "Authorization: Bearer $OAUTHTOKEN" https://api.twitch.tv/helix/users?login="$USER"| grep -Po '"id":.*?[^\\]",' | sed 's/^"id":"//i;s/",$//i')
    mapfile -t streamers <<< $(curl -s -H "Authorization: Bearer $OAUTHTOKEN" https://api.twitch.tv/helix/users/follows?from_id="$USERID" | grep -Po '"to_name":.*?[^\\]",' | sed 's/^"to_name":"//;s/",$//i')
    #cache followed streamers
    for streamer in "${streamers[@]}"; do
        echo "$streamer" >> "$CACHEDIR"/streamers
    done
}

buildUi() {
    if [ -z "${oStreamers[*]}" ]; then #no streamer is online
        printf "no one is streaming :(\n"
        exit 0
    fi
    for ostreamer in "${oStreamers[@]}"; do #for each online streamer print info
        getMetadata "$ostreamer"
        printf "\e[0;32monline\e[0m  %s is playing %s\n%s\nlink: https://twitch.tv/%s\n\n" "$ostreamer" "$game" "$title" "$ostreamer"
    done
}

shouldNotify() {
    for ostreamer in "${oStreamers[@]}"; do
        if ! [ $(grep -o "$ostreamer" "$CACHEDIR"/live ) ]; then #if streamer is online and notification not already sent, send it
            getIcon "$ostreamer"
            /usr/bin/notify-send -a "shelltwitch" -t 4500 -i "$CACHEDIR/$ostreamer.png" "$ostreamer is live" "https://twitch.tv/$ostreamer"
            echo "$ostreamer" >> "$CACHEDIR"/live #save that a notification was sent to cachefile
        fi
    done
}

getIcon() {
    #get icon url from the twitch api and curl that image into $CACHEDIR
    if [ ! -f "$CACHEDIR"/"$1".png ]; then
        streamerIcon=$(curl -s -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/users?login=$1" | grep -Po '"profile_image_url":".*?[^\\]",' | sed 's/^"profile_image_url":"//i;s/",$//i')
        curl -s "$streamerIcon" > "$CACHEDIR"/"$1".png
    fi
}

prepNotify() {
    update
    mapfile -t cachedLivestreams < "$CACHEDIR"/live #read streams that were detected as live last time into cachedLivestreams[]
    for cstream in "${cachedLivestreams[@]}"; do
    #if a streamer is no longer in oStreamers[] but still in the cachefile
    #aka if they went offline remove them from the cachefile on the next check (if run via cron)
        if ! [ $(grep -o "$cstream" <<< "${oStreamers[*]}" ) ]; then
            cutThis="$(printf "%q" $cstream)"
            sed -i "/$cutThis/d" "$CACHEDIR"/live #remove them from the cachefile
        fi
    done
}

# acquire oauth token
getoauthtoken() {
  curl -s -X POST "https://id.twitch.tv/oauth2/token?client_id=$CLIENTID&client_secret=$CLIENTSECRET&grant_type=client_credentials" | grep -oP '(?<="access_token":").*?(?=",")' > "$CACHEDIR"/oauth-token
  [[ -s "$CACHEDIR"/token ]] && echo "saved oauth token to "$CACHEDIR"/token"
}

checktoken() {
  if [ $((($(date +%s) - $(stat -c %Y "$CACHEDIR"/token)) / 86400)) -ge "30" ]; then
    echo "token file wasn't modified in the last 30 days, reacquiring token."
    getoauthtoken
  fi
}

printhelp() {
  cat << 'EOF'
shelltwitch -- a simple cli and notifier for twitch

cli options:

upcache    - update followed streamers and repopulate cachefiles
cron       - use this for notifications using cron (see README.md).
oauth      - explicitly acquire new OAuth token. Only needed during setup.
checktoken - checks the oauth token every month or so (see README.md).
help       - show this message.

everything else: run the script normally.
EOF
  exit 0
}

#check cache and vars
if [ -z $CLIENTID ]; then echo "error: no client secret set"&&exit 1; fi
if [ -z $CLIENTSECRET ]; then echo "error: no client secret set"&&exit 1; fi
if [ -z $USER ]; then echo "error: no username set"&&exit 1; fi
if [ -z $ENABLEDELAY ]; then echo "error: \$ENABLEDELAY not set"&&exit 1; fi
if [ -z $CACHEDIR ]; then echo "error: no cache directory set"&&exit 1; fi
if [ ! -d "$CACHEDIR" ]; then mkdir -p "$CACHEDIR"; fi
if [ ! -f "$CACHEDIR"/live ]; then touch "$CACHEDIR"/live; fi
if [ ! -f "$CACHEDIR"/streamers ]; then touch "$CACHEDIR"/streamers; fi
OAUTHTOKEN="$(head -n 1 "$CACHEDIR"/token)" || OAUTHTOKEN=""
[[ -z "$OAUTHTOKEN" ]] && echo -e "error: no oauth token found\nplease run this script with 'oauth' to get a valid oauth token" && exit 1 

case $1 in
    cron)
        #environment vars for notify-send
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
        export DISPLAY=":0"
        prepNotify
        shouldNotify ;;
    upcache)
        updateCachedStreamers ;;
    oauth)
        getoauthtoken ;;
    checktoken)
        checktoken ;;
    h|help|--help|-help)
        printhelp ;;
    *)
        main ;;
esac
