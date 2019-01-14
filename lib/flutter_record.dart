import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class FlutterRecord {
  static FlutterRecord _instance;

  factory FlutterRecord() => _instance ??= FlutterRecord._();

  FlutterRecord._() {
    _channel.setMethodCallHandler(_handleCallback);
  }

  static const MethodChannel _channel = const MethodChannel('flutter_record');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  StreamController<double> volumeController = StreamController.broadcast();

  bool isPlaying = false;

  bool isRecording = false;

  Future<void> _handleCallback(MethodCall call) async {
    switch (call.method) {
      case 'updateVolume':
        Map<String, dynamic> result = json.decode(call.arguments);
        _volumeListener(result['current_volume']);
        break;
      case 'playComplete':
        _playComplete();
        break;
    }
  }

  FutureOr<String> startRecorder({String path, double maxVolume}) async {
    assert(path != null);
    if (!isRecording) {
      isRecording = true;

      final params = {'path': path};

      if (maxVolume is double) {
        params.putIfAbsent('maxVolume', () => maxVolume.toString());
      }

      try {
        String result = await _channel.invokeMethod('startRecorder', params);
        return result;
      } catch (e) {
        print(e);
      }
    }
    return 'Recorder is already recording.';
  }

  Future<void> _stop(String method) async {
    if (isRecording) {
      isRecording = false;

      try {
        print(await _channel.invokeMethod(method));
      } catch (e) {
        print(e);
      } finally {
        _volumeRemoveListener();
      }
    }
  }

  Future<void> stopRecorder() async {
    _stop('stopRecorder');
  }

  Future<void> cancelRecorder() async {
    _stop('cancelRecorder');
  }

  Future<void> startPlayer({String path}) async {
    assert(path != null);

    if (isPlaying) return stopPlayer();

    isPlaying = true;

    try {
      print(await _channel.invokeMethod('startPlayer', {'path': path}));
    } catch (e) {
      print(e);
    }
  }

  Future<void> stopPlayer() async {
    if (isPlaying) {
      isPlaying = false;

      try {
        print(await _channel.invokeMethod('stopPlayer'));
      } catch (e) {
        print(e);
      }
    }
  }

  Future<int> getDuration({String path}) async {
    final dynamic duration =
        await _channel.invokeMethod('getDuration', {'path': path});
    return duration ?? 0;
  }

  Future<void> setVolume(double volume) async {
    try {
      print(await _channel.invokeMethod('setVolume', {'volume': volume}));
    } catch (e) {
      print(e);
    }
  }

  void _playComplete() {
    print('complete');
    isPlaying = false;
  }

  void _volumeListener(double volume) {
    volumeController.sink.add(volume);
  }

  void _volumeRemoveListener() {
    volumeController
      ..add(0)
      ..close();
    volumeController = StreamController.broadcast();
  }
}
