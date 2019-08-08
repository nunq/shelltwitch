# shelltwitch
A bash script that checks what streamers are online, what they're playing, etc. using the [New Twitch API](https://dev.twitch.tv/docs/api). Notifications are also supported.

## Adding streamers
Followed streamers are fetched using the Twitch API, so just enter your username after `USER=`

When you follow or unfollow a streamer you need to run `./shelltwitch.sh upcache`, to register the changes into the cache file (located at: `~/.cache/shelltwitch/streamers`).

## Client ID
\> How do I get a Client-ID?

* Go to the [Twitch Developer Site](https://dev.twitch.tv)
* Create an account by linking your Twitch account
* Go to your dashboard and create a new application
* Paste the Client-ID into this script

## Notifications
Simply call this script with "`cron`".

To check every three minutes, paste this into your crontab:
```
*/3 * * * * <ABSOLUTE_PATH_TO_SHELLTWITCH.SH> cron
```

## Rate Limiting
If a lot of the Streamers you follow are live (>5), we send a lot of requests to the API. Because of that the API does some rate limiting so some data may not show up. To combat this, you can set `$ENABLEDELAY="1"`, this adds a one second delay if more than 5 Streamers are live.

## Other
Dependencies: curl, GNU grep, GNU sed, notify-send (for notifications)

License: GPL v3
