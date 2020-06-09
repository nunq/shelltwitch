# shelltwitch
A bash script that checks what streamers are online, what they're playing, etc. using the [New Twitch API](https://dev.twitch.tv/docs/api). Notifications are also supported.

## Adding streamers
Followed streamers are fetched using the Twitch API, so just enter your username after `USER=`

When you follow or unfollow a streamer you need to run `./shelltwitch.sh upcache`, to register the changes into the cache file (located at: `~/.cache/shelltwitch/streamers`).

## Authenticating with the API
> As of April 30, 2020 Twitch requires OAuth tokens in all requests made to API endpoints

\> How do I get a token?

* Go to the [Twitch Developer Site](https://dev.twitch.tv)
* Create an account by linking your Twitch account
* Setup 2FA (cuz everything needs 2FA nowadays...)
* Go to your dashboard and [create a new application](https://dev.twitch.tv/console/apps/create) (`http://localhost` works as an OAuth redirect URL)
* Paste the Client ID into this script
* Click 'New Secret' and paste the Client Secret into this script
* Run this script with `oauth` as arg 1 to get an OAuth token
* Put the following into your crontab
```
@weekly <ABSOLUTE_PATH_TO_SHELLTWITCH.SH> checktoken
```
to periodically check when the token file was last modified and, if necessary, request a new token.
* Everything _should_ work.


## Notifications
Simply call this script with `cron`.

To check every three minutes, paste this into your crontab:
```
*/3 * * * * <ABSOLUTE_PATH_TO_SHELLTWITCH.SH> cron
```

## Rate Limiting
If a lot of the streamers you follow are live (>5), we send a lot of requests to the API. Because of that the API does some rate limiting so some data may not show up. To combat this, you can set `$ENABLEDELAY="1"`, this adds a one second delay if more than 5 streamers are live.

## Other
Dependencies: curl, GNU grep, GNU sed, notify-send (for notifications)

License: GPL v3
