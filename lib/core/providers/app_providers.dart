import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_store.dart';

enum BackendMode { demo, firebase }

class AppBackend {
  AppBackend({
    required this.mode,
    this.auth,
    this.firestore,
    this.storage,
  });

  final BackendMode mode;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;

  bool get isDemo => mode == BackendMode.demo;
}

final appBackendProvider = Provider<AppBackend>((ref) {
  throw UnimplementedError('appBackendProvider must be overridden in main');
});

final demoStoreProvider = Provider<DemoStore>((ref) => DemoStore.instance);

extension DemoUserBootstrap on DemoStore {
  Stream<String?> watchUid() async* {
    yield sessionUser?.id;
    yield* userStream.map((u) => u?.id);
  }
}

final authUidProvider = StreamProvider<String?>((ref) {
  final backend = ref.watch(appBackendProvider);
  if (backend.isDemo) {
    final store = ref.watch(demoStoreProvider);
    return store.watchUid();
  }
  return backend.auth!.authStateChanges().map((u) => u?.uid);
});

String? readCurrentUid(Ref ref) {
  final backend = ref.read(appBackendProvider);
  if (backend.isDemo) {
    return ref.read(demoStoreProvider).sessionUser?.id;
  }
  return backend.auth!.currentUser?.uid;
}

void logBackend(String message) {
  debugPrint('[LedgerOne] $message');
}
