import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Bildirim servisini başlat
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Bildirime tıklandığında yapılacak işlemler
    print('Bildirime tıklandı: ${response.payload}');
  }

  // İzin iste
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // Başarılı giriş bildirimi
  static Future<void> showSuccessNotification({
    required String title,
    required String body,
    String? accessType,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'security_success',
      'Güvenlik Başarılı',
      channelDescription: 'Başarılı güvenlik işlemleri bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.green,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: 'success_$accessType',
    );
  }

  // Hata bildirimi
  static Future<void> showErrorNotification({
    required String title,
    required String body,
    String? errorType,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'security_error',
      'Güvenlik Hatası',
      channelDescription: 'Güvenlik hatası bildirimleri',
      importance: Importance.max,
      priority: Priority.max,
      color: Colors.red,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: 'error_$errorType',
    );
  }

  // Uyarı bildirimi
  static Future<void> showWarningNotification({
    required String title,
    required String body,
    String? warningType,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'security_warning',
      'Güvenlik Uyarısı',
      channelDescription: 'Güvenlik uyarı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.orange,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: 'warning_$warningType',
    );
  }

  // Bilgi bildirimi
  static Future<void> showInfoNotification({
    required String title,
    required String body,
    String? infoType,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'security_info',
      'Güvenlik Bilgisi',
      channelDescription: 'Güvenlik bilgi bildirimleri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Colors.blue,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: 'info_$infoType',
    );
  }

  // Kapı açıldı bildirimi
  static Future<void> showDoorOpenedNotification() async {
    await showSuccessNotification(
      title: '🔓 Kapı Açıldı',
      body: 'Ev güvenlik sistemi kapıyı açtı',
      accessType: 'door_opened',
    );
  }

  // Yanlış PIN bildirimi
  static Future<void> showWrongPinNotification() async {
    await showErrorNotification(
      title: '⚠️ Yanlış PIN',
      body: 'Girilen PIN kodu hatalı!',
      errorType: 'wrong_pin',
    );
  }

  // Bilinmeyen kart bildirimi
  static Future<void> showUnknownCardNotification(String cardId) async {
    await showErrorNotification(
      title: '❌ Bilinmeyen Kart',
      body: 'Tanınmayan RFID kart: $cardId',
      errorType: 'unknown_card',
    );
  }

  // Bağlantı hatası bildirimi
  static Future<void> showConnectionErrorNotification() async {
    await showErrorNotification(
      title: '📶 Bağlantı Hatası',
      body: 'ESP32 cihazına bağlanılamıyor',
      errorType: 'connection_error',
    );
  }

  // NFC hatası bildirimi
  static Future<void> showNFCErrorNotification(String error) async {
    await showErrorNotification(
      title: '📱 NFC Hatası',
      body: error,
      errorType: 'nfc_error',
    );
  }

  // Kart eklendi bildirimi
  static Future<void> showCardAddedNotification(String cardName) async {
    await showSuccessNotification(
      title: '✅ Kart Eklendi',
      body: '$cardName kartı başarıyla eklendi',
      accessType: 'card_added',
    );
  }

  // PIN değiştirildi bildirimi
  static Future<void> showPinChangedNotification() async {
    await showSuccessNotification(
      title: '🔐 PIN Değiştirildi',
      body: 'Güvenlik PIN\'iniz başarıyla değiştirildi',
      accessType: 'pin_changed',
    );
  }

  // Yetkisiz giriş alarm bildirimi
  static Future<void> showUnauthorizedAccessNotification() async {
    await showErrorNotification(
      title: '🚨 ALARM: Yetkisiz Giriş!',
      body: 'Ev girişinde yetkisiz erişim algılandı! Derhal kontrol edin!',
      errorType: 'unauthorized_access',
    );
  }

  // Hareket algılandı bildirimi
  static Future<void> showMotionDetectedNotification() async {
    await showWarningNotification(
      title: '👁️ Hareket Algılandı',
      body: 'Ev girişinde hareket algılandı. Kimlik doğrulaması bekleniyor.',
      warningType: 'motion_detected',
    );
  }

  // Kart silindi bildirimi
  static Future<void> showCardDeletedNotification(String cardName) async {
    await showInfoNotification(
      title: '🗑️ Kart Silindi',
      body: '$cardName kartı başarıyla silindi',
      infoType: 'card_deleted',
    );
  }

  // Tüm bildirimleri temizle
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Belirli bir bildirimi iptal et
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
