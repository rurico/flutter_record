import 'package:flutter/material.dart';
import 'package:flutter_record/flutter_record.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterRecord _flutterRecord;
  double _dbspl = 0;
  int _duration = 0;
  String path;
  int _time = 0;

  @override
  void initState() {
    super.initState();
    _flutterRecord = FlutterRecord();
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
              SizedBox(height: 50.0),
              Text('dbspl:$_dbspl'),
              Text('time:$_time'),
              FlatButton(
                child: Text('startRecorder'),
                onPressed: () async {
                  path = await _flutterRecord.startRecorder('test');

                  print(path);

                  _flutterRecord.dbStream.stream.listen((dbspl) {
                    setState(() {
                      _dbspl = dbspl;
                    });
                  });

                  _flutterRecord.recTimeStream.stream.listen((time) {
                    setState(() {
                      _time = time;
                    });
                    print(time);
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
                  await _flutterRecord.startPlayer(path);
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
                  final int duration = await _flutterRecord.getDuration(path);
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
