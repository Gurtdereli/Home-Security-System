import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'services/notification_service.dart';
import 'services/nfc_service.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bildirimleri başlat
  await NotificationService.initialize();
  
  // Mobil platformlarda özellikleri etkinleştir
  if (Platform.isAndroid || Platform.isIOS) {
    await NotificationService.requestPermissions();
    
    // NFC varlığını kontrol et
    await NFCService.checkNFCAvailability();
    
    // İzinleri iste
    await _requestPermissions();
  } else {
    print('Desktop platformda çalışıyor - mobil özellikler devre dışı');
  }

  runApp(const HomeSecurityApp());
}

Future<void> _requestPermissions() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    print('Desktop platformda izin gerektirmiyor');
    return;
  }

  try {
    // Bildirim izni
    await Permission.notification.request();

    // NFC izni - Android'de otomatik olarak sistem tarafından yönetilir
    // Ancak cihazın NFC özelliğini kontrol edebiliriz
    print('NFC izinleri kontrol ediliyor...');
  } catch (e) {
    print('İzin kontrolü hatası: $e');
  }

  // İnternet izni Android'de otomatik olarak verilir
  // Ek izin gerektirmez
}

class HomeSecurityApp extends StatelessWidget {
  const HomeSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
      ],
      child: MaterialApp(
        title: 'Ev Güvenlik Sistemi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}

// Security state management
class SecurityProvider extends ChangeNotifier {
  bool _isConnected = false;
  bool _isDoorOpen = false;
  bool _isLoading = false;
  String _lastAccessType = '';
  String _esp32IpAddress = '192.168.1.48';

  bool get isConnected => _isConnected;
  bool get isDoorOpen => _isDoorOpen;
  bool get isLoading => _isLoading;
  String get lastAccessType => _lastAccessType;
  String get esp32IpAddress => _esp32IpAddress;

  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  void setDoorOpen(bool open) {
    _isDoorOpen = open;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setLastAccessType(String accessType) {
    _lastAccessType = accessType;
    notifyListeners();
  }

  void setEsp32IpAddress(String ip) {
    _esp32IpAddress = ip;
    notifyListeners();
  }
}
