import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../errors/app_exception.dart';
import '../providers/app_providers.dart';
import '../utils/rate_limiter.dart';

class StorageService {
  StorageService(this._ref);

  final Ref _ref;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  FirebaseStorage? get _storage {
    final backend = _ref.read(appBackendProvider);
    return backend.storage;
  }

  /// Picks an image and uploads profile photo. Returns download URL.
  Future<String> uploadProfilePhoto(String uid) async {
    RateLimiter.instance.ensureAllowed(
      'storage_upload',
      max: 8,
      windowSeconds: 60,
    );
    final storage = _storage;
    if (storage == null) {
      throw DataException('Storage unavailable in demo mode');
    }

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) {
      throw DataException('Selection cancelled');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw DataException('Image must be under 5 MB');
    }

    final contentType = _guessContentType(file.name);
    final ref = storage.ref('users/$uid/profile/avatar.jpg');
    try {
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: contentType),
      );
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw DataException(_mapStorageError(e), code: e.code);
    }
  }

  /// Uploads a receipt image for a transaction. Returns download URL.
  Future<String> uploadReceipt({
    required String uid,
    required String transactionId,
  }) async {
    RateLimiter.instance.ensureAllowed(
      'storage_upload',
      max: 8,
      windowSeconds: 60,
    );
    final storage = _storage;
    if (storage == null) {
      throw DataException('Storage unavailable in demo mode');
    }

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) {
      throw DataException('Selection cancelled');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw DataException('Receipt must be under 8 MB');
    }

    final id =
        '${transactionId.isEmpty ? "receipt" : transactionId}_${_uuid.v4()}';
    final ref = storage.ref('users/$uid/receipts/$id.jpg');
    try {
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: _guessContentType(file.name)),
      );
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw DataException(_mapStorageError(e), code: e.code);
    }
  }

  String _guessContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _mapStorageError(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'Storage permission denied. Sign in again and redeploy storage rules.';
      case 'object-not-found':
        return 'File not found in Storage';
      case 'canceled':
        return 'Upload cancelled';
      case 'retry-limit-exceeded':
        return 'Upload failed after retries. Check your connection.';
      default:
        if (kIsWeb) {
          return 'Storage upload failed on web. Ensure the Storage bucket exists, '
              'CORS is configured, and rules are deployed. (${e.code})';
        }
        return e.message ?? 'Storage upload failed (${e.code})';
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref);
});
