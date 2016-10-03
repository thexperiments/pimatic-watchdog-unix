Pimatic Watchdog Unix plugin
=======================

This plugin adds a simple watchdog to pimatic for unix based systems (as it is using bash)

It can do the following:
- Check if pimatic process is still running
- Check if pimatic is still reachable via webinterface
- Restart pimatic if one of the above fails
- Reboot the machine if restart of pimatic fails

Example config.json entries:
```json
    {
      "plugin": "watchdog-unix",
      "processEnabled": true,
      "httpURL": "http://127.0.0.1:80/",
      "httpEnabled": true,
      "active": true
    },
```