import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/security_response.dart';

class ESP32Service {
  static const String defaultIpAddress = '192.168.1.9'; // ESP32 IP adresi
  static const int port = 80;
  static const Duration timeoutDuration = Duration(seconds: 5);

  String _ipAddress = defaultIpAddress;
  final http.Client _client = http.Client();

  String get ipAddress => _ipAddress;

  void setIpAddress(String ip) {
    _ipAddress = ip;
  }

  String get baseUrl => 'http://$_ipAddress:$port';

  // Bağlantı durumunu kontrol et
  Future<bool> checkConnection() async {
    try {
      final url = Uri.parse('$baseUrl/status');
      final response = await _client.get(url).timeout(timeoutDuration);

      return response.statusCode == 200;
    } on SocketException catch (e) {
      print('Ağ hatası: $e');
      return false;
    } on TimeoutException catch (e) {
      print('Zaman aşımı: $e');
      return false;
    } catch (e) {
      print('Beklenmeyen hata: $e');
      return false;
    }
  }

  // HTTP POST isteği gönderen yardımcı fonksiyon
  Future<SecurityResponse> _post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('$baseUrl/$endpoint');
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Connection': 'keep-alive',
            },
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SecurityResponse.fromJson(data);
      } else {
        print('HTTP Hata ${response.statusCode}: ${response.body}');
        return SecurityResponse(
          success: false,
          message: 'HTTP Hata ${response.statusCode}',
          timestamp: DateTime.now(),
        );
      }
    } on SocketException catch (e) {
      print('Ağ hatası: $e');
      return SecurityResponse(
        success: false,
        message: 'Ağ bağlantısı hatası',
        timestamp: DateTime.now(),
      );
    } on TimeoutException catch (e) {
      print('Zaman aşımı: $e');
      return SecurityResponse(
        success: false,
        message: 'Bağlantı zaman aşımına uğradı',
        timestamp: DateTime.now(),
      );
    } on FormatException catch (e) {
      print('JSON ayrıştırma hatası: $e');
      return SecurityResponse(
        success: false,
        message: 'Sunucu yanıtı geçersiz',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Beklenmeyen hata: $e');
      return SecurityResponse(
        success: false,
        message: 'Beklenmeyen bir hata oluştu',
        timestamp: DateTime.now(),
      );
    }
  }

  // PIN ile doğrulama
  Future<SecurityResponse> verifyPin(String pin) async {
    return _post('verify-pin', {'pin': pin});
  }

  // RFID kart doğrulama
  Future<SecurityResponse> verifyRfidCard(String cardId) async {
    return _post('verify-rfid', {'card_id': cardId});
  }

  // RFID kart ekleme
  Future<SecurityResponse> addRfidCard(String cardId, String cardName,
      {String? ownerName}) async {
    final requestBody = {
      'card_id': cardId,
      'card_name': cardName,
      'owner_name': ownerName ?? cardName,
    };
    return _post('add-rfid', requestBody);
  }

  // PIN değiştirme
  Future<SecurityResponse> changePin(String oldPin, String newPin) async {
    return _post('change-pin', {
      'old_pin': oldPin,
      'new_pin': newPin,
    });
  }

  // Kapı açma komutu
  Future<SecurityResponse> openDoor() async {
    return _post('open-door', {});
  }

  // Kart listesi getirme
  Future<Map<String, dynamic>> getCardList() async {
    try {
      final url = Uri.parse('$baseUrl/list-cards');
      final response = await _client.get(url).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('HTTP Hata ${response.statusCode}: ${response.body}');
        return {
          'success': false,
          'message': 'HTTP Hata ${response.statusCode}',
          'cards': [],
        };
      }
    } on SocketException catch (e) {
      print('Ağ hatası: $e');
      return {
        'success': false,
        'message': 'Ağ bağlantısı hatası',
        'cards': [],
      };
    } on TimeoutException catch (e) {
      print('Zaman aşımı: $e');
      return {
        'success': false,
        'message': 'Bağlantı zaman aşımına uğradı',
        'cards': [],
      };
    } on FormatException catch (e) {
      print('JSON ayrıştırma hatası: $e');
      return {
        'success': false,
        'message': 'Sunucu yanıtı geçersiz',
        'cards': [],
      };
    } catch (e) {
      print('Beklenmeyen hata: $e');
      return {
        'success': false,
        'message': 'Beklenmeyen bir hata oluştu',
        'cards': [],
      };
    }
  }

  // RFID kart silme - YENİ!
  Future<SecurityResponse> deleteRfidCard(String cardId) async {
    return _post('delete-rfid', {'card_id': cardId});
  }

  // Sistem durumu detayları getirme (yetkisiz giriş kontrolü için)
  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final url = Uri.parse('$baseUrl/status');
      final response = await _client.get(url).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('HTTP Hata ${response.statusCode}: ${response.body}');
        return {
          'status': 'error',
          'motion_detected': false,
          'unauthorized_access': false,
        };
      }
    } on SocketException catch (e) {
      print('Ağ hatası: $e');
      return {
        'status': 'error',
        'motion_detected': false,
        'unauthorized_access': false,
      };
    } on TimeoutException catch (e) {
      print('Zaman aşımı: $e');
      return {
        'status': 'error',
        'motion_detected': false,
        'unauthorized_access': false,
      };
    } on FormatException catch (e) {
      print('JSON ayrıştırma hatası: $e');
      return {
        'status': 'error',
        'motion_detected': false,
        'unauthorized_access': false,
      };
    } catch (e) {
      print('Beklenmeyen hata: $e');
      return {
        'status': 'error',
        'motion_detected': false,
        'unauthorized_access': false,
      };
    }
  }

  // Servis sonlandırma
  void dispose() {
    _client.close();
  }
}
