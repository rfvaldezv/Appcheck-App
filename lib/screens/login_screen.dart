import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _numeroController = TextEditingController();
  final _pinController = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<void> _login() async {
    final numero = _numeroController.text.trim();
    final pin = _pinController.text.trim();

    if (numero.isEmpty || pin.isEmpty) {
      setState(() => _error = 'Ingresa tu número de empleado y PIN.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final response = await ApiService.validarPin(
        numeroEmpleado: numero,
        pin: pin,
      );

      final nombre = response['nombre'] as String;
      await StorageService.guardarSesion(
        numeroEmpleado: numero,
        nombre: nombre,
        pin: pin,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 80, color: AppTheme.primary),
                  const SizedBox(height: 24),
                  const Text(
                    'AppCheck',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Checador de asistencia',
                    style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _numeroController,
                    decoration: const InputDecoration(
                      labelText: 'Número de Empleado',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppTheme.error)),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _login,
                      child: _cargando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Entrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
