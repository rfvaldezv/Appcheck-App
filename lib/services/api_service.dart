import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;

  // =====================================================
  // 1. Recuperar token por deviceId
  // =====================================================
  static Future<Map<String, dynamic>> recuperarToken({required String deviceId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/kiosko/recuperar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': deviceId}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(jsonDecode(response.body)['mensaje'] ?? 'Error al recuperar token');
    } catch (e) {
      throw Exception('Error al recuperar token: $e');
    }
  }

  // =====================================================
  // 2. Activar kiosko con código (primera vez)
  // =====================================================
  static Future<Map<String, dynamic>> activarKiosko({
    required String codigo,
    required String deviceId,
    required String nombreKiosko,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/kiosko/activar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'codigo': codigo,
          'deviceId': deviceId,
          'nombreKiosko': nombreKiosko,
          'tipo': 'KioskoFijo',
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(jsonDecode(response.body)['mensaje'] ?? 'Error al activar');
    } catch (e) {
      throw Exception('Error al activar: $e');
    }
  }

  // =====================================================
  // 3. Validar ID + PIN del empleado
  // =====================================================
  static Future<Map<String, dynamic>> validarPin({
    required String numeroEmpleado,
    required String pin,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/employee/validar-pin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'numeroEmpleado': numeroEmpleado,
          'pin': pin,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(jsonDecode(response.body)['mensaje'] ?? 'PIN incorrecto');
    } catch (e) {
      throw Exception('Error al validar PIN: $e');
    }
  }

  // =====================================================
  // 4. Registrar checada (con GPS opcional)
  // =====================================================
  static Future<Map<String, dynamic>> registrarChecada({
    required String tokenPuntoLectura,
    required String numeroEmpleado,
    required String metodoUsado,
    String? fotoBase64,
    String? pin,
    double? latitud,
    double? longitud,
  }) async {
    Future<http.Response> postChecada(String token) => http.post(
      Uri.parse('$baseUrl/api/checada'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'numeroEmpleado': numeroEmpleado,
        'tokenPuntoLectura': token,
        'tipoChecada': 'Entrada',
        'metodoUsado': metodoUsado,
        'esOffline': false,
        'fotoBase64': fotoBase64,
        'pin': pin,
        'latitud': latitud,
        'longitud': longitud,
      }),
    );

    var response = await postChecada(tokenPuntoLectura);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    // Retry en 401
    if (response.statusCode == 401) {
      try {
        final deviceId = await StorageService.leerDeviceId();
        if (deviceId != null) {
          final rec = await recuperarToken(deviceId: deviceId);
          final tokenNuevo = rec['tokenPuntoLectura'] as String?;
          if (tokenNuevo != null && tokenNuevo.isNotEmpty) {
            await StorageService.guardarToken(tokenNuevo);
            await Future.delayed(const Duration(milliseconds: 500));
            response = await postChecada(tokenNuevo);
            if (response.statusCode == 200) {
              return jsonDecode(response.body);
            }
          }
        }
      } catch (e) {
        print('❌ Error en retry: $e');
      }
    }

    final error = jsonDecode(response.body);
    throw Exception(error['mensaje'] ?? 'Error al registrar checada');
  }

  // =====================================================
  // 5. Historial de checadas (JWT del empleado, si aplica)
  // =====================================================
  static Future<List<dynamic>> obtenerHistorial({
    required String numeroEmpleado,
    required String tokenPuntoLectura,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/checada/historial/$numeroEmpleado?tokenKiosko=$tokenPuntoLectura'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['registros'] as List<dynamic>? ?? [];
      }
      throw Exception('Error al obtener historial');
    } catch (e) {
      throw Exception('Error al obtener historial: $e');
    }
  }

  // =====================================================
  // 6. Registrar checada como EMPLEADO (sin kiosko)
  //    Endpoint: POST /api/Checada/empleado
  // =====================================================
  static Future<Map<String, dynamic>> registrarChecadaEmpleado({
    required String numeroEmpleado,
    required String pin,
    required String metodoUsado,
    String? fotoBase64,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/checada/empleado'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'numeroEmpleado': numeroEmpleado,
          'pin': pin,
          'tipoChecada': 'Entrada',
          'metodoUsado': metodoUsado,
          'esOffline': false,
          'fotoBase64': fotoBase64,
          'latitud': latitud,
          'longitud': longitud,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception(
          'El servidor tardó demasiado en responder. Verifica tu conexión e intenta de nuevo.'
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      // Manejar errores específicos del backend
      String mensajeError;
      try {
        final error = jsonDecode(response.body);
        mensajeError = error['mensaje'] ?? 'Error al registrar checada (${response.statusCode})';
      } catch (_) {
        mensajeError = 'Error al registrar checada (${response.statusCode}): ${response.body}';
      }
      throw Exception(mensajeError);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
