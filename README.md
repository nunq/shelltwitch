# shelltwitch
A bash script that checks what streamers are online, what they're playing, etc. using the [New Twitch API](https://dev.twitch.tv/docs/api). Notifications are also supported.

## Client ID
\> How do I get a Client-ID?

* Go to the [Twitch Developer Site](https://dev.twitch.tv)
* Create an account by linking your Twitch account
* Go to your dashboard and create a new application
* Paste the Client-ID into this script

## Notifications
Simply call this script with "cron".

To check every three minutes, paste this into your crontab:
```
*/3 * * * * " <PATH_TO_SHELLTWITCH.SH> cron"
```

## Other
Sometimes not all the info shows up, I don't really know why this is happening, but I assume that it's rate-limiting done by the Twitch API.

License: GPL v3