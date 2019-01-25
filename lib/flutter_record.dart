import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Singleton class that communicate with a FlutterRecord Instance
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

  static Future<String> get getBasePath async {
    final String basePath = await _channel.invokeMethod('getBasePath');
    return basePath;
  }

  /// Feedback volume of steam
  StreamController<double> volumeSubscription = StreamController.broadcast();

  /// Player is playing?
  bool isPlaying = false;

  /// Recorder is isRecording?
  bool isRecording = false;

  // /// Timer
  // Timer _timer;

  // /// get record duration
  // StreamController<int> recordSubscription = StreamController.broadcast();

  // /// get play duration
  // StreamController<int> playSubscription = StreamController.broadcast();

  Future<void> _handleCallback(MethodCall call) async {
    switch (call.method) {
      case 'updateVolume':
        Map<String, dynamic> result = json.decode(call.arguments);
        _volumeListener(result['current_volume']);
        break;
      case 'playComplete':
        _playComplete();
        break;
      case 'recordComplete':
        _recordComplete();
        break;
    }
  }

  Future<bool> requestPermission() async {
    bool result = await _channel.invokeMethod('requestPermission');
    return result;
  }

  /// Start recorder
  Future<String> startRecorder({String path, double maxVolume}) async {
    assert(path != null);
    if (!isRecording) {
      isRecording = true;

      final params = {'path': path};

      if (maxVolume is double) {
        params.putIfAbsent('maxVolume', () => maxVolume.toString());
      }

      try {
        // if (_timer != null) {
        //   _timer.cancel();
        //   _timer = null;
        // }
        // _timer = _getCurrentTimeTimer(DateTime.now().millisecondsSinceEpoch,
        //     (int currentTime) {
        //   _recordListener(DateTime.now().millisecondsSinceEpoch - currentTime);
        // });
        String result = await _channel.invokeMethod('startRecorder', params);
        return result;
      } catch (e) {
        print(e);
      }
    }
    return 'Recorder is already recording.';
  }

  // Timer _getCurrentTimeTimer(int currentTime, void callback(int currentTime)) {
  //   return Timer.periodic(
  //     Duration(microseconds: 50),
  //     (Timer _) => callback(currentTime),
  //   );
  // }

  Future<void> _stop(String method) async {
    if (isRecording) {
      isRecording = false;

      try {
        await _channel.invokeMethod(method);
      } catch (e) {
        print(e);
      } finally {
        _volumeRemoveListener();
        // _recordRemoveListener();
      }
    }
  }

  /// Stop recorder
  Future<void> stopRecorder() async {
    _stop('stopRecorder');
  }

  /// Cancel recording audio
  Future<void> cancelRecorder() async {
    _stop('cancelRecorder');
  }

  /// Start current play audio
  Future<void> startPlayer({String path}) async {
    assert(path != null);

    if (isPlaying) return stopPlayer();

    isPlaying = true;

    try {
      // if (_timer != null) {
      //   _timer.cancel();
      //   _timer = null;
      // }
      // _timer = _getCurrentTimeTimer(DateTime.now().millisecondsSinceEpoch,
      //     (int currentTime) {
      //   _playListener(DateTime.now().millisecondsSinceEpoch - currentTime);
      // });
      await _channel.invokeMethod('startPlayer', {'path': path});
    } catch (e) {
      print(e);
    }
  }

  /// Pause current play audio
  Future<void> pausePlayer() async {
    if (isPlaying) {
      try {
        _playComplete();

        await _channel.invokeMethod('pausePlayer');
      } catch (e) {
        print(e);
      }
    }
  }

  /// Stop current play audio
  Future<void> stopPlayer() async {
    if (isPlaying) {
      isPlaying = false;

      _playComplete();

      try {
        await _channel.invokeMethod('stopPlayer');
      } catch (e) {
        print(e);
      }
    }
  }

  /// get `path` audio duration
  Future<int> getDuration({String path}) async {
    final dynamic duration =
        await _channel.invokeMethod('getDuration', {'path': path});
    return duration ?? 0;
  }

  /// set current player volume
  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      print(e);
    }
  }

  /// on play complete
  void _playComplete() {
    print('play complete');
    isPlaying = false;
    // _playRemoveListener();
  }

  /// on record complete
  void _recordComplete() {
    print('record complete');
    isRecording = false;
  }

  /// volume listener stream
  void _volumeListener(double volume) {
    volumeSubscription.sink.add(volume);
  }

  /// remove volume listener
  void _volumeRemoveListener() {
    volumeSubscription
      ..add(0)
      ..close();
    volumeSubscription = null;
    volumeSubscription = StreamController.broadcast();
  }

  // /// volume listener stream
  // void _recordListener(int volume) {
  //   recordSubscription.sink.add(volume);
  // }

  // /// remove volume listener
  // void _recordRemoveListener() {
  //   recordSubscription
  //     ..add(0)
  //     ..close();
  //   recordSubscription = null;
  //   recordSubscription = StreamController.broadcast();
  //   _resetTimer();
  // }

  // /// volume listener stream
  // void _playListener(int volume) {
  //   playSubscription.sink.add(volume);
  // }

  // /// remove volume listener
  // void _playRemoveListener() {
  //   playSubscription
  //     ..add(0)
  //     ..close();
  //   playSubscription = null;
  //   playSubscription = StreamController.broadcast();
  //   _resetTimer();
  // }

  // void _resetTimer() {
  //   _timer.cancel();
  //   _timer = null;
  // }
}
