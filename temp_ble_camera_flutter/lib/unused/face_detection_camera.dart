import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:math' as Math;
import '../utils.dart';

class FaceDetectionFromLiveCamera extends StatefulWidget {
  // var currentTemp;
  FaceDetectionFromLiveCamera({Key key}) : super(key: key);

  @override
  _FaceDetectionFromLiveCameraState createState() =>
      _FaceDetectionFromLiveCameraState();
}

class _FaceDetectionFromLiveCameraState
    extends State<FaceDetectionFromLiveCamera> {
  final FaceDetector faceDetector = FirebaseVision.instance.faceDetector();
  List<Face> faces;
  CameraController _camera;

  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );

    _camera = CameraController(
      description,
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
    );
    await _camera.initialize();

    _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      detect(image, FirebaseVision.instance.faceDetector().processImage,
              rotation)
          .then(
        (dynamic result) {
          setState(() {
            faces = result;
          });

          _isDetecting = false;
        },
      ).catchError(
        (_) {
          _isDetecting = false;
        },
      );
    });
  }

  Widget _testPainting() {
    const Text noResultsText = const Text('No results!');
    if (faces == null || _camera == null || !_camera.value.isInitialized) {
      return noResultsText;
    }
    CustomPainter painter;
    final Size imageSize = Size(
      _camera.value.previewSize.height,
      _camera.value.previewSize.width,
    );
    if (faces is! List<Face>) return noResultsText;
    painter = _TestPainter(imageSize, faces);

    return CustomPaint(
      painter: painter,
    );
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: _camera == null
          ? const Center(
              child: Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30.0,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CameraPreview(_camera),
                _testPainting(),
                Positioned(
                  bottom: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: Container(
                    color: Colors.white,
                    height: 50.0,
                    child: Text('deg.(C)'),
                  ),
                ),
              ],
            ),
    );
  }

  void _toggleCameraDirection() async {
    if (_direction == CameraLensDirection.back) {
      _direction = CameraLensDirection.front;
    } else {
      _direction = CameraLensDirection.back;
    }

    await _camera.stopImageStream();
    await _camera.dispose();

    setState(() {
      _camera = null;
    });

    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Face Detection with Smile"),
        actions: <Widget>[
          IconButton(
            icon: Icon(_direction == CameraLensDirection.back
                ? Icons.camera_front
                : Icons.camera_rear),
            onPressed: _toggleCameraDirection,
          )
        ],
      ),
      body: _buildImage(),
    );
  }
}

class _TestPainter extends CustomPainter {
  final Size imageSize;
  final List<Face> faces;
  _TestPainter(this.imageSize, this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.length > 0) {
      double faceX =
          faces[0].boundingBox.center.dx * size.width / imageSize.width;
      double faceY =
          faces[0].boundingBox.center.dy * size.height / imageSize.height;
      double distance = Math.sqrt(
          Math.pow((faceX - 180.0), 2.0) + Math.pow((faceY - 280.0), 2.0));
      print(faceX);
      print(faceY);
      print(distance);
      final rect = Rect.fromLTRB(20, 20, 340, 500);
      //Radius for smile circle
      final radius = Math.min(rect.width, rect.height) / 2;
      var c = Offset(180, 280);
      var paint = Paint()
        ..isAntiAlias = true
        ..color = distance < 25.0 ? Colors.red : Colors.blue
        ..strokeWidth = 5.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(
        c,
        radius,
        paint,
      );
    } else {
      final rect = Rect.fromLTRB(20, 20, 340, 500);
      //Radius for smile circle
      final radius = Math.min(rect.width, rect.height) / 2;
      var c = Offset(200, 260);
      var paint = Paint()
        ..isAntiAlias = true
        ..color = Colors.blue
        ..strokeWidth = 5.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(
        c,
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

Rect _scaleRect({
  @required Rect rect,
  @required Size imageSize,
  @required Size widgetSize,
}) {
  final double scaleX = widgetSize.width / imageSize.width;
  final double scaleY = widgetSize.height / imageSize.height;

  return Rect.fromLTRB(
    rect.left.toDouble() * scaleX,
    rect.top.toDouble() * scaleY,
    rect.right.toDouble() * scaleX,
    rect.bottom.toDouble() * scaleY,
  );
}
