import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'confirmation_screen.dart';

class CameraScreen extends StatefulWidget {
  final String metodoUsado;
  const CameraScreen({super.key, this.metodoUsado = 'ID+Rostro'});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _procesando = false;
  String? _error;
  final List<String> _debugLog = [];

  void _log(String mensaje) {
    debugPrint('[DEBUG] $mensaje');
    if (mounted) {
      setState(() {
        _debugLog.add('${DateTime.now().toIso8601String().substring(11, 19)} - $mensaje');
      });
    }
  }

  Future<Map<String, double>?> _obtenerUbicacion() async {
    try {
      _log('📍 Verificando permisos de ubicación...');
      
      // Timeout global: si tarda >8s, seguir sin GPS
      return await Future.any([
        _obtenerUbicacionReal(),
        Future.delayed(const Duration(seconds: 8), () {
          _log('⚠️ Timeout de GPS (8s), continuando sin ubicación');
          return null;
        }),
      ]);
    } catch (e) {
      _log('⚠️ GPS falló: $e');
      return null;
    }
  }

  Future<Map<String, double>?> _obtenerUbicacionReal() async {
    try {
      var permission = await Geolocator.checkPermission();
      _log('📍 Permiso actual: $permission');
      
      if (permission == LocationPermission.denied) {
        _log('📍 Solicitando permiso (puede requerir interacción del usuario)...');
        
        // ⚠️ En Safari iOS, esto puede NO resolver. El Future.any lo cubre.
        permission = await Geolocator.requestPermission();
        _log('📍 Permiso después de solicitar: $permission');
      }
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log('⚠️ Permiso denegado, continuando sin GPS');
        return null;
      }
      
      _log('📍 Obteniendo posición GPS...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      _log('✅ GPS obtenido: ${position.latitude}, ${position.longitude}');
      return {
        'latitud': position.latitude,
        'longitud': position.longitude,
      };
    } catch (e) {
      _log('⚠️ GPS real falló: $e');
      return null;
    }
  }

  Future<void> _tomarFotoYChecar() async {
    if (_procesando) return;
    
    setState(() {
      _procesando = true;
      _error = null;
      _debugLog.clear();
    });

    try {
      _log('📷 Abriendo cámara...');
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
        maxWidth: 800,
      );
      
      if (foto == null) {
        _log('⚠️ Usuario canceló la cámara');
        if (mounted) setState(() => _procesando = false);
        return;
      }
      _log('✅ Foto capturada: ${foto.path}');
      _log('📏 Tamaño: ${await foto.length()} bytes');

      _log('📖 Leyendo bytes...');
      final bytes = await foto.readAsBytes();
      _log('✅ Bytes leídos: ${bytes.length} bytes');

      _log('🔐 Codificando a Base64...');
      final fotoBase64 = base64Encode(bytes);
      _log('✅ Base64 generado: ${fotoBase64.length} caracteres');

      _log('👤 Leyendo sesión...');
      final numero = await StorageService.leerNumeroEmpleado();
      final pin = await StorageService.leerPin();
      if (numero == null || pin == null) {
        throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
      }
      _log('✅ Sesión: $numero');

      // Obtener ubicación (opcional, con timeout)
      _log('📍 Obteniendo ubicación...');
      final ubicacion = await _obtenerUbicacion();

      _log('🚀 Enviando checada al servidor...');
      final sw = Stopwatch()..start();
      
      final response = await ApiService.registrarChecadaEmpleado(
        numeroEmpleado: numero,
        pin: pin,
        metodoUsado: widget.metodoUsado,  // ← DINÁMICO
        fotoBase64: fotoBase64,
        latitud: ubicacion?['latitud'],
        longitud: ubicacion?['longitud'],
      );
      
      sw.stop();
      _log('✅ Respuesta del servidor en ${sw.elapsedMilliseconds} ms');
      _log('📦 Tipo: ${response['tipoChecada']}');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmationScreen(
            mensaje: response['mensaje'] as String,
            tipoChecada: response['tipoChecada'] as String,
            nombreEmpleado: response['empleado']['nombreCompleto'] as String,
            hash: response['hash'] as String,
            timestamp: response['timestampServidor'] as String,
          ),
        ),
      );
    } catch (e) {
      _log('❌ ERROR: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checar con rostro')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face, size: 80, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Coloca tu rostro en el óvalo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Asegúrate de tener buena luz y mirar de frente',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppTheme.error), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _procesando ? null : _tomarFotoYChecar,
                      icon: _procesando
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(_procesando ? 'Procesando...' : 'Tomar foto y checar'),
                    ),
                  ),
                  // 🎯 DEBUG LOG VISIBLE
                  if (_debugLog.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bug_report, color: Colors.greenAccent, size: 16),
                              SizedBox(width: 8),
                              Text('Log de ejecución', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._debugLog.map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
