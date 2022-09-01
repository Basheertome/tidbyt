Tidbyt
=========

The code for my custom apps for [Tidbyt](https://tidbyt.com).

The server file runs using a separate configuation file (stored one level above git), config.json, which needs to be formatted like so:

```
{
	"username": "basheer",
	"threshold": 24,
	"timezone": "America/Los_Angeles",
	"special": {
		"url": "https://example.com/calendar0.ics",
		"color": "#0000FF"
	},
	"calendars": [
		{
			"url": "https://example.com/calendar1.ics",
			"color": "#FF0000"
		},
		{
			"url": "https://example.com/calendar2.ics",
			"color": "#FFFF00"
		},
		{
			"url": "https://example.com/calendar3.ics",
			"color": "#00FF00"
		}
	]
}
```
