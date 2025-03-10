import 'dart:async';

Stream<String> captureOutput(FutureOr<void> Function() fn) {
  final controller = StreamController<String>();

  runZoned(
    () async {
      await fn();
      await controller.close();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, message) => controller.add(message),
    ),
  );
  return controller.stream;
}

T silenceOutput<T>(T Function() fn) {
  return runZoned(
    fn,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, message) {},
    ),
  );
}
