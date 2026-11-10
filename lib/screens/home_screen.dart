import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'camera_screen.dart';
import 'huella_screen.dart';
import 'confirmation_screen.dart';
import 'login_screen.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _nombre;
  String? _metodo;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSesion();
  }

  Future<void> _cargarSesion() async {
    final nombre = await StorageService.leerNombreEmpleado();
    final metodo = await StorageService.leerMetodo();
    if (mounted) {
      setState(() {
        _nombre = nombre;
        _metodo = metodo ?? 'ID+Rostro';
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await StorageService.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  String _descripcionMetodo() {
    switch (_metodo) {
      case 'QR':
        return 'QR (solo Kiosko)';
      case 'QR+Rostro':
        return 'QR + Rostro (solo Kiosko)';
      case 'ID+PIN':
        return 'Checar con ID + PIN';
      case 'ID+Rostro':
        return 'Checar con ID + Rostro';
      case 'Rostro':
        return 'Checar con Rostro';
      case 'Huella':
        return 'Checar con Huella';
      default:
        return 'Checar';
    }
  }

  IconData _iconoMetodo() {
    switch (_metodo) {
      case 'QR':
      case 'QR+Rostro':
        return Icons.qr_code_scanner;
      case 'ID+PIN':
        return Icons.pin;
      case 'ID+Rostro':
      case 'Rostro':
        return Icons.camera_alt;
      case 'Huella':
        return Icons.fingerprint;
      default:
        return Icons.check_circle;
    }
  }

  Future<void> _checar() async {
    if (_procesando) return;

    final metodo = _metodo ?? 'ID+Rostro';

    // 🆕 Validar métodos no disponibles en PWA
    if (metodo == 'QR' || metodo == 'QR+Rostro') {
      setState(() {
        _error = 'Este método solo está disponible en el Kiosko de oficina. '
                 'Usa ID+PIN, ID+Rostro o Rostro desde tu celular.';
      });
      return;
    }

    // 🆕 SIEMPRE capturar GPS (antes de decidir el método)
    setState(() {
      _procesando = true;
      _error = null;
    });

    try {
      final ubicacion = await _obtenerUbicacion();

      // Si el método NO requiere cámara, registrar directo
      if (metodo == 'ID+PIN') {
        final numero = await StorageService.leerNumeroEmpleado();
        final pin = await StorageService.leerPin();
        if (numero == null || pin == null) {
          throw Exception('Sesión expirada. Vuelve a iniciar sesión.');
        }

        final response = await ApiService.registrarChecadaEmpleado(
          numeroEmpleado: numero,
          pin: pin,
          metodoUsado: metodo,
          latitud: ubicacion?['latitud'],
          longitud: ubicacion?['longitud'],
        );

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
        return;
      }

      // Si es Huella, ir a HuellaScreen (Próximamente)
      if (metodo == 'Huella') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HuellaScreen()),
        );
        return;
      }

      // Si requiere cámara (ID+Rostro, Rostro), ir a CameraScreen CON GPS
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CameraScreen(
            metodoUsado: metodo,
            latitud: ubicacion?['latitud'],
            longitud: ubicacion?['longitud'],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<Map<String, double>?> _obtenerUbicacion() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return {
        'latitud': position.latitude,
        'longitud': position.longitude,
      };
    } catch (e) {
      print('⚠️ No se pudo obtener ubicación: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppCheck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 64, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Hola, ${_nombre ?? 'Empleado'}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Método: ${_descripcionMetodo()}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: ElevatedButton(
                      onPressed: _procesando ? null : _checar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _procesando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_iconoMetodo(), size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  _descripcionMetodo(),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.error),
                        textAlign: TextAlign.center,
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
