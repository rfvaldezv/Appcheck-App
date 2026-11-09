import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HuellaScreen extends StatelessWidget {
  const HuellaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checar con Huella')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 96, color: AppTheme.primary),
              const SizedBox(height: 24),
              const Text(
                'Próximamente',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'La huella digital en la app estará disponible pronto.\n'
                'Por ahora, usa ID + PIN o ID + Rostro.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
