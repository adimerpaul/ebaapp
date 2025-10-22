import 'package:ebaapp/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  await dotenv.load(fileName: isProduction ? '.env.production' : '.env');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eba app',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/': (context) => LoginPage(),
      },
      initialRoute: '/',
    );
  }
}
