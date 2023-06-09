import 'package:flutter/material.dart';
import 'package:get_secure_storage/get_secure_storage.dart';

void main() async {
  await GetSecureStorage.init(password: 'password');
  runApp(const App());
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final box = GetSecureStorage();
  bool get isDark => box.read('darkmode') ?? false;
  void changeTheme(bool val) {
    box.write('darkmode', val);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text("GetSecureStorage")),
        body: Center(
          child: SwitchListTile(
            value: isDark,
            title: const Text("Touch to change ThemeMode"),
            onChanged: changeTheme,
          ),
        ),
      ),
    );
  }
}
