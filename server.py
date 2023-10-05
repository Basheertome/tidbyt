from __future__ import print_function

import sys
import math
import json
from datetime import date, datetime, timezone, timedelta

import os.path

from flask import Flask, jsonify, request

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

app = Flask("Calendar Server")

SCOPES = ['https://www.googleapis.com/auth/calendar.readonly']

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
		timezone = config.get("timezone")
		threshold = float(config.get("threshold"))

		now = datetime.now().astimezone()

		output = {"timezone": timezone}

		events = []
		calendars = config.get("calendars")
		for calendar in calendars:
			for event in process_calendar(calendar, threshold):
				if not check_declined(event):
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
	summary = event.get("summary")
	start = event.get("start")
	end = event.get("end")
	busy = True
	if (event.get("transparency") == "transparent"):
		busy = False
	if "date" in start:
		allday = True
		start = datetime.strptime(start.get("date"), "%Y-%m-%d")
		end = datetime.strptime(end.get("date"), "%Y-%m-%d")
	else:
		start = datetime.fromisoformat(start.get("dateTime")).astimezone()
		end = datetime.fromisoformat(end.get("dateTime")).astimezone()
		if ((end - start).days > 0):
			allday = True
		else:
			allday = False

	return {
		"summary": summary,
		"start": start,
		"end": end,
		"allday": allday,
		"busy": busy,
		"color": color
	}

def check_declined(event):
	declined = False
	try:
		attendees = event.get("attendees")
		for attendee in attendees:
			if attendee.get("self") and attendee.get("responseStatus") == 'declined':
				declined = True
	except:
		declined = False
	return declined

def process_calendar(calendar, threshold):
	calendar_name = calendar.get("name")
	calid = calendar.get("id")
	token_file = calendar_name + '_creds.json'

	creds = None

	if os.path.exists(token_file):
	    creds = Credentials.from_authorized_user_file(token_file, SCOPES)

	if not creds or not creds.valid:
	    print("Going to ask for permissions for your " + calendar_name + "calendar...")
	    if creds and creds.expired and creds.refresh_token:
	        creds.refresh(Request())
	    else:
	        flow = InstalledAppFlow.from_client_secrets_file(
	            'credentials.json', SCOPES)
	        creds = flow.run_local_server(port=0)
	    with open(token_file, 'w') as token:
	        token.write(creds.to_json())
	
	try:
	    service = build('calendar', 'v3', credentials=creds)
	    time_min = (datetime.utcnow() - timedelta(hours=threshold)).isoformat() + 'Z'
	    time_max = (datetime.utcnow() + timedelta(hours=threshold)).isoformat() + 'Z'
	    events_result = service.events().list(calendarId=calid, timeMin=time_min, timeMax=time_max,
	                                          maxResults=10, singleEvents=True,
	                                          orderBy='startTime').execute()
	    events = events_result.get('items', [])
	
	except HttpError as error:
	    print('An error occurred: %s' % error)
	
	return events

@app.errorhandler(404)
def not_found(error):
	return jsonify({"error": "404 Not Found"}), 404

if __name__ == "__main__":
	app.run(debug=True)
