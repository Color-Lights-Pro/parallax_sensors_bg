library parallax_sensors_bg;

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'parallax_sensors.dart';
export 'parallax_sensors.dart';

class Layer {
  Layer({
    Key? key,
    required this.sensitivity,
    this.offset,
    this.widget,
    this.imageFit = BoxFit.cover,
    this.preventCrop = false,
    this.imageHeight,
    this.imageWidth,
    this.imageBlurValue,
    this.imageDarkenValue,
    this.opacity,
    this.child,
  });

  final double sensitivity;
  final Offset? offset;
  final Widget? widget;
  final BoxFit imageFit;
  final bool preventCrop;
  final double? imageHeight;
  final double? imageWidth;
  double? imageBlurValue;
  double? imageDarkenValue;
  double? opacity;
  final Widget? child;

  Widget _build(
      BuildContext context,
      int animationDuration,
      double maxSensitivity,
      ValueNotifier<double> top,
      ValueNotifier<double> bottom,
      ValueNotifier<double> right,
      ValueNotifier<double> left) {
    return ValueListenableBuilder<double>(
      valueListenable: top,
      builder: (context, topValue, _) {
        return ValueListenableBuilder<double>(
          valueListenable: bottom,
          builder: (context, bottomValue, _) {
            return ValueListenableBuilder<double>(
              valueListenable: right,
              builder: (context, rightValue, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: left,
                  builder: (context, leftValue, _) {
                    return AnimatedPositioned(
                      duration: Duration(milliseconds: animationDuration),
                      top: (preventCrop
                          ? (topValue - maxSensitivity) * sensitivity
                          : topValue * sensitivity +
                          (MediaQuery.of(context).size.height -
                              (imageHeight ??
                                  MediaQuery.of(context).size.height)) / 2) +
                          ((offset?.dy ?? 0) / 2),
                      bottom: (preventCrop
                          ? (bottomValue - maxSensitivity) * sensitivity
                          : bottomValue * sensitivity +
                          (MediaQuery.of(context).size.height -
                              (imageHeight ??
                                  MediaQuery.of(context).size.height)) / 2) -
                          ((offset?.dy ?? 0) / 2),
                      right: (preventCrop
                          ? (rightValue - maxSensitivity) * sensitivity
                          : rightValue * sensitivity +
                          (MediaQuery.of(context).size.width -
                              (imageWidth ??
                                  MediaQuery.of(context).size.width)) / 2) -
                          ((offset?.dx ?? 0) / 2),
                      left: (preventCrop
                          ? (leftValue - maxSensitivity) * sensitivity
                          : leftValue * sensitivity +
                          (MediaQuery.of(context).size.width -
                              (imageWidth ??
                                  MediaQuery.of(context).size.width)) / 2) +
                          ((offset?.dx ?? 0) / 2),
                      child: Opacity(
                        opacity: opacity ?? 1,
                        child: Container(
                          height: imageHeight,
                          width: imageWidth,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (widget != null)
                                FittedBox(
                                  fit: imageFit,
                                  child: SizedBox(
                                    height: imageHeight,
                                    width: imageWidth,
                                    child: widget,
                                  ),
                                ),
                              if (imageBlurValue != null ||
                                  imageDarkenValue != null)
                                ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: imageBlurValue ?? 0,
                                        sigmaY: imageBlurValue ?? 0),
                                    child: Container(
                                      height: imageHeight,
                                      width: imageWidth,
                                      color: Colors.black.withOpacity(
                                          imageDarkenValue ?? 0),
                                    ),
                                  ),
                                ),
                              child ?? const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class Parallax extends StatefulWidget {
  const Parallax({
    Key? key,
    this.sensor = ParallaxSensor.accelerometer,
    required this.layers,
    this.reverseVerticalAxis = false,
    this.reverseHorizontalAxis = false,
    this.lockVerticalAxis = false,
    this.lockHorizontalAxis = false,
    this.animationDuration = 300,
    this.child,
  }) : super(key: key);

  final ParallaxSensor sensor;
  final List<Layer> layers;
  final bool reverseVerticalAxis;
  final bool reverseHorizontalAxis;
  final bool lockVerticalAxis;
  final bool lockHorizontalAxis;
  final int animationDuration;
  final Widget? child;

  @override
  State<Parallax> createState() => _ParallaxState();
}

class _ParallaxState extends State<Parallax> {
  StreamSubscription<AccelerometerEvent>? _accelerometerSensorEvent;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSensorEvent;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSensorEvent;
  StreamSubscription<MagnetometerEvent>? _magnetometerSensorEvent;

  ValueNotifier<double> _top = ValueNotifier<double>(0);
  ValueNotifier<double> _bottom = ValueNotifier<double>(0);
  ValueNotifier<double> _right = ValueNotifier<double>(0);
  ValueNotifier<double> _left = ValueNotifier<double>(0);
  double _maxSensitivity = 0;
  DateTime _lastUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    switch (widget.sensor) {
      case ParallaxSensor.accelerometer:
        _accelerometerSensorEvent =
            accelerometerEvents.listen((AccelerometerEvent event) {
              _maxSensitivity = 10;
              _processSensorEvent(event.x, event.y);
            });
        break;

      case ParallaxSensor.userAccelerometer:
        _userAccelerometerSensorEvent =
            userAccelerometerEvents.listen((UserAccelerometerEvent event) {
              _maxSensitivity = 10;
              _processSensorEvent(event.x, event.y);
            });
        break;

      case ParallaxSensor.gyroscope:
        _gyroscopeSensorEvent = gyroscopeEvents.listen((GyroscopeEvent event) {
          _maxSensitivity = 10;
          _processSensorEvent(event.y, event.x);
        });
        break;

      case ParallaxSensor.magnetometer:
        _magnetometerSensorEvent =
            magnetometerEvents.listen((MagnetometerEvent event) {
              _maxSensitivity = 50;
              _processSensorEvent(event.x, event.y);
            });
        break;
    }
  }

  void _processSensorEvent(double x, double y) {
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds > 100) {
      _lastUpdate = now;
      if (_shouldUpdateValues(x, y)) {
        _top.value = widget.lockVerticalAxis ? 0 : widget.reverseVerticalAxis ? -y : y;
        _bottom.value = widget.lockVerticalAxis ? 0 : widget.reverseVerticalAxis ? y : -y;
        _right.value = widget.lockHorizontalAxis ? 0 : widget.reverseHorizontalAxis ? -x : x;
        _left.value = widget.lockHorizontalAxis ? 0 : widget.reverseHorizontalAxis ? x : -x;
        setState(() {});
      }
    }
  }

  bool _shouldUpdateValues(double x, double y) {
    // Update only if there is a significant change
    const double threshold = 0.1;
    return (x - _left.value).abs() > threshold || (y - _top.value).abs() > threshold;
  }

  @override
  void dispose() {
    _accelerometerSensorEvent?.cancel();
    _userAccelerometerSensorEvent?.cancel();
    _gyroscopeSensorEvent?.cancel();
    _magnetometerSensorEvent?.cancel();
    _top.dispose();
    _bottom.dispose();
    _right.dispose();
    _left.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Stack(
          children: widget.layers
              .map((layer) => layer._build(context, widget.animationDuration,
              _maxSensitivity, _top, _bottom, _right, _left))
              .toList(),
        ),
        widget.child ?? Container(),
      ],
    );
  }
}

enum ParallaxSensor {
  accelerometer,
  userAccelerometer,
  gyroscope,
  magnetometer
}

