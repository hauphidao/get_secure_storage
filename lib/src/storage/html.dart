import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:get_secure_storage/get_secure_storage.dart';

class StorageImpl {
  StorageImpl(this.fileName, [this.path]);
  html.Storage get localStorage => html.window.localStorage;

  final String? path;
  final String fileName;
  StringCallback _encrypt = (input) async => input;
  StringCallback _decrypt = (input) async => input;

  ValueStorage<Map<String, dynamic>> subject =
      ValueStorage<Map<String, dynamic>>(<String, dynamic>{});

  void clear() {
    localStorage.remove(fileName);
    subject.value?.clear();

    subject
      ..value?.clear()
      ..changeValue("", null);
  }

  static deleteContainer(container, [String? path]) {}

  Future<bool> _exists() async {
    return localStorage.containsKey(fileName);
  }

  Future<void> flush() {
    return _writeToStorage(subject.value ?? {});
  }

  T? read<T>(String key) {
    return subject.value![key] as T?;
  }

  T getKeys<T>() {
    return subject.value!.keys as T;
  }

  T getValues<T>() {
    return subject.value!.values as T;
  }

  Future<void> init(Map<String, dynamic>? initialData, StringCallback encrypt,
      StringCallback decrypt) async {
    _encrypt = encrypt;
    _decrypt = decrypt;
    subject.value = initialData ?? <String, dynamic>{};
    if (await _exists()) {
      await _readFromStorage();
    } else {
      await _writeToStorage(subject.value ?? {});
    }
    return;
  }

  void remove(String key) {
    subject
      ..value?.remove(key)
      ..changeValue(key, null);
    //  return _writeToStorage(subject.value);
  }

  void write(String key, dynamic value) {
    subject
      ..value![key] = value
      ..changeValue(key, value);
    //return _writeToStorage(subject.value);
  }

  // void writeInMemory(String key, dynamic value) {

  // }

  Future<void> _writeToStorage(Map<String, dynamic> data) async {
    final subjectValue = await _encrypt(json.encode(subject.value));
    localStorage.update(fileName, (val) => subjectValue,
        ifAbsent: () => subjectValue);
  }

  Future<void> _readFromStorage() async {
    final dataFromLocal = localStorage.entries.firstWhereOrNull(
      (value) {
        return value.key == fileName;
      },
    );
    if (dataFromLocal != null) {
      String dataValue = await _decrypt(dataFromLocal.value);
      subject.value = json.decode(dataValue) as Map<String, dynamic>;
    } else {
      await _writeToStorage(<String, dynamic>{});
    }
  }
}

extension FirstWhereExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
