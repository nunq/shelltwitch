# shelltwitch
A bash script that checks what streamers are online, what they're playing, etc. using the [New Twitch API](https://dev.twitch.tv/docs/api). Notifications are also supported.

## Setup

Followed streamers are fetched using the Twitch API, so just enter your username after `USER=` in `apikeys.sh`

> As of April 30, 2020 Twitch requires OAuth tokens in all requests made to API endpoints

\> How do I get a token?

* Setup 2FA for your Twitch account (is required to register an application)
* Go to the [Twitch Developer Site](https://dev.twitch.tv)
* Create an account by linking your Twitch account
* Go to your dashboard and [create a new application](https://dev.twitch.tv/console/apps/create)
* Use `http://localhost:8090` as the OAuth redirect URL
* Paste the Client ID into `apikeys.sh`
* Run `./<script> oauth` to authorize the application you just created to read your Twitch account data

## Notifications
Simply call this script with `cron`.

To check every three minutes, paste this into your crontab, systemd-timer, etc:
```
*/3 * * * * <FULL_PATH_TO_SHELLTWITCH.SH> cron
```

## Other
Dependencies: bash, curl, GNU grep, GNU sed, notify-send (for notifications)

License: GPL v3
