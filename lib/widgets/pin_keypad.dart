import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    this.onBiometric,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        ...keys.map((k) => _KeyButton(label: k, onTap: () {
              HapticFeedback.lightImpact();
              onKey(k);
            })),
        _IconKeyButton(
          icon: Icons.fingerprint,
          onTap: onBiometric,
          enabled: onBiometric != null,
        ),
        _KeyButton(label: '0', onTap: () {
          HapticFeedback.lightImpact();
          onKey('0');
        }),
        _IconKeyButton(
          icon: Icons.backspace_outlined,
          onTap: () {
            HapticFeedback.lightImpact();
            onBackspace();
          },
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconKeyButton extends StatelessWidget {
  const _IconKeyButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              size: 26,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.length,
    required this.maxLength,
    this.error = false,
  });

  final int length;
  final int maxLength;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (i) {
        final filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (error ? AppColors.danger : AppColors.primary)
                : Colors.transparent,
            border: Border.all(
              color: error
                  ? AppColors.danger
                  : (filled
                      ? AppColors.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.25)),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}
