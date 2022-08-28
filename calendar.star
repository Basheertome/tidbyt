load("render.star", "render")
load("animation.star", "animation")
load("http.star", "http")
load("time.star", "time")
load("encoding/json.star", "json")
load("humanize.star", "humanize")
load("math.star", "math")
load("re.star", "re")
load("schema.star", "schema")
load("cache.star", "cache")

DEFAULT_LOCATION = """
{
	"timezone": "America/Los_Angeles"
}
"""

def main(config):
	locationRaw = config.get("location", DEFAULT_LOCATION)
	location = json.decode(locationRaw)
	now = time.now()
	threshold = int(config.get("threshold", "24"))

	relevantSpecialEvents = []
	relevantEvents = []

	specialCalendar = None
	if (config.get("calendarSpecialURL") != None):
		specialCalendar = {
			"URL": config.get("calendarSpecialURL"),
			"Color": config.get("calendarSpecialColor")
		}
	if specialCalendar != None:
		get_calendar(specialCalendar)
		for event in process_events(specialCalendar):		
			if event.get("eventStart") != None and event.get("eventEnd") != None:
				if event["allDay"] and not event["Declined"] and now > event["eventStart"] and now < event["eventEnd"]:
					relevantSpecialEvents.append([specialCalendar["Color"], event])

	calendars = []
	for index in range(4):
		if (config.get("calendar" + str(index+1) + "URL") != None):
			calendars.append({
				"URL": config.get("calendar" + str(index+1) + "URL"),
				"Color": config.get("calendar" + str(index+1) + "Color")
			})
	if len(calendars) > 0:
		for index, calendar in enumerate(calendars):
			get_calendar(calendar)
			for event in process_events(calendars[index]):
				if event.get("eventStart") != None and event.get("eventEnd") != None:
					relativeStart = event["eventStart"]-now
					relativeEnd = event["eventStart"]-now
					if not (event["allDay"] or event["Declined"]):
						if relativeStart.hours > 0 and relativeStart.hours < threshold:
							relevantEvents.append([calendars[index]["Color"], relativeStart, event])
						elif now > event["eventStart"] and now < event["eventEnd"]:
							relevantEvents.append([calendars[index]["Color"], relativeStart, event])
		sortedEvents = []
		while relevantEvents:
			minimum = relevantEvents[0]
			for x in relevantEvents: 
				if x[1] < minimum[1]:
					minimum = x
			sortedEvents.append(minimum)
			relevantEvents.remove(minimum)
		filteredEvents = []
		for event in sortedEvents:
			if event[1] > time.parse_duration("0"):
				filteredEvents.append(event)
		if len(filteredEvents) > 0:
			relevantEvents = filteredEvents
		else:
			relevantEvents = sortedEvents

	children = render_events(relevantSpecialEvents, relevantEvents, location)
	if len(children) > 0:
		return render.Root(
			delay = 2000,
			child = render.Column(
			    children = children,
			),
		)
	else:
		return [] # Hide app if nothing to show

def render_events(specials, events, location):
	output = []
	if specials:
		summaries = []
		for summary in split_summaries(specials[0][1]["SUMMARY"]):
			summaries.append(
				render.Padding(
					pad = (0, 1, 0, 2),
					child = render.Row(
					    main_align = "center",
					    cross_align = "center",
					    expanded = True,
					    children = [render.Text(
					    	content = "∗ " + summary + " ∗",
					    	font = "6x13",
					    	color = specials[0][0],
					    ),]
					)
				)
			)
		output.append(
			render.Animation(
				children = summaries
			)
		)
	if events:
		if not specials:
			output.append(
				render.Padding(
					pad = (0, 1, 0, 2),
					child = render.Row(
					    main_align = "center",
					    cross_align = "center",
					    expanded = True,
					    children = [render.Text(
					    	content = humanize.time_format("HH:mm", time.now()),
					    	font = "6x13",
					    ),]
					)
				)
			)
		event = events[0]
		summaries = []
		for summary in joined_summaries(event[2]["SUMMARY"]):
			summaries.append(
				render.Padding(
					pad = (0, 0, 0, 2),
					child = render.Row(
					    main_align = "center",
					    cross_align = "center",
					    expanded = True,
					    children = [render.Text(
					    	content = summary,
					    	font = "tom-thumb",
					    ),]
					)
				)
			)
		output.append(
			render.Animation(
				children = summaries
			)
		)
		output.append(
		    render.Row(
		    	main_align = "center",
		    	cross_align = "center",
		    	expanded = True,
		    	children = [
		    		render.Circle(
		    			diameter = 3,
		    			color = event[0],
		    		),
		    		render.Padding(
		    			pad = (3, 0, 3, 0),
		    			child = render.Text(
			    			content = format_duration(event[1], location, event[2]),
			    			font = "tom-thumb",
			    			color = event[0],
		    			),
		    		),
		    		render.Circle(
		    			diameter = 3,
		    			color = event[0],
		    		),
		    	]
		    )
		)
	return output

def joined_summaries(summary):
	summaries = split_summaries(summary)
	splitSummaries = []
	for item in summaries:
		if len(item) > 16:
			splitSummaries.append(item[:16])
			splitSummaries.append(item[16:])
		else:
			splitSummaries.append(item)
	output = []
	for item in splitSummaries:
		if len(output) > 0 and len(output[-1]) + len(item) <= 16:
			output[-1] += " " + item
		else:
			output.append(item)
	return output

def split_summaries(summary):
	output = re.sub("[^\x00-\x7F]+", "", summary)
	output = output.rstrip(" ").lstrip(" ")
	output = output.split(" ")
	return output

def format_duration(duration, location, event):
	output = "in "
	if duration.hours > 24:
		amount = duration.hours/24
		output += humanize.ftoa(amount, 0) + " day"
		if amount >= 2:
			output += "s"
	elif duration.hours > 1:
		amount = duration.hours
		output += humanize.ftoa(amount, 1) + " hr"
		if amount > 1.15:
			output += "s"
	elif duration.minutes > 0:
		amount = duration.minutes
		zero = ""
		if str(math.floor(duration.minutes))[-1:] == "0":
			zero = "0"
		output += humanize.ftoa(amount, 0) + zero + " min"
		if amount >= 2:
			output += "s"
	else:
		output = "until "
		target = humanize.time_format("HH:mm", event["eventEnd"].in_location(location["timezone"]))
		output += target
	return output

def process_events(calendar):
	for event in calendar["Events"]:
		eventDeclined = 0
		for detail in event.items():
			multi = detail[0].split(";")
			if len(multi) > 1 and multi[0] == "ATTENDEE":
				for p, pieces in enumerate(multi[1:]):
					bit = pieces.split("=")
					if bit[0] == "CN" and bit[1] == "Basheer Tome":
						eventDeclined += 1
					elif bit[0] == "PARTSTAT" and bit[1] == "DECLINED":
						eventDeclined += 1
		if eventDeclined > 1:
			event["Declined"] = True
		else:
			event["Declined"] = False
		event["Timezone"] = "UTC"
		if event.get("DTSTART;VALUE=DATE") != None:
			event["allDay"] = True
			event["eventStart"] = time.parse_time(event.get("DTSTART;VALUE=DATE"), "20060102", event["Timezone"])
			event["eventEnd"] = time.parse_time(event.get("DTEND;VALUE=DATE"), "20060102", event["Timezone"])
		else:
			event["allDay"] = False
			for detail in event.items():
				if detail[0][:12] == "DTSTART;TZID":
					event["Timezone"] = detail[0].split("TZID=")[1]
					if not time.is_valid_timezone(event["Timezone"]):
						event["Timezone"] = "UTC"
					event["eventStart"] = time.parse_time(detail[1][:15], "20060102T150405", event["Timezone"])
				if detail[0][:10] == "DTEND;TZID":
					event["eventEnd"] = time.parse_time(detail[1][:15], "20060102T150405", event["Timezone"])
			if event.get("eventStart") == None and event.get("DTSTART") != None:
				event["eventStart"] = time.parse_time(str(event.get("DTSTART"))[:15], "20060102T150405", event["Timezone"])
			if event.get("eventEnd") == None and event.get("DTEND") != None:
				event["eventEnd"] = time.parse_time(str(event.get("DTEND"))[:15], "20060102T150405", event["Timezone"])
	return calendar["Events"]

def get_calendar(calendarIn):
	cached = cache.get(calendarIn["URL"])
	if cached != None:
		response = cached
	else:
		response = http.get(calendarIn["URL"]).body()
		cache.set(calendarIn["URL"], response, ttl_seconds=60)
	calendar = response.split("BEGIN:VEVENT\r\n")
	calendarSettings = calendar[0].replace("\r\n ", "").split("\r\n")
	settings = {}
	for item, line in enumerate(calendarSettings):
		if item < len(calendarSettings)-1:
			data = line.split(":")
			if len(data) > 0:
				settings[data[0]] = "".join(data[1:])
	calendarEvents = "".join(calendar[1:]).split("END:VEVENT\r\n")[:-1]
	events = []
	for index, event in enumerate(calendarEvents):
		newEvent = {}
		event = event.replace("\r\n ", "").split("\r\n")
		for item, line in enumerate(event):
			if item < len(event)-1:
				data = line.split(":")
				if len(data) > 0:
					newEvent[data[0]] = "".join(data[1:])
		events.append(newEvent)
	calendarIn["Settings"] = settings
	calendarIn["Timezone"] = calendarIn["Settings"].get("X-WR-TIMEZONE", calendarIn["Settings"].get("TZID"))
	calendarIn["Events"] = events

def get_schema():
	colorOptions = [
		schema.Option(display = "White", value = "#FFFFFF"),
		schema.Option(display = "Red", value = "#FF0000"),
		schema.Option(display = "Green", value = "#00FF00"),
		schema.Option(display = "Blue", value = "#0000FF"),
		schema.Option(display = "Yellow", value = "#FFFF00"),
		schema.Option(display = "Cyan", value = "#00FFFF"),
		schema.Option(display = "Magenta", value = "#FF00FF"),
	]
	return schema.Schema(
		version = "1",
		fields = [
			schema.Location(
				id = "location",
				name = "Device Location",
				desc = "Location for which to reference time",
				icon = "locationDot",
			),
			schema.Text(
			    id = "threshold",
			    name = "Upcoming Event Threshold",
			    desc = "The number of hours for the cutoff",
			    icon = "clock",
			    default = "24",
			),
			schema.Text(
				id = "calendarSpecialURL",
				name = "Special Calendar URL",
				desc = "Link to iCAL/ICS formatted of special calendar",
				icon = "link",
			),
			schema.Dropdown(
				id = "calendarSpecialColor",
				name = "Special Calendar Color",
				desc = "Set the icon color of this calendar",
				icon = "palette",
				default = colorOptions[0].value,
				options = colorOptions,
			),
			schema.Text(
				id = "calendar1URL",
				name = "Calendar 1 URL",
				desc = "Link to iCAL/ICS formatted calendar",
				icon = "link",
			),
			schema.Dropdown(
				id = "calendar1Color",
				name = "Calendar 1 Color",
				desc = "Set the icon color of this calendar",
				icon = "palette",
				default = colorOptions[0].value,
				options = colorOptions,
			),
			schema.Text(
				id = "calendar2URL",
				name = "Calendar 2 URL",
				desc = "Link to iCAL/ICS formatted calendar",
				icon = "link",
			),
			schema.Dropdown(
				id = "calendar2Color",
				name = "Calendar 2 Color",
				desc = "Set the icon color of this calendar",
				icon = "palette",
				default = colorOptions[0].value,
				options = colorOptions,
			),
			schema.Text(
				id = "calendar3URL",
				name = "Calendar 3 URL",
				desc = "Link to iCAL/ICS formatted calendar",
				icon = "link",
			),
			schema.Dropdown(
				id = "calendar3Color",
				name = "Calendar 3 Color",
				desc = "Set the icon color of this calendar",
				icon = "palette",
				default = colorOptions[0].value,
				options = colorOptions,
			),
			schema.Text(
				id = "calendar4URL",
				name = "Calendar 4 URL",
				desc = "Link to iCAL/ICS formatted calendar",
				icon = "link",
			),
			schema.Dropdown(
				id = "calendar4Color",
				name = "Calendar 4 Color",
				desc = "Set the icon color of this calendar",
				icon = "palette",
				default = colorOptions[0].value,
				options = colorOptions,
			),
		],
	)
