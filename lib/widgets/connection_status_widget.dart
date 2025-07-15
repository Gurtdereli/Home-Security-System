import 'package:flutter/material.dart';
import '../services/esp32_service.dart';
import '../utils/app_theme.dart';

class ConnectionStatusWidget extends StatefulWidget {
  final String status;
  final ESP32Service esp32Service;
  final VoidCallback onRefresh;

  const ConnectionStatusWidget({
    super.key,
    required this.status,
    required this.esp32Service,
    required this.onRefresh,
  });

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Bağlantı durumuna göre animasyonu başlat
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ConnectionStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status.contains('Bağlanıyor') || _isRefreshing) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    if (widget.status.contains('Bağlı')) {
      return AppTheme.successColor;
    } else if (widget.status.contains('Bağlanıyor')) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.errorColor;
    }
  }

  IconData _getStatusIcon() {
    if (widget.status.contains('Bağlı')) {
      return Icons.wifi;
    } else if (widget.status.contains('Bağlanıyor')) {
      return Icons.wifi_find;
    } else {
      return Icons.wifi_off;
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    _updateAnimation();

    try {
      widget.onRefresh();
      // Minimum refresh süresi
      await Future.delayed(const Duration(milliseconds: 1000));
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        _updateAnimation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESP32 Bağlantısı',
                        style: AppTheme.subtitleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.status,
                        style: AppTheme.bodyStyle.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  icon: _isRefreshing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Bağlantıyı Yenile',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // IP adresi ve port bilgisi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.router,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'IP: ${widget.esp32Service.baseUrl}',
                      style: AppTheme.captionStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showIpChangeDialog(context),
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: 'IP Adresini Değiştir',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIpChangeDialog(BuildContext context) {
    final TextEditingController ipController = TextEditingController(
      text: widget.esp32Service.ipAddress,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ESP32 IP Adresi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Adresi',
                hintText: '192.168.1.100',
                prefixIcon: Icon(Icons.router),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
            onPressed: () {
              final newIp = ipController.text.trim();
              if (newIp.isNotEmpty && _isValidIpAddress(newIp)) {
                widget.esp32Service.setIpAddress(newIp);
                Navigator.of(context).pop();
                _handleRefresh();
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
