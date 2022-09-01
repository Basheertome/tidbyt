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

def main(config):
	children = None

	url = config.get("serverURL") or "http://127.0.0.1:5000"
	if url:
		data = get_data(url)
		children = render_events(data.get("special"), data.get("event"), data.get("timezone"))
	
	if children:
		return render.Root(
			delay = 3000,
			child = render.Column(
			    children = children,
			),
		)
	else:
		return [] # Hide app if nothing to show

def render_events(special, event, timezone):
	output = []
	if special:
		pages = []
		for word in split_summary(special.get("summary")):
			pages.append(
				render.Padding(
					pad = (0, 1, 0, 2),
					child = render.Row(
					    main_align = "center",
					    cross_align = "center",
					    expanded = True,
					    children = [render.Text(
					    	content = "∗ " + word + " ∗",
					    	font = "6x13",
					    	color = special.get("color"),
					    ),]
					)
				)
			)
		output.append(
			render.Animation(
				children = pages
			)
		)
	if event:
		if not special:
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
		pages = []
		for word in joined_summary(event.get("summary")):
			pages.append(
				render.Padding(
					pad = (0, 0, 0, 2),
					child = render.Row(
					    main_align = "center",
					    cross_align = "center",
					    expanded = True,
					    children = [render.Text(
					    	content = word,
					    	font = "tom-thumb",
					    ),]
					)
				)
			)
		output.append(
			render.Animation(
				children = pages
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
		    			color = event.get("color"),
		    		),
		    		render.Padding(
		    			pad = (3, 0, 3, 0),
		    			child = render.Text(
			    			content = relative_human_time(event, timezone),
			    			font = "tom-thumb",
			    			color = event.get("color"),
		    			),
		    		),
		    		render.Circle(
		    			diameter = 3,
		    			color = event.get("color"),
		    		),
		    	]
		    )
		)
	return output

def joined_summary(summary):
	words = split_summary(summary)
	splitSummary = []
	for item in words:
		if len(item) > 16:
			splitSummary.append(item[:16])
			splitSummary.append(item[16:])
		else:
			splitSummary.append(item)
	output = []
	for item in splitSummary:
		if len(output) > 0 and len(output[-1]) + len(item) <= 16:
			output[-1] += " " + item
		else:
			output.append(item)
	return output

def split_summary(summary):
	output = re.sub("[^\x00-\x7F]+", "", summary)
	output = output.rstrip(" ").lstrip(" ")
	output = output.split(" ")
	return output

def relative_human_time(event, timezone):
	start = time.parse_time(event.get("start"), format="Mon, 02 Jan 2006 15:04:05 MST").in_location(timezone)
	end = time.parse_time(event.get("end"), format="Mon, 02 Jan 2006 15:04:05 MST").in_location(timezone)
	relativeStart = start - time.now()

	output = "in "
	if relativeStart.hours > 24:
		amount = relativeStart.hours/24
		output += humanize.ftoa(amount, 0) + " day"
		if amount >= 2:
			output += "s"
	elif relativeStart.hours > 1:
		amount = relativeStart.hours
		output += humanize.ftoa(amount, 1) + " hr"
		if amount > 1.15:
			output += "s"
	elif relativeStart.minutes > 0:
		amount = relativeStart.minutes
		zero = ""
		if str(math.floor(relativeStart.minutes))[-1:] == "0":
			zero = "0"
		output += humanize.ftoa(amount, 0) + zero + " min"
		if amount >= 2:
			output += "s"
	else:
		output = "until "
		target = humanize.time_format("HH:mm", end)
		output += target
	return output

def get_data(url):
	# cached = cache.get("data")
	# if cached != None:
	# 	response = cached
	# else:
	# 	response = http.get(url).json()
	# 	cache.set("data", response, ttl_seconds=15)
	response = http.get(url).json()
	return response

def get_schema():
	return schema.Schema(
		version = "1",
		fields = [
			schema.Text(
				id = "serverURL",
				name = "Server URL",
				desc = "Link to local python processing server",
				icon = "link",
			),
		],
	)
