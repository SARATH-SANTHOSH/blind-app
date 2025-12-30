Blind Assist App – Backend Integration Guide

This document explains how the Flutter Blind Assist mobile application communicates with the backend server and what the backend developer must implement.

1. Overview

The Blind Assist mobile app connects to a local backend server (Python/Flask/FastAPI preferred) over HTTP.

The backend performs:

Vision analysis (image understanding)

Gesture recognition (streamed images)

Audio understanding (speech / sound analysis)

The app:

Captures camera images or audio

Converts them to Base64

Sends them to the backend via POST requests

Receives a text response

Speaks the response using Text-to-Speech

2. Network Requirements

Backend must run on the same local network as the mobile phone

Backend must be reachable via IP address

Example:

Mobile Phone IP: 192.168.1.10
Backend Server IP: 192.168.1.5


App input:

Server IP Address = 192.168.1.5


Backend port:

5050


Base URL:

http://<SERVER_IP>:5050

3. API Endpoint
Endpoint
POST /


Only one endpoint is used for all modes.

4. Request Format
Headers
Content-Type: application/json

Request Body (JSON)
{
  "mode": "<vision | gesture | audio>",
  "image": "<base64_encoded_data>"
}

Field explanation:
Field	Description
mode	Operation mode (vision, gesture, or audio)
image	Base64 encoded image or audio data
5. Mode Details
5.1 Vision Mode

App captures single camera image

Sends it once to backend

Example request:

{
  "mode": "vision",
  "image": "/9j/4AAQSkZJRgABAQAAAQABAAD..."
}


Expected backend task:

Object detection

Scene understanding

Obstacle awareness

5.2 Gesture Mode (Streaming)

App captures images every ~800 ms

Sends images continuously

Backend must process frames independently

Example request:

{
  "mode": "gesture",
  "image": "/9j/4AAQSkZJRgABAQAAAQABAAD..."
}


Expected backend task:

Hand gesture recognition

Return gesture meaning (e.g., “Swipe Left”)

⚠️ Important:

Backend must respond fast

No long blocking operations

5.3 Audio Mode

App records 10 seconds of audio

Encodes audio as Base64

Sends it as "image" field (name kept for consistency)

Example request:

{
  "mode": "audio",
  "image": "UklGRkAAAABXQVZFZm10IBAAAAABAAEA..."
}


Expected backend task:

Speech recognition

Audio classification

Command understanding

6. Response Format (VERY IMPORTANT)

Backend must always return JSON in the following format:

{
  "result": "Human readable text response"
}


Example responses:

{ "result": "I see a person standing in front of you" }

{ "result": "Gesture detected: Thumbs Up" }

{ "result": "You said: What is in front of me" }

7. Error Handling

Backend should never crash or return plain text.

On error, return:

{
  "result": "Unable to process request. Please try again."
}


Recommended HTTP status codes:

200 → success

400 → invalid input

500 → internal error (still return JSON)

8. Backend Technology (Recommended)

Python 3.9+

Flask or FastAPI

OpenCV / MediaPipe / YOLO (vision & gesture)

Whisper / SpeechRecognition (audio)

Base64 decoding support




9. Sample Flask Backend Skeleton
from flask import Flask, request, jsonify
import base64

app = Flask(__name__)

@app.route("/", methods=["POST"])
def process():
    data = request.json
    mode = data.get("mode")
    payload = data.get("image")

    if not mode or not payload:
        return jsonify({"result": "Invalid request"}), 400

    if mode == "vision":
        result = "Vision processed"
    elif mode == "gesture":
        result = "Gesture processed"
    elif mode == "audio":
        result = "Audio processed"
    else:
        result = "Unknown mode"

    return jsonify({"result": result})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050)

10. Important Notes

Backend must support large Base64 payloads

Responses must be fast (<1 second) for gesture mode

Always return JSON

Do not change field names (mode, image, result)

11. Testing

Test using:

Postman

curl

Flutter app directly

Example curl:

curl -X POST http://192.168.1.5:5050 \
-H "Content-Type: application/json" \
-d '{"mode":"vision","image":"BASE64_DATA"}'

12. Summary

Single POST endpoint

Three modes

Base64 in → text out

Fast, reliable, JSON-only responses