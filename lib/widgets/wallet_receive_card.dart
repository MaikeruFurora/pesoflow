import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wallet.dart';
import '../services/wallet_asset_service.dart';

/// Card shown on the wallet detail screen displaying the wallet's QR (if
/// any) and account number (if any). Tapping the QR opens a fullscreen
/// viewer; tapping the account number copies it to the clipboard.
class WalletReceiveCard extends StatefulWidget {
  const WalletReceiveCard({super.key, required this.wallet});
  final Wallet wallet;

  @override
  State<WalletReceiveCard> createState() => _WalletReceiveCardState();
}

class _WalletReceiveCardState extends State<WalletReceiveCard> {
  String? _qrPath;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(WalletReceiveCard old) {
    super.didUpdateWidget(old);
    if (old.wallet.qrFileName != widget.wallet.qrFileName ||
        old.wallet.id != widget.wallet.id) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (widget.wallet.qrFileName.isEmpty) {
      setState(() => _qrPath = null);
      return;
    }
    final p = await WalletAssetService()
        .qrPath(widget.wallet.id, widget.wallet.qrFileName);
    if (mounted) setState(() => _qrPath = p);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    final hasQr = _qrPath != null;
    final hasAccount = w.accountNumber.isNotEmpty;
    if (!hasQr && !hasAccount) return const SizedBox.shrink();

    final color = Color(w.colorValue);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                'Receive money',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasQr)
                _QrThumbnail(
                  path: _qrPath!,
                  walletName: w.name,
                  walletEmoji: w.emoji,
                  accountNumber: w.accountNumber,
                  accentColor: color,
                ),
              if (hasQr) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account / mobile',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasAccount)
                      _CopyableAccount(
                        value: w.accountNumber,
                        accentColor: color,
                      )
                    else
                      Text(
                        '— not set',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.45),
                          fontSize: 14,
                        ),
                      ),
                    if (hasQr) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Tap the QR to show fullscreen for scanning.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrThumbnail extends StatelessWidget {
  const _QrThumbnail({
    required this.path,
    required this.walletName,
    required this.walletEmoji,
    required this.accountNumber,
    required this.accentColor,
  });
  final String path;
  final String walletName;
  final String walletEmoji;
  final String accountNumber;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'qr-$path',
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black87,
            transitionDuration: const Duration(milliseconds: 220),
            pageBuilder: (_, a, __) => _QrFullscreenViewer(
              path: path,
              walletName: walletName,
              walletEmoji: walletEmoji,
              accountNumber: accountNumber,
              accentColor: accentColor,
            ),
          ));
        },
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withOpacity(0.30),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyableAccount extends StatelessWidget {
  const _CopyableAccount({required this.value, required this.accentColor});
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied "$value"'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 16, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrFullscreenViewer extends StatelessWidget {
  const _QrFullscreenViewer({
    required this.path,
    required this.walletName,
    required this.walletEmoji,
    required this.accountNumber,
    required this.accentColor,
  });
  final String path;
  final String walletName;
  final String walletEmoji;
  final String accountNumber;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final qrSize = size.width * 0.86;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$walletEmoji  $walletName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (accountNumber.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      accountNumber,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Hero(
                    tag: 'qr-$path',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(path),
                          width: qrSize,
                          height: qrSize,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.brightness_high_rounded,
                            color: Colors.white.withOpacity(0.75),
                            size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Turn brightness up to scan faster',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white.withOpacity(0.15),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close_rounded,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
