import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data_layer.dart';

final dataLayerProvider = FutureProvider<DataLayer>((ref) async {
  final layer = await DataLayer.open();
  layer.sync.start();
  ref.onDispose(() {
    unawaited(() async {
      await layer.sync.dispose();
      await layer.close();
    }());
  });
  return layer;
});
