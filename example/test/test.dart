import 'package:flutter_test/flutter_test.dart';
import 'package:get_secure_storage/get_secure_storage.dart';

void main() {
  const counter = 'counter';
  const isDarkMode = 'isDarkMode';
  GetSecureStorage box = GetSecureStorage();
  test('GetSecureStorage read and write operation', () {
    box.write(counter, 0);
    expect(box.read(counter), 0);
  });

  test('save the state of brightness mode of app in GetSecureStorage', () {
    box.write(isDarkMode, true);
    expect(box.read(isDarkMode), true);
  });
}
