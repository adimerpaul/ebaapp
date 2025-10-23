import 'package:ebaapp/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _importing = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameCtrl.text.trim();
    setState(() => _loading = true);
    try {
      final user = await DatabaseHelper().loginWithUsername(username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenido, ${user['name']}')),
      );
      Navigator.pushReplacementNamed(context, '/menu');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login fallido: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importar() async {
    FocusScope.of(context).unfocus();
    setState(() => _importing = true);
    try {
      final result = await DatabaseHelper().importFromServer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importación OK: users ${result.users}, productores ${result.productores}, apiarios ${result.apiarios}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar: $e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiUrl = dotenv.env['API_URL'] ?? '(sin API_URL)';

    return Scaffold(
      // Fondo con gradiente
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.9, -1.0),
            end: Alignment(1.0, 0.8),
            colors: [
              Color(0xFF1E3C72), // azul profundo
              Color(0xFF2A5298), // azul intermedio
              Color(0xFF5DA7FF), // acento claro
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 86,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Título y subtítulo
                    Text(
                      'EBA App',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accede para gestionar Productores y Apiarios',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    // Tarjeta del formulario
                    Card(
                      elevation: 10,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Campo username
                              TextFormField(
                                controller: _usernameCtrl,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _doLogin(),
                                decoration: InputDecoration(
                                  labelText: 'Usuario',
                                  hintText: 'Ej: jdiaz',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Ingresa tu username';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'Mínimo 3 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Botón ingresar
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _doLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2A5298),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.login_rounded),
                                      SizedBox(width: 8),
                                      Text('Ingresar'),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),
                              // Línea divisoria suave
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(height: 1, color: Colors.grey.shade200),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('o', style: TextStyle(color: Colors.grey)),
                                  ),
                                  Expanded(
                                    child: Container(height: 1, color: Colors.grey.shade200),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Botón importar
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton.icon(
                                  onPressed: _importing ? null : _importar,
                                  icon: _importing
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                      : const Icon(Icons.cloud_download_outlined),
                                  label: Text(_importing ? 'Importando…' : 'Importar datos'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2A5298),
                                    side: BorderSide(color: Colors.blue.shade200),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Pie con info de API
                    Text(
                      'API: $apiUrl',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),
                    Text(
                      '© ${DateTime.now().year} — EBA',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
