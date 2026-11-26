import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Periodically checks whether the device can resolve a Firebase host.
/// This reports basic internet reachability; it does not guarantee that every
/// Firebase service is available.
final internetStatusProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    var connected = false;
    try {
      final addresses = await InternetAddress.lookup('firebase.google.com')
          .timeout(const Duration(seconds: 4));
      connected = addresses.isNotEmpty;
    } on Exception {
      connected = false;
    }

    yield connected;
    await Future<void>.delayed(const Duration(seconds: 15));
  }
});
