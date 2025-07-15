import 'dart:typed_data';
import 'dart:io';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class NFCService {
  static bool _isAvailable = false;
  static bool _isInitialized = false;

  static bool get isAvailable => _isAvailable;

  // NFC varlığını kontrol et
  static Future<void> checkNFCAvailability() async {
    // Desktop platformlarda NFC desteklenmiyor
    if (!Platform.isAndroid && !Platform.isIOS) {
      print('Desktop platformda NFC desteklenmiyor');
      _isAvailable = false;
      _isInitialized = true;
      return;
    }

    try {
      // İlk olarak izinleri kontrol et
      await _requestNFCPermissions();

      _isAvailable = await NfcManager.instance.isAvailable();
      _isInitialized = true;

      if (_isAvailable) {
        print('NFC destekleniyor ve kullanılabilir');
      } else {
        print('NFC desteklenmiyor veya devre dışı');
      }
    } catch (e) {
      print('NFC kontrol hatası: $e');
      _isAvailable = false;
      _isInitialized = true;
    }
  }

  // NFC izinlerini iste
  static Future<bool> _requestNFCPermissions() async {
    try {
      // Android'de NFC izni
      if (await Permission.ignoreBatteryOptimizations.isGranted) {
        // İzin zaten verilmiş
        return true;
      }

      // İzin iste (Android'de otomatik olarak sistem yönetir)
      return true;
    } catch (e) {
      print('NFC izin hatası: $e');
      return false;
    }
  }

  // NFC kart okuma başlat
  static Future<void> startNFCReading({
    required Function(String cardId) onCardDetected,
    required Function(String error) onError,
  }) async {
    if (!_isInitialized) {
      await checkNFCAvailability();
    }

    if (!_isAvailable) {
      onError('NFC desteklenmiyor veya devre dışı');
      return;
    }

    try {
      // NFC session başlat
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            // Tag ID'sini al
            String cardId = _getTagId(tag);

            if (cardId.isNotEmpty) {
              onCardDetected(cardId);
            } else {
              onError('Kart ID\'si okunamadı');
            }

            // Session'ı durdur
            await stopNFCReading();
          } catch (e) {
            onError('Kart okuma hatası: $e');
            await stopNFCReading();
          }
        },
      );
    } catch (e) {
      onError('NFC session başlatılamadı: $e');
    }
  }

  // NFC okuma durdur
  static Future<void> stopNFCReading() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      print('NFC session durdurma hatası: $e');
    }
  }

  // Tag ID'sini string formatına çevir
  static String _getTagId(NfcTag tag) {
    try {
      final identifier = tag.data['nfca']?['identifier'] ??
          tag.data['nfcb']?['identifier'] ??
          tag.data['nfcf']?['identifier'] ??
          tag.data['nfcv']?['identifier'] ??
          tag.data['isodep']?['identifier'] ??
          tag.data['mifareclassic']?['identifier'] ??
          tag.data['mifareultralight']?['identifier'];

      if (identifier != null) {
        List<int> bytes = List<int>.from(identifier);
        return bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join('')
            .toUpperCase();
      }

      return '';
    } catch (e) {
      print('Tag ID çıkarma hatası: $e');
      return '';
    }
  }

  // NFC kart yazma (gelecek için)
  static Future<bool> writeNFCTag(String data) async {
    if (!_isAvailable) {
      return false;
    }

    try {
      bool success = false;

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              return;
            }

            NdefMessage message = NdefMessage([
              NdefRecord.createText(data),
            ]);

            await ndef.write(message);
            success = true;
          } catch (e) {
            print('NFC yazma hatası: $e');
          }
        },
      );

      await stopNFCReading();
      return success;
    } catch (e) {
      print('NFC yazma session hatası: $e');
      return false;
    }
  }

  // NFC durumunu kontrol et
  static Future<Map<String, dynamic>> getNFCStatus() async {
    if (!_isInitialized) {
      await checkNFCAvailability();
    }

    return {
      'available': _isAvailable,
      'initialized': _isInitialized,
      'enabled': _isAvailable, // Android'de NFC açık/kapalı durumu
    };
  }

  // Byte array'i hex string'e çevir
  static String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  }

  // Hex string'i byte array'e çevir
  static Uint8List _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(result);
  }

  // RFID kartın formatını kontrol et
  static Future<Map<String, dynamic>> getNFCCardInfo() async {
    if (!_isAvailable) {
      return {'error': 'NFC kullanılabilir değil'};
    }

    try {
      Map<String, dynamic> cardInfo = {};

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            cardInfo['available_technologies'] = tag.data.keys.toList();

            // NDEF bilgileri
            final ndef = Ndef.from(tag);
            if (ndef != null) {
              cardInfo['ndef'] = {
                'isWritable': ndef.isWritable,
                'maxSize': ndef.maxSize,
                'cachedMessage': ndef.cachedMessage?.records.length ?? 0,
              };
            }

            // NFC-A bilgileri
            if (tag.data.containsKey('nfca')) {
              final nfcaData = tag.data['nfca'] as Map<String, dynamic>;
              cardInfo['nfca'] = {
                'identifier': _bytesToHex(nfcaData['identifier'] as Uint8List),
                'atqa': nfcaData['atqa'],
                'sak': nfcaData['sak'],
              };
            }

            await NfcManager.instance.stopSession();
          } catch (e) {
            cardInfo['error'] = 'Kart bilgileri okunamadı: $e';
            await NfcManager.instance.stopSession();
          }
        },
      );

      return cardInfo;
    } catch (e) {
      return {'error': 'NFC session hatası: $e'};
    }
  }
}
