#!/bin/bash
set -e #exit on error

APIKEYSFILE="./apikeys.sh"
CACHEDIR="$HOME/.cache/shelltwitch"

source "$APIKEYSFILE"

main() {
  printf "shelltwitch\n--------------------\nupdating...\r"
  update
  buildUi
}

update() {
  USERID=$(curl -s -H "Client-ID: $CLIENTID" -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/users?login=$USER" | grep -oP '(?<="id":").*?(?=")')
  followedLive=$(curl -s -H "Client-ID: $CLIENTID" -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/streams/followed?user_id=$USERID")

  mapfile -t oStreamers <<< "$(echo $followedLive | grep -oP '(?<="user_name":").*?(?=")')"
  mapfile -t oGames <<< "$(echo $followedLive | grep -oP '(?<="game_name":").*?(?=")')"
  mapfile -t oTitles <<< "$(echo $followedLive | grep -oP '(?<="title":").*?(?=")')"
  mapfile -t oViewers <<< "$(echo $followedLive | grep -oP '(?<="viewer_count":).*?(?=,)')"
}

buildUi() {
  if [ -z "${oStreamers[*]}" ]; then #no streamer is online
    printf "no one is streaming :(\n"
    exit 0
  fi
  for (( i=0; i<${#oStreamers[@]}; i++ )); do
    printf "\e[0;32monline\e[0m  %s is playing %s with %s viewers\n%s\nlink: https://twitch.tv/%s\n\n" "${oStreamers[$i]}" "${oGames[$i]}" "${oViewers[$i]}" "${oTitles[$i]}" "${oStreamers[$i]}"
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
# TODO implement new oauth user flow
  curl -s -X POST "https://id.twitch.tv/oauth2/token?client_id=$CLIENTID&client_secret=$CLIENTSECRET&grant_type=client_credentials" | grep -oP '(?<="access_token":").*?(?=",")' > "$CACHEDIR"/token
  [[ -s "$CACHEDIR"/token ]] && echo "saved oauth token to "$CACHEDIR"/token"
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
if [ -z $CLIENTID ]; then echo "error: no client id set"&&exit 1; fi
if [ -z $USER ]; then echo "error: no username set"&&exit 1; fi
if [ -z $CACHEDIR ]; then echo "error: no cache directory set"&&exit 1; fi
if [ ! -d "$CACHEDIR" ]; then mkdir -p "$CACHEDIR"; fi
if [ ! -f "$CACHEDIR"/live ]; then touch "$CACHEDIR"/live; fi
if [ ! -f "$CACHEDIR"/streamers ]; then touch "$CACHEDIR"/streamers; fi
OAUTHTOKEN="$(head -n 1 "$CACHEDIR"/token)" || OAUTHTOKEN=""

case $1 in
  cron)
    [[ -z "$OAUTHTOKEN" ]] && echo -e "error: no oauth token found\nplease run this script with 'oauth' to get a valid oauth token" && exit 1
    #environment vars for notify-send
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
    export DISPLAY=":0"
    prepNotify
    shouldNotify ;;
  upcache)
    [[ -z "$OAUTHTOKEN" ]] && echo -e "error: no oauth token found\nplease run this script with 'oauth' to get a valid oauth token" && exit 1
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
