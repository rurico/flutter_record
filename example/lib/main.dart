import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_record/flutter_record.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  FlutterRecord _flutterRecord;
  double _volume = 0.0;
  int _duration = 0;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _flutterRecord = FlutterRecord();
  }

  Future<void> initPlatformState() async {
    String platformVersion;

    try {
      platformVersion = await FlutterRecord.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Running on: $_platformVersion\n'),
              SizedBox(height: 50.0),
              Text('$_volume'),
              FlatButton(
                child: Text('startRecorder'),
                onPressed: () async {
                  String path = await _flutterRecord.startRecorder(
                      path: 'test', maxVolume: 7.0);

                  print(path);

                  _flutterRecord.volumeSubscription.stream.listen((volume) {
                    setState(() {
                      _volume = volume;
                    });
                  });
                },
              ),
              FlatButton(
                child: Text('stopRecorder'),
                onPressed: () async {
                  await _flutterRecord.stopRecorder();
                },
              ),
              FlatButton(
                child: Text('cancelRecorder'),
                onPressed: () async {
                  await _flutterRecord.cancelRecorder();
                },
              ),
              FlatButton(
                child: Text('startPlayer'),
                onPressed: () async {
                  await _flutterRecord.startPlayer(path: 'test');
                  await _flutterRecord.setVolume(1.0);
                },
              ),
              FlatButton(
                child: Text('pausePlayer'),
                onPressed: () async {
                  await _flutterRecord.pausePlayer();
                },
              ),
              FlatButton(
                child: Text('stopPlay'),
                onPressed: () async {
                  await _flutterRecord.stopPlayer();
                },
              ),
              Text('$_duration'),
              FlatButton(
                child: Text('getDuration'),
                onPressed: () async {
                  final int duration =
                      await _flutterRecord.getDuration(path: 'test');
                  setState(() {
                    _duration = duration;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
