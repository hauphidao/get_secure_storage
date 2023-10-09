import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:get_secure_storage/get_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class StorageImpl {
  StorageImpl(this.fileName, [this.path]);

  final String? path;
  final String fileName;
  StringCallback _encrypt = (input) async => input;
  StringCallback _decrypt = (input) async => input;

  final ValueStorage<Map<String, dynamic>> subject = ValueStorage<Map<String, dynamic>>(<String, dynamic>{});

  RandomAccessFile? _randomAccessfile;

  void clear() async {
    subject
      ..value?.clear()
      ..changeValue("", null);
  }

  Future<void> deleteBox() async {
    final box = await _fileDb(isBackup: false);
    final backup = await _fileDb(isBackup: true);
    await Future.wait([box.delete(), backup.delete()]);
  }

  Future<void> flush() async {
    final buffer = utf8.encode(await _encrypt(json.encode(subject.value)));
    final length = buffer.length;
    RandomAccessFile file = await _getRandomFile();

    _randomAccessfile = await file.lock();
    _randomAccessfile = await _randomAccessfile!.setPosition(0);
    _randomAccessfile = await _randomAccessfile!.writeFrom(buffer);
    _randomAccessfile = await _randomAccessfile!.truncate(length);
    _randomAccessfile = await file.unlock();
    _madeBackup();
  }

  void _madeBackup() async {
    final subjectValue = await _encrypt(json.encode(subject.value));
    _getFile(true).then(
      (value) => value.writeAsString(
        subjectValue,
        flush: true,
      ),
    );
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

  Future<void> init(Map<String, dynamic>? initialData, StringCallback encrypt, StringCallback decrypt) async {
    _encrypt = encrypt;
    _decrypt = decrypt;
    subject.value = initialData ?? <String, dynamic>{};

    RandomAccessFile file = await _getRandomFile();
    return file.lengthSync() == 0 ? flush() : _readFile();
  }

  void remove(String key) {
    subject
      ..value!.remove(key)
      ..changeValue(key, null);
  }

  void write(String key, dynamic value) {
    subject
      ..value![key] = value
      ..changeValue(key, value);
  }

  Future<void> _readFile() async {
    try {
      RandomAccessFile file = await _getRandomFile();
      file = await file.setPosition(0);
      final buffer = Uint8List(await file.length());
      await file.readInto(buffer);
      subject.value = json.decode(await _decrypt(utf8.decode(buffer)));
    } catch (e) {
      Get.log('Corrupted box, recovering backup file', isError: true);
      final file = await _getFile(true);

      dynamic content = {};
      try {
        content = await _decrypt((await file.readAsString())..trim());
      } on Exception catch (_) {}

      if (content.isEmpty) {
        subject.value = {};
      } else {
        try {
          subject.value = (json.decode(content) as Map<String, dynamic>?) ?? {};
        } catch (e) {
          Get.log('Can not recover Corrupted box', isError: true);
          subject.value = {};
        }
      }
      flush();
    }
  }

  Future<RandomAccessFile> _getRandomFile() async {
    if (_randomAccessfile != null) return _randomAccessfile!;
    final fileDb = await _getFile(false);
    _randomAccessfile = await fileDb.open(mode: FileMode.append);

    return _randomAccessfile!;
  }

  Future<bool> _hasFile() async {
    final fileDb = await _fileDb(isBackup: false);
    if (fileDb.existsSync()) return true;
    final backupDb = await _fileDb(isBackup: true);
    if (backupDb.existsSync()) return true;
    return false;
  }

  _deleteFile() async {
    final fileDb = await _fileDb(isBackup: false);
    await fileDb.delete();
    final backupDb = await _fileDb(isBackup: true);
    await backupDb.delete();
  }

  Future<File> _getFile(bool isBackup) async {
    final fileDb = await _fileDb(isBackup: isBackup);
    if (!fileDb.existsSync()) {
      fileDb.createSync(recursive: true);
    }
    return fileDb;
  }

  Future<File> _fileDb({required bool isBackup}) async {
    final dir = await _getImplicitDir();
    final filepath = await _getPath(isBackup, path ?? dir.path);
    final file = File(filepath);
    return file;
  }

  Future<Directory> _getImplicitDir() async {
    try {
      return getApplicationDocumentsDirectory();
    } catch (err) {
      rethrow;
    }
  }

  Future<String> _getPath(bool isBackup, String? path) async {
    final isWindows = GetPlatform.isWindows;
    final separator = isWindows ? '\\' : '/';
    return isBackup ? '$path$separator$fileName.bak' : '$path$separator$fileName.gs';
  }

  static deleteContainer(container, [String? path]) async {
    final tmp = StorageImpl(container, path);
    await tmp._deleteFile();
  }

  static Future<bool> hasContainer(container, [String? path]) async {
    final tmp = StorageImpl(container, path);
    return tmp._hasFile();
  }
}
