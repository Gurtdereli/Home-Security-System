import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:async';
import '../main.dart';
import '../services/esp32_service.dart';
import '../services/nfc_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../widgets/security_card.dart';
import '../widgets/pin_input_widget.dart';
import '../widgets/connection_status_widget.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ESP32Service _esp32Service = ESP32Service();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Timer? _statusTimer;

  bool _isNFCListening = false;
  String _connectionStatus = 'Bağlanıyor...';
  String _lastAccessInfo = '';
  bool _motionDetected = false;
  double _lastDistance = 0.0;
  bool _lastMotionState = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    
    // Build tamamlandıktan sonra bağlantı kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnection();
      _initializeNFC();
      _startStatusMonitoring();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkSystemStatus();
    });
  }

  Future<void> _checkSystemStatus() async {
    try {
      final status = await _esp32Service.getSystemStatus();

      bool currentMotionState = status['motion_detected'] ?? false;
      if (currentMotionState != _lastMotionState) {
        _lastMotionState = currentMotionState;
        if (currentMotionState) {
          await NotificationService.showMotionDetectedNotification();
          setState(() {
            _lastAccessInfo = 'Hareket algılandı - Kimlik doğrulaması gerekli';
          });
        }
      }

      setState(() {
        _motionDetected = currentMotionState;
        _lastDistance = (status['last_distance'] ?? 0.0).toDouble();
      });

      bool unauthorizedAccess = status['unauthorized_access'] ?? false;
      if (unauthorizedAccess) {
        await NotificationService.showUnauthorizedAccessNotification();
        setState(() {
          _lastAccessInfo = 'ALARM: Yetkisiz giriş algılandı!';
        });
      }
    } catch (e) {
      print('Sistem durumu kontrol hatası: $e');
    }
  }

  Future<void> _checkConnection() async {
    final provider = Provider.of<SecurityProvider>(context, listen: false);
    provider.setLoading(true);

    try {
      final isConnected = await _esp32Service.checkConnection();
      provider.setConnected(isConnected);
      setState(() {
        _connectionStatus = isConnected ? 'Bağlı' : 'Bağlantı Yok';
      });

      if (!isConnected) {
        await NotificationService.showConnectionErrorNotification();
      }
    } catch (e) {
      provider.setConnected(false);
      setState(() {
        _connectionStatus = 'Hata: $e';
      });
    } finally {
      provider.setLoading(false);
    }
  }

  Future<void> _initializeNFC() async {
    await NFCService.checkNFCAvailability();
  }

  Future<void> _startNFCReading() async {
    if (_isNFCListening) return;

    setState(() {
      _isNFCListening = true;
    });

    await NFCService.startNFCReading(
      onCardDetected: (cardId) async {
        setState(() {
          _isNFCListening = false;
          _lastAccessInfo = 'NFC Kart: $cardId';
        });

        final provider = Provider.of<SecurityProvider>(context, listen: false);
        provider.setLoading(true);

        try {
          final response = await _esp32Service.verifyRfidCard(cardId);

          if (response.success) {
            provider.setDoorOpen(true);
            provider.setLastAccessType('NFC');
            await NotificationService.showDoorOpenedNotification();

            await _esp32Service.openDoor();

            Future.delayed(const Duration(seconds: 3), () {
              provider.setDoorOpen(false);
            });
          } else {
            await NotificationService.showUnknownCardNotification(cardId);
          }
        } catch (e) {
          await NotificationService.showNFCErrorNotification(e.toString());
        } finally {
          provider.setLoading(false);
        }
      },
      onError: (error) async {
        setState(() {
          _isNFCListening = false;
        });
        await NotificationService.showNFCErrorNotification(error);
      },
    );
  }

  Future<void> _verifyPin(String pin) async {
    final provider = Provider.of<SecurityProvider>(context, listen: false);
    provider.setLoading(true);

    try {
      final response = await _esp32Service.verifyPin(pin);

      if (response.success) {
        provider.setDoorOpen(true);
        provider.setLastAccessType('PIN');
        setState(() {
          _lastAccessInfo = 'PIN Girişi Başarılı';
        });

        await NotificationService.showDoorOpenedNotification();

        await _esp32Service.openDoor();

        Future.delayed(const Duration(seconds: 3), () {
          provider.setDoorOpen(false);
        });
      } else {
        await NotificationService.showWrongPinNotification();
        setState(() {
          _lastAccessInfo = 'Yanlış PIN!';
        });
      }
    } catch (e) {
      await NotificationService.showConnectionErrorNotification();
      setState(() {
        _lastAccessInfo = 'Bağlantı Hatası';
      });
    } finally {
      provider.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 28),
            const SizedBox(width: 8),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Ev Güvenlik Sistemi',
                  textStyle: AppTheme.titleStyle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  speed: const Duration(milliseconds: 100),
                ),
              ],
              totalRepeatCount: 1,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkConnection,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimationLimiter(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                ConnectionStatusWidget(
                  status: _connectionStatus,
                  esp32Service: _esp32Service,
                  onRefresh: _checkConnection,
                ),
                const SizedBox(height: 16),
                if (_motionDetected)
                  Card(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.motion_photos_on,
                            color: AppTheme.warningColor,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '👁️ Hareket Algılandı',
                                  style: AppTheme.subtitleStyle.copyWith(
                                    color: AppTheme.warningColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Mesafe: ${_lastDistance.toStringAsFixed(1)} cm',
                                  style: AppTheme.bodyStyle.copyWith(
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                                Text(
                                  'Kimlik doğrulaması gerekli!',
                                  style: AppTheme.captionStyle.copyWith(
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_motionDetected) const SizedBox(height: 16),
                Consumer<SecurityProvider>(
                  builder: (context, provider, _) {
                    return SecurityCard(
                      title: provider.isDoorOpen
                          ? '🔓 Kapı Açık'
                          : '🔒 Kapı Kapalı',
                      subtitle: provider.isDoorOpen
                          ? 'Güvenlik sistemi devre dışı'
                          : 'Güvenlik sistemi aktif',
                      color: provider.isDoorOpen
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                      isLoading: provider.isLoading,
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_lastAccessInfo.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Son Erişim',
                            style: AppTheme.subtitleStyle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lastAccessInfo,
                            style: AppTheme.bodyStyle.copyWith(
                              color: _lastAccessInfo.contains('ALARM')
                                  ? AppTheme.errorColor
                                  : _lastAccessInfo.contains('Hareket')
                                      ? AppTheme.warningColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                            ),
                          ),
                          Text(
                            DateTime.now().toString().substring(0, 16),
                            style: AppTheme.captionStyle.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                PinInputWidget(
                  onPinSubmitted: _verifyPin,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'NFC ile Giriş',
                          style: AppTheme.subtitleStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (NFCService.isAvailable) ...[
                          ElevatedButton.icon(
                            onPressed:
                                _isNFCListening ? null : _startNFCReading,
                            icon: _isNFCListening
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.nfc),
                            label: Text(
                              _isNFCListening
                                  ? 'NFC Kart Bekleniyor...'
                                  : 'NFC Kart Okut',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isNFCListening
                                  ? AppTheme.warningColor
                                  : AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (_isNFCListening) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.warningColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.contactless,
                                    color: AppTheme.warningColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'NFC kartını telefona yaklaştırın',
                                      style: AppTheme.bodyStyle.copyWith(
                                        color: AppTheme.warningColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isNFCListening = false;
                                });
                                NFCService.stopNFCReading();
                              },
                              child: const Text('İptal'),
                            ),
                          ],
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'NFC bu cihazda desteklenmiyor',
                                    style: AppTheme.bodyStyle.copyWith(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Consumer<SecurityProvider>(
                  builder: (context, provider, _) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Manuel Kontrol',
                              style: AppTheme.subtitleStyle,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: provider.isConnected &&
                                      !provider.isLoading
                                  ? () async {
                                      provider.setLoading(true);
                                      try {
                                        final response =
                                            await _esp32Service.openDoor();
                                        if (response.success) {
                                          provider.setDoorOpen(true);
                                          await NotificationService
                                              .showDoorOpenedNotification();
                                          Future.delayed(
                                              const Duration(seconds: 3), () {
                                            provider.setDoorOpen(false);
                                          });
                                        }
                                      } finally {
                                        provider.setLoading(false);
                                      }
                                    }
                                  : null,
                              icon: provider.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.lock_open),
                              label: const Text('Kapıyı Aç'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
