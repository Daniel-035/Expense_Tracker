import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class DeviceLock {
  const DeviceLock({this.pin, this.biometric = false});
  final String? pin;
  final bool biometric;
  bool get enabled => pin != null || biometric;
}

class DeviceLockService {
  final _storage = const FlutterSecureStorage();
  String _key(String uid) => 'ledgerone_lock_$uid';

  Future<DeviceLock> read(String uid) async {
    final raw = await _storage.read(key: _key(uid));
    if (raw == null) return const DeviceLock();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return DeviceLock(
      pin: data['pin'] as String?,
      biometric: data['biometric'] == true,
    );
  }

  Future<void> write(String uid, DeviceLock lock) async {
    if (lock.pin != null && !RegExp(r'^\d{4,6}$').hasMatch(lock.pin!)) {
      throw StateError('Use a 4–6 digit PIN.');
    }
    await _storage.write(
      key: _key(uid),
      value: jsonEncode({'pin': lock.pin, 'biometric': lock.biometric}),
    );
  }

  Future<void> clear(String uid) => _storage.delete(key: _key(uid));
  Future<bool> biometric() async {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) {
      throw StateError('Device authentication is unavailable.');
    }
    return auth.authenticate(localizedReason: 'Unlock LedgerOne');
  }
}

final deviceLockServiceProvider = Provider((ref) => DeviceLockService());
final deviceLockProvider = FutureProvider.family<DeviceLock, String>(
  (ref, uid) => ref.watch(deviceLockServiceProvider).read(uid),
);
