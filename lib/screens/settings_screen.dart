import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/esp32_service.dart';
import '../services/nfc_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../widgets/security_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ESP32Service _esp32Service = ESP32Service();
  bool _isLoading = false;
  List<Map<String, dynamic>> _cardList = [];

  @override
  void initState() {
    super.initState();
    _loadCardList();
  }

  Future<void> _loadCardList() async {
    try {
      final response = await _esp32Service.getCardList();
      if (response['success'] == true) {
        setState(() {
          _cardList = List<Map<String, dynamic>>.from(response['cards'] ?? []);
        });
      }
    } catch (e) {
      print('Kart listesi yüklenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // NFC Kart Yönetimi
          _buildSectionHeader('NFC Kart Yönetimi'),
          SecurityCard(
            title: 'Yeni Kart Ekle',
            subtitle: 'NFC ile yeni kart kaydet',
            color: AppTheme.primaryColor,
            icon: Icons.add_card,
            onTap: _showAddCardDialog,
          ),

          SecurityCard(
            title: 'Kart Listesi',
            subtitle: 'Kayıtlı kartları görüntüle (${_cardList.length} kart)',
            color: AppTheme.secondaryColor,
            icon: Icons.list,
            onTap: _showCardListDialog,
          ),

          const SizedBox(height: 24),

          // Güvenlik Ayarları
          _buildSectionHeader('Güvenlik Ayarları'),
          SecurityCard(
            title: 'PIN Değiştir',
            subtitle: 'Güvenlik PIN kodunu güncelle',
            color: AppTheme.warningColor,
            icon: Icons.lock_reset,
            onTap: _showChangePinDialog,
          ),

          const SizedBox(height: 24),

          // Sistem Ayarları
          _buildSectionHeader('Sistem Ayarları'),
          SecurityCard(
            title: 'ESP32 Bağlantısı',
            subtitle: 'IP adresi: ${_esp32Service.ipAddress}',
            color: AppTheme.primaryColor,
            icon: Icons.router,
            onTap: _showNetworkSettingsDialog,
          ),

          SecurityCard(
            title: 'NFC Testi',
            subtitle: 'NFC özelliğini test et',
            color: NFCService.isAvailable
                ? AppTheme.successColor
                : AppTheme.errorColor,
            icon: Icons.nfc,
            onTap: NFCService.isAvailable ? _showNFCTestDialog : null,
          ),

          const SizedBox(height: 24),

          // Uygulama Ayarları
          _buildSectionHeader('Uygulama'),
          SecurityCard(
            title: 'Kartları Yenile',
            subtitle: 'Kart listesini yeniden yükle',
            color: AppTheme.primaryColor,
            icon: Icons.refresh,
            onTap: _loadCardList,
          ),

          SecurityCard(
            title: 'Bildirimleri Temizle',
            subtitle: 'Tüm bildirimleri sil',
            color: AppTheme.secondaryColor,
            icon: Icons.clear_all,
            onTap: _clearNotifications,
          ),

          SecurityCard(
            title: 'Hakkında',
            subtitle: 'Uygulama bilgileri',
            color: AppTheme.primaryColor,
            icon: Icons.info,
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: AppTheme.subtitleStyle.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAddCardDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddCardDialog(
        esp32Service: _esp32Service,
        onCardAdded: () {
          _loadCardList();
          setState(() {});
        },
      ),
    );
  }

  void _showCardListDialog() {
    showDialog(
      context: context,
      builder: (context) => _CardListDialog(
        cardList: _cardList,
        onRefresh: _loadCardList,
        esp32Service: _esp32Service,
      ),
    );
  }

  void _showChangePinDialog() {
    showDialog(
      context: context,
      builder: (context) => _ChangePinDialog(esp32Service: _esp32Service),
    );
  }

  void _showNetworkSettingsDialog() {
    final TextEditingController ipController = TextEditingController(
      text: _esp32Service.ipAddress,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ağ Ayarları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'ESP32 IP Adresi',
                hintText: '192.168.1.100',
                prefixIcon: Icon(Icons.router),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Text(
              'ESP32 cihazınızın yerel ağdaki IP adresini girin.',
              style: AppTheme.captionStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newIp = ipController.text.trim();
              if (newIp.isNotEmpty && _isValidIpAddress(newIp)) {
                _esp32Service.setIpAddress(newIp);
                Navigator.of(context).pop();

                // Bağlantıyı test et
                final isConnected = await _esp32Service.checkConnection();
                if (mounted) {
                  final provider =
                      Provider.of<SecurityProvider>(context, listen: false);
                  provider.setConnected(isConnected);
                  provider.setEsp32IpAddress(newIp);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isConnected
                          ? 'Bağlantı başarılı'
                          : 'Bağlantı başarısız'),
                      backgroundColor: isConnected
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Geçerli bir IP adresi girin'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showNFCTestDialog() {
    showDialog(
      context: context,
      builder: (context) => _NFCTestDialog(),
    );
  }

  void _clearNotifications() {
    NotificationService.cancelAllNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildirimler temizlendi'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Ev Güvenlik Sistemi',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.security,
        size: 64,
        color: AppTheme.primaryColor,
      ),
      children: [
        const Text(
          'ESP32 tabanlı ev güvenlik sistemi uygulaması.\n\n'
          'Özellikler:\n'
          '• NFC kart okuma ve ekleme\n'
          '• PIN ile giriş\n'
          '• WiFi üzerinden haberleşme\n'
          '• 16x2 LCD ekran desteği\n'
          '• Gerçek zamanlı bildirimler\n\n'
          'Geliştirici: AI Assistant',
        ),
      ],
    );
  }

  bool _isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }
}

// Kart listesi dialog'u
class _CardListDialog extends StatefulWidget {
  final List<Map<String, dynamic>> cardList;
  final VoidCallback onRefresh;
  final ESP32Service esp32Service;

  const _CardListDialog({
    required this.cardList,
    required this.onRefresh,
    required this.esp32Service,
  });

  @override
  State<_CardListDialog> createState() => _CardListDialogState();
}

class _CardListDialogState extends State<_CardListDialog> {
  List<Map<String, dynamic>> _cardList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cardList = List.from(widget.cardList);
  }

  Future<void> _deleteCard(String cardId, String cardName, int index) async {
    // Onay dialog'u göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Kartı Sil'),
          ],
        ),
        content: Text(
          '$cardName kartını silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.esp32Service.deleteRfidCard(cardId);

      if (response.success) {
        await NotificationService.showCardDeletedNotification(cardName);

        setState(() {
          _cardList.removeAt(index);
        });

        widget.onRefresh();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$cardName kartı başarıyla silindi'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kart silinemedi: ${response.message}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.list, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text('Kayıtlı Kartlar (${_cardList.length})'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _cardList.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz kart eklenmemiş',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _cardList.length,
                itemBuilder: (context, index) {
                  final card = _cardList[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(
                          Icons.credit_card,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(card['name'] ?? 'Bilinmeyen Kart'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sahip: ${card['owner'] ?? 'Bilinmeyen'}'),
                          Text(
                            'ID: ${card['id'] ?? 'Bilinmeyen'}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: AppTheme.errorColor,
                              ),
                              onPressed: () => _deleteCard(
                                card['id'] ?? '',
                                card['name'] ?? 'Bilinmeyen Kart',
                                index,
                              ),
                              tooltip: 'Kartı Sil',
                            ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onRefresh();
            Navigator.of(context).pop();
          },
          child: const Text('Yenile'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

// Kart ekleme dialog'u
class _AddCardDialog extends StatefulWidget {
  final ESP32Service esp32Service;
  final VoidCallback onCardAdded;

  const _AddCardDialog({
    required this.esp32Service,
    required this.onCardAdded,
  });

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  String? _cardId;
  bool _isListening = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_card, color: AppTheme.primaryColor),
          SizedBox(width: 8),
          Text('Yeni Kart Ekle'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cardId == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isListening
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isListening ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.nfc,
                    size: 48,
                    color: _isListening ? AppTheme.primaryColor : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isListening
                        ? 'NFC Kart Bekleniyor...\nKartı telefonun arkasına yaklaştırın'
                        : 'NFC Kart Okuma\nOkumaya başlamak için butona basın',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isListening ? AppTheme.primaryColor : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isListening ? _stopListening : _startListening,
                    icon: Icon(_isListening ? Icons.stop : Icons.nfc),
                    label: Text(_isListening ? 'Durdur' : 'NFC Oku'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening
                          ? AppTheme.errorColor
                          : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.successColor),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kart Başarıyla Okundu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: $_cardId',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Kart Adı',
                hintText: 'Örn: Ana Kart, Misafir Kartı',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ownerController,
              decoration: const InputDecoration(
                labelText: 'Sahip Adı',
                hintText: 'Örn: Ali Veli',
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        if (_cardId != null)
          ElevatedButton(
            onPressed: _isLoading ? null : _addCard,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kartı Ekle'),
          ),
      ],
    );
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
    });

    await NFCService.startNFCReading(
      onCardDetected: (cardId) {
        setState(() {
          _cardId = cardId;
          _isListening = false;
        });
      },
      onError: (error) {
        setState(() {
          _isListening = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('NFC Hatası: $error'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  Future<void> _stopListening() async {
    await NFCService.stopNFCReading();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _addCard() async {
    final cardName = _nameController.text.trim();
    final ownerName = _ownerController.text.trim();

    if (cardName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kart adını girin'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.esp32Service.addRfidCard(
        _cardId!,
        cardName,
        ownerName: ownerName.isNotEmpty ? ownerName : cardName,
      );

      if (response.success) {
        await NotificationService.showCardAddedNotification(cardName);
        widget.onCardAdded();

        if (mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${cardName} kartı başarıyla eklendi'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kart eklenemedi: ${response.message}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    if (_isListening) {
      NFCService.stopNFCReading();
    }
    super.dispose();
  }
}

// NFC Test dialog'u
class _NFCTestDialog extends StatefulWidget {
  @override
  State<_NFCTestDialog> createState() => _NFCTestDialogState();
}

class _NFCTestDialogState extends State<_NFCTestDialog> {
  bool _isListening = false;
  String? _lastCardId;
  String _status = 'NFC testi yapmaya hazır';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.nfc, color: AppTheme.primaryColor),
          SizedBox(width: 8),
          Text('NFC Test'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isListening
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.nfc,
                  size: 48,
                  color: _isListening ? AppTheme.primaryColor : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                ),
                if (_lastCardId != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Son okunan: $_lastCardId',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isListening ? _stopTest : _startTest,
            icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
            label: Text(_isListening ? 'Testi Durdur' : 'Testi Başlat'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isListening ? AppTheme.errorColor : AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }

  Future<void> _startTest() async {
    setState(() {
      _isListening = true;
      _status = 'NFC kart bekleniyor...';
    });

    await NFCService.startNFCReading(
      onCardDetected: (cardId) {
        setState(() {
          _lastCardId = cardId;
          _status = 'Kart başarıyla okundu!';
          _isListening = false;
        });
      },
      onError: (error) {
        setState(() {
          _status = 'Hata: $error';
          _isListening = false;
        });
      },
    );
  }

  Future<void> _stopTest() async {
    await NFCService.stopNFCReading();
    setState(() {
      _isListening = false;
      _status = 'Test durduruldu';
    });
  }

  @override
  void dispose() {
    if (_isListening) {
      NFCService.stopNFCReading();
    }
    super.dispose();
  }
}

// PIN değiştirme dialog'u
class _ChangePinDialog extends StatefulWidget {
  final ESP32Service esp32Service;

  const _ChangePinDialog({required this.esp32Service});

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final TextEditingController _oldPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_reset, color: AppTheme.warningColor),
          SizedBox(width: 8),
          Text('PIN Değiştir'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldPinController,
            decoration: const InputDecoration(
              labelText: 'Mevcut PIN',
              prefixIcon: Icon(Icons.lock),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPinController,
            decoration: const InputDecoration(
              labelText: 'Yeni PIN',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPinController,
            decoration: const InputDecoration(
              labelText: 'Yeni PIN (Tekrar)',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePin,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Değiştir'),
        ),
      ],
    );
  }

  Future<void> _changePin() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (oldPin.length != 4 || newPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN 4 haneli olmalıdır'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni PIN\'ler eşleşmiyor'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.esp32Service.changePin(oldPin, newPin);

      if (response.success) {
        await NotificationService.showPinChangedNotification();

        if (mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN başarıyla değiştirildi'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN değiştirilemedi: ${response.message}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
