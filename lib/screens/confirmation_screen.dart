import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class ConfirmationScreen extends StatelessWidget {
  final String mensaje;
  final String tipoChecada;
  final String nombreEmpleado;
  final String hash;
  final String timestamp;

  const ConfirmationScreen({
    super.key,
    required this.mensaje,
    required this.tipoChecada,
    required this.nombreEmpleado,
    required this.hash,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final esEntrada = tipoChecada.toLowerCase() == 'entrada';
    final color = esEntrada ? AppTheme.success : AppTheme.warning;

    return Scaffold(
      backgroundColor: color,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    esEntrada ? Icons.check_circle : Icons.exit_to_app,
                    size: 120,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tipoChecada.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombreEmpleado,
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: color,
                      ),
                      child: const Text('Aceptar'),
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
