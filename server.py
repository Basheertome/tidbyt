import sys
import math
import json
from datetime import date, datetime, timezone, timedelta
import icalendar
import recurring_ical_events
import urllib.request
from flask import Flask, jsonify, request

app = Flask("Calendar Server")

@app.route("/", methods=["GET"])
def main():
	print("processing...")
	try:
		file = open('../config.json')
		config = json.load(file)
		file.close()
	except:
		file = open('config.json')
		config = json.load(file)
		file.close()
	try:
		username = config.get("username")
		timezone = config.get("timezone")

		threshold = float(config.get("threshold"))
		today = date.today()
		now = datetime.now().astimezone()
		endDate = date.today() + timedelta(days = math.ceil(threshold/24.0 + 1))

		output = {"timezone": timezone}

		events = []
		calendars = config.get("calendars")
		for calendar in calendars:
			for event in process_calendar(calendar.get("url"), today, endDate):
				if not check_declined(event, username):
					eventDict = process_event(event, calendar.get("color"))
					if not eventDict.get("allday") and eventDict.get("busy") and now <= eventDict.get("end"): 
						events.append(eventDict)
		sortedEvents = []
		for event in events:
			relativeStart = (event.get("start") - now).total_seconds()/3600.0
			if relativeStart < threshold:
				sortedEvents.append(event)
		if len(sortedEvents) > 0:
			sortedEvents.sort(key=startFilter)
			if len(sortedEvents) > 1:
				futureEvents = []
				for event in sortedEvents:
					relativeStart = (event.get("start") - now).total_seconds()/60.0
					if (relativeStart > -15):
						futureEvents.append(event)
				if len(futureEvents) > 0:
					sortedEvents = futureEvents
			output.update({"event": sortedEvents[0]})

		print("done")
		return jsonify(output)
	except Exception as e:
		print(e)
		return jsonify({"error": e})

def startFilter(event):
	return event.get("start")

def process_event(event, color):
	summary = event.decoded("summary").decode()
	start = event.decoded("dtstart")
	end = event.decoded("dtend")
	busy = True
	if (event.decoded("transp").decode() == "TRANSPARENT"):
		busy = False
	try:
		allday = False
		start.time()
	except:
		allday = True
	return {
		"summary": summary,
		"start": start,
		"end": end,
		"allday": allday,
		"busy": busy,
		"color": color
	}

def check_participant(attendee, username):
	declined = False
	if username[1][1:-1] in attendee and attendee.params["partstat"] == "DECLINED":
		declined = True
	return declined

def check_declined(event, username):
	try:
		attendees = event.get("attendee")
		try:
			if len(attendees[0]) > 1:
				for attendee in attendees:
					declined = check_participant(attendee, username)
			else:
				declined = check_participant(attendees, username)
		except:
			declined = False
	except:
		declined = False
	return declined

def process_calendar(url, start, end):
	ical_string = urllib.request.urlopen(url).read()
	calendar = icalendar.Calendar.from_ical(ical_string)
	events = recurring_ical_events.of(calendar).between(start, end)
	return events

@app.errorhandler(404)
def not_found(error):
	return jsonify({"error": "404 Not Found"}), 404

if __name__ == "__main__":
	app.run(debug=True)
