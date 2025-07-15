import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

class PinInputWidget extends StatefulWidget {
  final Function(String) onPinSubmitted;
  final int pinLength;

  const PinInputWidget({
    super.key,
    required this.onPinSubmitted,
    this.pinLength = 4,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isLoading = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_pin.length < widget.pinLength) {
      setState(() {
        _pin += digit;
      });

      // Haptic feedback
      HapticFeedback.selectionClick();

      // Auto submit when PIN is complete
      if (_pin.length == widget.pinLength) {
        _submitPin();
      }
    }
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
      HapticFeedback.selectionClick();
    }
  }

  void _clearPin() {
    setState(() {
      _pin = '';
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _submitPin() async {
    if (_pin.length == widget.pinLength && !_isLoading) {
      setState(() {
        _isLoading = true;
      });

      try {
        await widget.onPinSubmitted(_pin);
      } catch (e) {
        _shakeController.forward().then((_) {
          _shakeController.reset();
        });
      } finally {
        setState(() {
          _isLoading = false;
          _pin = '';
        });
      }
    }
  }

  Widget _buildPinDisplay() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shakeOffset = _shakeAnimation.value *
            10 *
            ((_shakeController.value * 4).round() % 2 == 0 ? 1 : -1);

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.pinLength, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _pin.length
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withOpacity(0.3),
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildNumberButton(String number, {bool isSpecial = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSpecial ? null : () => _addDigit(number),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSpecial
                ? Colors.transparent
                : Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: isSpecial
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            boxShadow: isSpecial
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              number,
              style: AppTheme.titleStyle.copyWith(
                color: isSpecial
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (color ?? AppTheme.primaryColor).withOpacity(0.1),
          ),
          child: Icon(
            icon,
            color: color ?? AppTheme.primaryColor,
            size: 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'PIN Girişi',
              style: AppTheme.subtitleStyle,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // PIN Display
            _buildPinDisplay(),

            const SizedBox(height: 32),

            // Loading indicator
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Doğrulanıyor...',
                style: AppTheme.bodyStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Number pad
              Column(
                children: [
                  // Row 1: 1, 2, 3
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('1'),
                      _buildNumberButton('2'),
                      _buildNumberButton('3'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 2: 4, 5, 6
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('4'),
                      _buildNumberButton('5'),
                      _buildNumberButton('6'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 3: 7, 8, 9
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('7'),
                      _buildNumberButton('8'),
                      _buildNumberButton('9'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 4: Clear, 0, Backspace
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.clear,
                        onTap: _clearPin,
                        color: AppTheme.errorColor,
                      ),
                      _buildNumberButton('0'),
                      _buildActionButton(
                        icon: Icons.backspace,
                        onTap: _removeDigit,
                      ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Submit button (if manual submission is needed)
            if (_pin.length == widget.pinLength && !_isLoading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitPin,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Giriş Yap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
