// main.dart
// Blind Assist App – Flutter
// Vision, Gesture (stream), Audio modes

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:path_provider/path_provider.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const BlindAssistApp());
}

class BlindAssistApp extends StatelessWidget {
  const BlindAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blind Assist',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0F1F),
        primaryColor: Colors.cyanAccent,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _logController = TextEditingController();

  final FlutterTts tts = FlutterTts();
  final FlutterSoundRecord recorder = FlutterSoundRecord();

  Timer? _gestureTimer;
  bool _gestureRunning = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    tts.setSpeechRate(0.45);
  }

  Future<void> _initCamera() async {
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );
    await _cameraController!.initialize();
    setState(() {});
  }

  void log(String msg) {
    _logController.text += "\n$msg";
  }

  bool get hasValidIP => _ipController.text.trim().isNotEmpty;

  Future<String> captureBase64Image() async {
    if (!_cameraController!.value.isInitialized) {
      throw Exception("Camera not ready");
    }
    final image = await _cameraController!.takePicture();
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  // ================= VISION MODE =================
  Future<void> sendVision() async {
    if (!hasValidIP) return log("❌ Enter server IP");

    log("📷 Vision Mode started");
    final img64 = await captureBase64Image();

    final res = await http.post(
      Uri.parse("http://${_ipController.text}:5050"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"mode": "vision", "image": img64}),
    );

    final result = jsonDecode(res.body)['result'];
    log("➡ $result");
    await tts.speak(result);
  }

  // ================= GESTURE MODE =================
  void toggleGesture() {
    if (!hasValidIP) {
      log("❌ Enter server IP");
      return;
    }

    if (_gestureRunning) {
      _gestureTimer?.cancel();
      _gestureRunning = false;
      log("🛑 Gesture Mode stopped");
      return;
    }

    log("✋ Gesture Mode started (streaming)");
    _gestureRunning = true;

    _gestureTimer = Timer.periodic(const Duration(milliseconds: 800), (
      _,
    ) async {
      final img64 = await captureBase64Image();

      final res = await http.post(
        Uri.parse("http://${_ipController.text}:5050"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"mode": "gesture", "image": img64}),
      );

      final result = jsonDecode(res.body)['result'];
      log("➡ $result");
      await tts.speak(result);
    });
  }

  // ================= AUDIO MODE =================
  Future<void> sendAudio() async {
    if (!hasValidIP) return log("❌ Enter server IP");

    log("🎤 Audio Mode recording (10 sec)");

    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/audio.wav";

    if (await recorder.hasPermission()) {
      await recorder.start(path: path);

      await Future.delayed(const Duration(seconds: 10));
      await recorder.stop();

      final bytes = await File(path).readAsBytes();
      final base64Audio = base64Encode(bytes);

      final res = await http.post(
        Uri.parse("http://${_ipController.text}:5050"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"mode": "audio", "image": base64Audio}),
      );

      final result = jsonDecode(res.body)['result'];
      log("➡ $result");
      await tts.speak(result);
    } else {
      log("❌ Microphone permission denied");
    }
  }

  @override
  void dispose() {
    _gestureTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blind Assist")),
      body: Column(
        children: [
          if (_cameraController?.value.isInitialized ?? false)
            SizedBox(height: 180, child: CameraPreview(_cameraController!)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ipController,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                labelText: "Server IP Address",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _logController,
                maxLines: null,
                readOnly: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: sendVision,
                child: const Text("Vision Mode"),
              ),
              ElevatedButton(
                onPressed: toggleGesture,
                child: const Text("Gesture Mode"),
              ),
              ElevatedButton(
                onPressed: sendAudio,
                child: const Text("Audio Mode"),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
