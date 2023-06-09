import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' hide Key;
import 'package:get/utils.dart';
import 'package:cryptography/cryptography.dart';

import 'storage/html.dart' if (dart.library.io) 'storage/io.dart';
import 'value.dart';

/// Instantiate GetSecureStorage to access storage driver apis
class GetSecureStorage {
  static String kNonce = 'nonce';
  static String kMac = 'mac';
  static String kCipherText = 'cipherText';

  factory GetSecureStorage(
      {String container = 'GetSecureStorage',
      String? password,
      String? path,
      Map<String, dynamic>? initialData}) {
    if (_sync.containsKey(container)) {
      return _sync[container]!;
    } else {
      final instance =
          GetSecureStorage._internal(container, path, initialData, password);
      _sync[container] = instance;
      return instance;
    }
  }

  GetSecureStorage._internal(String key,
      [String? path, Map<String, dynamic>? initialData, String? password]) {
    _concrete = StorageImpl(key, path);
    _initialData = initialData;

    // _privatekey = privatekey;
    initStorage = Future<bool>(() async {
      if (password != null) {
        algorithm = AesCtr.with128bits(macAlgorithm: Hmac.sha256());
        final pbkdf2 = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 1000, // 1000 iterations
          bits: 128, // 256 bits = 32 bytes output
        );
        secretKey = await pbkdf2.deriveKeyFromPassword(
          password: password,
          nonce: password.runes.toList().reversed.toList(),
        );
      }
      await _init();
      return true;
    });
  }

  static final Map<String, GetSecureStorage> _sync = {};

  final microtask = Microtask();

  /// Start the storage drive. It's important to use await before calling this API, or side effects will occur.
  static Future<bool> init(
      {String container = 'GetSecureStorage', String? password}) {
    WidgetsFlutterBinding.ensureInitialized();
    return GetSecureStorage(container: container, password: password)
        .initStorage;
  }

  Future<void> _init() async {
    try {
      await _concrete.init(_initialData, _encrypt, _decrypt);
    } catch (err) {
      throw err;
    }
  }

  bool _isListInt(dynamic jsonObj) =>
      jsonObj is List && jsonObj.every((element) => element is int);

  Future<String> _decrypt(String value) async {
    if (algorithm != null) {
      final jsonPayload = json.decode(value);
      if (jsonPayload == null ||
          !jsonPayload.containsKey(kCipherText) ||
          !jsonPayload.containsKey(kMac) ||
          !jsonPayload.containsKey(kNonce)) {
        return value;
      }

      if (!_isListInt(jsonPayload[kNonce]) ||
          !_isListInt(jsonPayload[kCipherText]) ||
          !_isListInt(jsonPayload[kMac])) {
        return '';
      }
      final secretBox = SecretBox(
        jsonPayload[kCipherText].cast<int>(),
        nonce: jsonPayload[kNonce].cast<int>(),
        mac: Mac(jsonPayload[kMac].cast<int>()),
      );
      try {
        final cleartxt = await algorithm!.decryptString(
          secretBox,
          secretKey: secretKey!,
        );
        return cleartxt;
      } catch (e) {}
      return '';
    } else {
      return value;
    }
  }

  Future<String> _encrypt(String value) async {
    if (algorithm != null) {
      final secretBox = await algorithm!.encryptString(
        value,
        secretKey: secretKey!,
      );
      final jsonPayload = {
        kNonce: secretBox.nonce,
        kMac: secretBox.mac.bytes,
        kCipherText: secretBox.cipherText,
      };
      return json.encode(jsonPayload);
    } else {
      return value;
    }
  }

  /// Reads a value in your container with the given key.
  T? read<T>(String key) {
    return _concrete.read(key);
  }

  T getKeys<T>() {
    return _concrete.getKeys();
  }

  T getValues<T>() {
    return _concrete.getValues();
  }

  /// return data true if value is different of null;
  bool hasData(String key) {
    return (read(key) == null ? false : true);
  }

  Map<String, dynamic> get changes => _concrete.subject.changes;

  /// Listen changes in your container
  VoidCallback listen(VoidCallback value) {
    return _concrete.subject.addListener(value);
  }

  Map<Function, Function> _keyListeners = <Function, Function>{};

  VoidCallback listenKey(String key, ValueSetter callback) {
    final VoidCallback listen = () {
      if (changes.keys.first == key) {
        callback(changes[key]);
      }
    };

    _keyListeners[callback] = listen;
    return _concrete.subject.addListener(listen);
  }

  /// Write data on your container
  Future<void> write(String key, dynamic value) async {
    writeInMemory(key, value);
    return _tryFlush();
  }

  void writeInMemory(String key, dynamic value) {
    _concrete.write(key, value);
  }

  /// Write data on your only if data is null
  Future<void> writeIfNull(String key, dynamic value) async {
    if (read(key) != null) return;
    return write(key, value);
  }

  /// remove data from container by key
  Future<void> remove(String key) async {
    _concrete.remove(key);
    return _tryFlush();
  }

  /// clear all data on your container
  Future<void> erase() async {
    _concrete.clear();
    return _tryFlush();
  }

  Future<void> save() async {
    return _tryFlush();
  }

  Future<void> _tryFlush() async {
    return microtask.exec(_addToQueue);
  }

  Future _addToQueue() {
    return queue.add(_flush);
  }

  Future<void> _flush() async {
    try {
      await _concrete.flush();
    } catch (e) {
      rethrow;
    }
    return;
  }

  late StorageImpl _concrete;

  GetQueue queue = GetQueue();

  /// listenable of container
  ValueStorage<Map<String, dynamic>> get listenable => _concrete.subject;

  /// Start the storage drive. Important: use await before calling this api, or side effects will happen.
  late Future<bool> initStorage;
  Map<String, dynamic>? _initialData;
  AesCtr? algorithm;
  SecretKey? secretKey;
}

class Microtask {
  int _version = 0;
  int _microtask = 0;

  void exec(Function callback) {
    if (_microtask == _version) {
      _microtask++;
      scheduleMicrotask(() {
        _version++;
        _microtask = _version;
        callback();
      });
    }
  }
}

typedef KeyCallback = Function(String);
typedef Future<String> StringCallback(String input);
