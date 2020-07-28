import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';

import '../utils.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({Key key, this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _SensorScreenState createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  bool isReady;
  Stream<List<int>> stream;
  List<double> traceDust = List();

  // Camera parameter
  final FaceDetector faceDetector = FirebaseVision.instance.faceDetector();
  List<Face> faces;
  CameraController _camera;
  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    isReady = false;
    connectToDevice();
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

  connectToDevice() async {
    if (widget.device == null) {
      _Pop();
      return;
    }

    new Timer(const Duration(seconds: 15), () {
      if (!isReady) {
        disconnectFromDevice();
        _Pop();
      }
    });

    await widget.device.connect();
    discoverServices();
  }

  disconnectFromDevice() {
    if (widget.device == null) {
      _Pop();
      return;
    }

    widget.device.disconnect();
  }

  discoverServices() async {
    if (widget.device == null) {
      _Pop();
      return;
    }

    List<BluetoothService> services = await widget.device.discoverServices();
    services.forEach((service) {
      if (service.uuid.toString() == SERVICE_UUID) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
            characteristic.setNotifyValue(!characteristic.isNotifying);
            stream = characteristic.value;

            setState(() {
              isReady = true;
            });
          }
        });
      }
    });

    if (!isReady) {
      _Pop();
    }
  }

  Future<bool> _onWillPop() {
    return showDialog(
        context: context,
        builder: (context) =>
            new AlertDialog(
              title: Text('Are you sure?'),
              content: Text('Do you want to disconnect device and go back?'),
              actions: <Widget>[
                new FlatButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: new Text('No')),
                new FlatButton(
                    onPressed: () {
                      disconnectFromDevice();
                      Navigator.of(context).pop(true);
                    },
                    child: new Text('Yes')),
              ],
            ) ??
            false);
  }

  _Pop() {
    Navigator.of(context).pop(true);
  }

  String _dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
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
    painter = TestPainter(imageSize, faces);

    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Body Temperature Sensor'),
          actions: <Widget>[
            IconButton(
              icon: Icon(_direction == CameraLensDirection.back
                  ? Icons.camera_front
                  : Icons.camera_rear),
              onPressed: _toggleCameraDirection,
            )
          ],
        ),
        body: Container(
          child: !isReady
              ? Center(
                  child: Text(
                    "Waiting...",
                    style: TextStyle(fontSize: 24, color: Colors.red),
                  ),
                )
              : Container(
                  child: StreamBuilder<List<int>>(
                    stream: stream,
                    builder: (BuildContext context,
                        AsyncSnapshot<List<int>> snapshot) {
                      if (snapshot.hasError)
                        return Text('Error: ${snapshot.error}');

                      if (snapshot.connectionState == ConnectionState.active) {
                        var currentValue = _dataParser(snapshot.data);
                        traceDust.add(double.tryParse(currentValue) ?? 0);

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text('Current value from Sensor',
                                        style: TextStyle(fontSize: 14)),
                                    Text('${currentValue} deg.(C)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24))
                                  ]),
                              Expanded(
                                flex: 1,
                                child: Container(
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
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Text('Check the stream');
                      }
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class TestPainter extends CustomPainter {
  final Size imageSize;
  final List<Face> faces;
  TestPainter(this.imageSize, this.faces);

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
