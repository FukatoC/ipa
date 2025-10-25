import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(MyApp(initialCamera: firstCamera, cameras: cameras));
}

class MyApp extends StatelessWidget {
  final CameraDescription initialCamera;
  final List<CameraDescription> cameras;
  const MyApp({required this.initialCamera, required this.cameras, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detección de Género y Edad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF4A148C), // Fondo morado oscuro
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: FaceDetectionPage(camera: initialCamera, cameras: cameras),
    );
  }
}

class FaceDetectionPage extends StatefulWidget {
  final CameraDescription camera;
  final List<CameraDescription> cameras;
  const FaceDetectionPage({required this.camera, required this.cameras, Key? key}) : super(key: key);

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool loading = false;
  String result = '';
  int _cameraIndex = 0;

  final String apiKey = "WanjWnqqJ7rCyLqrlvzsbVbesIKHPyfs";
  final String apiSecret = "TVzO6KYbNkoWDp6-AL1kDbHoOksP09N4";

  @override
  void initState() {
    super.initState();
    _initCamera(widget.camera);
  }

  void _initCamera(CameraDescription camera) {
    _controller = CameraController(
    camera,
    ResolutionPreset.high,
    enableAudio: false, 
  );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _controller.dispose();
    _initCamera(widget.cameras[_cameraIndex]);
  }

  Future<void> _captureAndAnalyze() async {
    try {
      await _initializeControllerFuture;

      final image = await _controller.takePicture();
      setState(() {
        loading = true;
        result = '';
      });

      final response = await _analyzeImage(File(image.path));

      setState(() {
        result = response;
        loading = false;
      });
    } catch (e) {
      setState(() {
        result = "Error: $e";
        loading = false;
      });
    }
  }

  Future<String> _analyzeImage(File imageFile) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/detect');

    var request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['api_secret'] = apiSecret
      ..fields['return_attributes'] = 'gender,age'
      ..files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

    final res = await request.send();
    final body = await res.stream.bytesToString();
    final data = jsonDecode(body);

    if (data['faces'] != null && data['faces'].isNotEmpty) {
      final gender = data['faces'][0]['attributes']['gender']['value'];
      final age = data['faces'][0]['attributes']['age']['value'];
      return "👤 Género detectado: $gender\n🎂 Edad aproximada: $age años";
    } else {
      return "No se detectó ningún rostro en la imagen.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detección de Género y Edad'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: CameraPreview(_controller),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                          label: const Text("Cambiar cámara", style: TextStyle(color: Colors.white)),
                          onPressed: _switchCamera,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9575CD),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          label: const Text('Analizar rostro', style: TextStyle(color: Colors.white)),
                          onPressed: loading ? null : _captureAndAnalyze,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              result,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      color: const Color(0xFF6A1B9A),
                      padding: const EdgeInsets.all(12),
                      child: const Text(
                        "© 2025 - Yan Francis Casayco Contreras | Proyectos",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
          },
        ),
      ),
    );
  }
}
