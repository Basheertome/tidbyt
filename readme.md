Tidbyt
=========

The code for my custom apps for [Tidbyt](https://tidbyt.com).

The server file runs using a separate configuation file (stored one level above git), config.json, which needs to be formatted like so:

```
{
	"threshold": 24,
	"timezone": "America/Los_Angeles",
	"calendars": [
		{
			"name": "string",
			"id": "look up in Google Calendar",
			"color": "#FF0000"
		},
		{
			"name": "string",
			"id": "look up in Google Calendar",
			"color": "#FFFF00"
		},
		{
			"name": "string",
			"id": "look up in Google Calendar",
			"color": "#00FF00"
		}
	]
}
```
