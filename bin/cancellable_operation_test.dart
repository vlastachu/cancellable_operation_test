
import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:vm_service/vm_service_io.dart';

class SomeClassForGCTest {}

WeakReference<SomeClassForGCTest> getClosuredWeakRef(Future<void> futureToAwait) {
  final ref = SomeClassForGCTest();
  final runFuture = () async {
    await futureToAwait;
    print(ref);
  };
  runFuture();
  return WeakReference(ref);
}



void main(List<String> arguments) async {
  final cancellable = CancelableOperation.fromFuture(Future.delayed(Duration(hours: 1)));
  final weakRef = getClosuredWeakRef(cancellable.value);
  await forceGC();
  print(weakRef.target);

  cancellable.cancel();
  await forceGC();
  print(weakRef.target);

  Completer? completer = Completer();
  final weakRef2 = getClosuredWeakRef(completer.future);
  await forceGC();
  print(weakRef2.target);

  completer = null;
  await forceGC();
  print(weakRef2.target);

}

/// used to run gc's garbage collection
/// thanks to julemand101 https://stackoverflow.com/a/63730430
Future<void> forceGC() async {
  final serverUri = (await Service.getInfo()).serverUri;

  if (serverUri == null) {
    // ignore: avoid_print
    print('Please run the application with the --observe parameter!');
    return;
  }

  final isolateId = Service.getIsolateID(Isolate.current)!;
  final vmService = await vmServiceConnectUri(_toWebSocket(serverUri));
  await vmService.getAllocationProfile(isolateId, gc: true);
}

List<String> _cleanupPathSegments(Uri uri) {
  final pathSegments = <String>[];
  if (uri.pathSegments.isNotEmpty) {
    pathSegments.addAll(
      uri.pathSegments.where((s) => s.isNotEmpty),
    );
  }
  return pathSegments;
}

String _toWebSocket(Uri uri) {
  final pathSegments = _cleanupPathSegments(uri);
  pathSegments.add('ws');
  return uri.replace(scheme: 'ws', pathSegments: pathSegments).toString();
}
