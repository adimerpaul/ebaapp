import 'package:ebaapp/pages/login_page.dart';
import 'package:ebaapp/pages/menu_page.dart';
import 'package:ebaapp/pages/register_page.dart';
import 'package:ebaapp/services/database_helper.dart';
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
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        // '/': (context) => const LoginPage(),
        '/': (context) => const VerifiPage(),
        '/menu': (context) => const MenuPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage()
      },
      initialRoute: '/',
    );
  }
}

class VerifiPage extends StatefulWidget {
  const VerifiPage({super.key});

  @override
  State<VerifiPage> createState() => _VerifiPageState();
}

class _VerifiPageState extends State<VerifiPage> {
  @override
  void initState() {
    super.initState();
    verificarLogin();
  }
  Future<void> verificarLogin() async {
    final user = await DatabaseHelper().currentUser();
    print('user en verifi: $user');
    if (user != null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/menu');
    } else {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

