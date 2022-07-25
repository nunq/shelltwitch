#!/bin/bash
set -e #exit on error

APIKEYSFILE="./apikeys.sh"
CACHEDIR="$HOME/.cache/shelltwitch"

source "$APIKEYSFILE"

main() {
  printf "shelltwitch\n--------------------\nupdating...\r"
  validateoauth
  update
  buildUi
}

update() {
  USERID=$(curl -s -H "Client-ID: $CLIENTID" -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/users?login=$USER" | grep -oP '(?<="id":").*?(?=")')
  followedLive=$(curl -s -H "Client-ID: $CLIENTID" -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/streams/followed?user_id=$USERID")

  mapfile -t oStreamers <<< "$(echo $followedLive | grep -oP '(?<="user_name":").*?(?=")')"
  mapfile -t oStreamersLogin <<< "$(echo $followedLive | grep -oP '(?<="user_login":").*?(?=")')"
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
    printf "\e[0;32monline\e[0m  %s is playing %s with %s viewers\n%s\nlink: https://twitch.tv/%s\n\n" "${oStreamers[$i]}" "${oGames[$i]}" "${oViewers[$i]}" "${oTitles[$i]}" "${oStreamersLogin[$i]}"
  done
}

shouldNotify() {
  for (( i=0; i<${#oStreamersLogin[@]}; i++ )); do
    if ! grep -q "${oStreamersLogin[$i]}" "$CACHEDIR"/live; then #if streamer is online and notification not already sent, send it
      getIcon "${oStreamersLogin[$i]}"
      /usr/bin/notify-send -a "shelltwitch" -t 4500 -i "$CACHEDIR/${oStreamersLogin[$i]}.png" "${oStreamers[$i]} is live" "https://twitch.tv/${oStreamersLogin[$i]}"
      echo "${oStreamersLogin[$i]}" >> "$CACHEDIR"/live #save that a notification was sent to cachefile
    fi
  done
}

getIcon() {
  #get icon url from the twitch api and curl that image into $CACHEDIR
  if [ ! -f "$CACHEDIR"/"$1".png ]; then
    streamerIcon=$(curl -s -H "Client-ID: $CLIENTID" -H "Authorization: Bearer $OAUTHTOKEN" "https://api.twitch.tv/helix/users?login=$1" | grep -Po '"profile_image_url":".*?[^\\]",' | sed 's/^"profile_image_url":"//i;s/",$//i')
    curl -s "$streamerIcon" > "$CACHEDIR"/"$1".png
  fi
}

prepNotify() {
  update
  mapfile -t areLive < "$CACHEDIR"/live #read streams that were detected as live last time into areLive[]
  for stream in "${areLive[@]}"; do
    #if a streamer is no longer in oStreamers[] but still in the cachefile
    #aka if they went offline remove them from the cachefile on the next check (if run via cron)
    if ! echo "${oStreamersLogin[*]}" | grep -q "$stream" ; then
      cutThis="$(printf "%q" $cstream)"
      sed -i "/$cutThis/d" "$CACHEDIR"/live #remove them from the cachefile
    fi
  done
}

validateoauth() {
  maybeValid=$(curl -s -H "Client-ID: $CLIENTID" -H "Authorization: Bearer $OAUTHTOKEN" "https://id.twitch.tv/oauth2/validate")
  if [[ "$maybeValid" =~ "401" ]]; then
    echo "oauth token is invalid or has expired, please acquire a new one."
    exit 1
  fi
}

# acquire oauth token
getoauthtoken() {
  echo "please visit:"
  echo "https://id.twitch.tv/oauth2/authorize?response_type=token&client_id=$CLIENTID&redirect_uri=http://localhost:8090&scope=user%3Aread%3Afollows"
  echo -e "in your browser and grant authorization\n\n"

  read -p "please paste the url you were redirected to (localhost):" url
  echo $url | grep -oP '(?<=access_token=).*?(?=&)' > "$CACHEDIR"/token

  [[ -s "$CACHEDIR"/token ]] && echo -e "\nsaved oauth token to "$CACHEDIR"/token"
}

printhelp() {
  cat << 'EOF'
shelltwitch -- a simple cli and notifier for twitch

cli options:

cron       - use this for notifications using cron (see README.md).
oauth      - acquire new OAuth token.
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
OAUTHTOKEN="$(head -n 1 "$CACHEDIR"/token)" || OAUTHTOKEN=""

case $1 in
  cron)
    [[ -z "$OAUTHTOKEN" ]] && echo -e "error: no oauth token found\nplease run this script with 'oauth' to get a valid oauth token" && exit 1
    #environment vars for notify-send
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
    export DISPLAY=":0"
    prepNotify
    shouldNotify ;;
  oauth)
    getoauthtoken ;;
  h|help|--help|-help)
    printhelp ;;
  *)
    main ;;
esac
