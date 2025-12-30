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
