import 'dart:async';

import 'package:flutter/services.dart';
import 'audio_options.dart';
import 'volume_options.dart';
import 'player_options.dart';
import 'observableBuilder.dart';

class FlutterRecord {
  static FlutterRecord _instance;

  factory FlutterRecord() => _instance ??= FlutterRecord._();

  FlutterRecord._() {
    _channel.setMethodCallHandler(_handleCallback);
  }

  static const MethodChannel _channel = const MethodChannel('flutter_record');

  ObservableBuilder<double> dbStream = ObservableBuilder<double>(initValue: 0);
  ObservableBuilder<int> recTimeStream = ObservableBuilder<int>(initValue: 0);
  ObservableBuilder<int> playTimeStream = ObservableBuilder<int>(initValue: 0);

  bool playing = false;

  void _resetRecordSteam() {
    dbStream.reset();
    recTimeStream.reset();
  }

  Future<void> _handleCallback(MethodCall call) async {
    print(call.arguments.toString());
    switch (call.method) {
      case 'dB_Spl_Max':
        dbStream.next(call.arguments);
        break;
      case 'record_time_stream':
        recTimeStream.next(call.arguments);
        break;
      case 'play_time_stream':
        playTimeStream.next(call.arguments);
        break;
      case 'notify_play_complete':
        playing = false;
        break;
    }
  }

  Future<T> _invoke<T>(String fnName, [Map<String, dynamic> params]) async {
    T result;
    try {
      print(params.keys.length);
      result = params.keys.length > 1
          ? await _channel.invokeMethod(fnName, params)
          : await _channel.invokeMethod(fnName);
    } catch (e) {
      print('''FlutterRecord Error: 
      Method: $fnName
      $e''');
    }
    print(result.runtimeType);
    return result;
  }

  Future<String> startRecorder(
    String filename, {
    AudioOptions audioOptions = const AudioOptions(),
    VolumeOptions volumeOptions = const VolumeOptions(),
  }) async {
    assert(!filename.contains("/"));
    final audio = audioOptions.toJson();
    final volume = volumeOptions.toJson();
    return _invoke<String>('startRecorder', {
      'filename': filename,
      'audioOptions': audio,
      'volumeOptions': volume,
    });
  }

  Future<void> stopRecorder() async {
    await _invoke<void>('stopRecorder');
    _resetRecordSteam();
  }

  Future<void> cancelRecorder() async {
    await _invoke('stopRecorder', {"delete": true});
    _resetRecordSteam();
  }

  Future<void> startPlayer(
    String path, {
    PlayerOptions playerOptions = const PlayerOptions(),
  }) async {
    playing = true;
    final player = playerOptions.toJson();
    await _invoke('startPlayer', {
      'path': path,
      'playerOptions': player,
    });
  }

  Future<void> stopPlayer() async {
    await _invoke('stopPlayer');
    playTimeStream.reset();
  }

  Future<void> pausePlayer() async {
    await _invoke('pausePlayer');
  }

  Future<void> resumePlayer() async {
    await _invoke('resumePlayer');
  }

  Future<int> getDuration(String path) async {
    return await _invoke<int>('getDuration', {'path': path}) ?? 0;
  }

  Future<void> setVolume(double volume) async {
    await _invoke('setVolume', {'volume': volume});
  }
}
