import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts queued-operation payloads at rest (section 42: "Encrypted Local
/// Storage"). The AES-256 key lives in the platform keystore (Android
/// Keystore / iOS Keychain via flutter_secure_storage) -- never in the
/// sqflite database alongside the ciphertext it protects, since a device
/// left unlocked or a rooted/jailbroken read of the app's SQLite file
/// should not itself expose the queue's patient references and pack scans.
///
/// AES-GCM (not CBC) is deliberate: it's authenticated, so a corrupted or
/// tampered ciphertext fails to decrypt loudly instead of silently
/// producing garbage that gets synced as if it were real data.
class QueueEncryption {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyStorageKey = 'stericord_offline_queue_key_v1';

  enc.Key? _cachedKey;

  Future<enc.Key> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final existing = await _secureStorage.read(key: _keyStorageKey);
    if (existing != null) {
      _cachedKey = enc.Key.fromBase64(existing);
      return _cachedKey!;
    }

    final random = Random.secure();
    final keyBytes = Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
    final key = enc.Key(keyBytes);
    await _secureStorage.write(key: _keyStorageKey, value: key.base64);
    _cachedKey = key;
    return key;
  }

  /// Returns a single base64 string containing the IV and ciphertext,
  /// self-contained so decryption never depends on a separately-stored IV.
  Future<String> encrypt(String plaintext) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(12);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final combined = iv.bytes + encrypted.bytes;
    return base64Encode(combined);
  }

  Future<String> decrypt(String encoded) async {
    final key = await _getOrCreateKey();
    final combined = base64Decode(encoded);
    final iv = enc.IV(Uint8List.fromList(combined.sublist(0, 12)));
    final ciphertext = combined.sublist(12);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return encrypter.decrypt(enc.Encrypted(Uint8List.fromList(ciphertext)), iv: iv);
  }
}
