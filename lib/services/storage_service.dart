import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'token_punto_lectura';
  static const _keyDeviceId = 'device_id';
  static const _keyNumeroEmpleado = 'numero_empleado';
  static const _keyNombreEmpleado = 'nombre_empleado';
  static const _keyPin = 'pin_empleado';

  static Future<void> guardarToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> leerToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> borrarToken() async {
    await _storage.delete(key: _keyToken);
  }

  static Future<void> guardarDeviceId(String deviceId) async {
    await _storage.write(key: _keyDeviceId, value: deviceId);
  }

  static Future<String?> leerDeviceId() async {
    var deviceId = await _storage.read(key: _keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      // Generar uno nuevo (UUID v4 simplificado)
      deviceId = _generarDeviceId();
      await guardarDeviceId(deviceId);
    }
    return deviceId;
  }

  static String _generarDeviceId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<void> guardarSesion({
    required String numeroEmpleado,
    required String nombre,
    required String pin,
  }) async {
    await _storage.write(key: _keyNumeroEmpleado, value: numeroEmpleado);
    await _storage.write(key: _keyNombreEmpleado, value: nombre);
    await _storage.write(key: _keyPin, value: pin);
  }

  static Future<String?> leerNumeroEmpleado() async {
    return await _storage.read(key: _keyNumeroEmpleado);
  }

  static Future<String?> leerNombreEmpleado() async {
    return await _storage.read(key: _keyNombreEmpleado);
  }

  static Future<String?> leerPin() async {
    return await _storage.read(key: _keyPin);
  }

  static Future<bool> tieneSesion() async {
    final numero = await leerNumeroEmpleado();
    return numero != null && numero.isNotEmpty;
  }

  static Future<void> cerrarSesion() async {
    await _storage.delete(key: _keyNumeroEmpleado);
    await _storage.delete(key: _keyNombreEmpleado);
    await _storage.delete(key: _keyPin);
  }

  static Future<void> borrarTodo() async {
    await _storage.deleteAll();
  }
}
