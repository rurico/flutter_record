import 'dart:async';
import 'package:meta/meta.dart';

class ObservableBuilder<T> {
  ObservableBuilder({
  // @nullnable 
  @required this.initValue})
      : assert(initValue != null);
  final T initValue;
  StreamController<T> _observable = StreamController.broadcast();

  get stream => _observable.stream;

  void next(T value) {
    _observable.sink.add(value);
  }

  void reset([bool resetInitValue = true]) {
    close(resetInitValue);
    _observable = null;
    _observable = StreamController.broadcast();
  }

  void close([bool resetInitValue = true]) {
    if (resetInitValue != null) {
      _observable
        ..add(initValue)
        ..close();
    } else {
      _observable.close();
    }
  }
}

// @pragma("vm:non-nullable-result-type")
// class Nullnable {
//   const Nullnable();
//   factory Nullnable._uninstantiable() {
//     throw new UnsupportedError('class Nullnable cannot be instantiated');
//   }
// }

// const nullnable = const Nullnable();
