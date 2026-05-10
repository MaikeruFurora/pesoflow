import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/wallet.dart';
import '../services/wallet_asset_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/money_input.dart';

const _emojiChoices = [
  '💳', '🏦', '💵', '💰', '📱', '💎',
  '🪙', '🛟', '📊', '💸', '🐷', '🏧',
];

const _colorChoices = [
  0xFF2BB3A4, 0xFF4F8DF7, 0xFFF7B84F, 0xFFEF6F6C,
  0xFF8B5CF6, 0xFF52C28F, 0xFFFF7AB3, 0xFF3B4252,
];

Future<void> showWalletEditSheet(
  BuildContext context, {
  Wallet? wallet,
  bool asVault = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _WalletEditSheet(wallet: wallet, asVault: asVault),
  );
}

class _WalletEditSheet extends StatefulWidget {
  const _WalletEditSheet({this.wallet, this.asVault = false});
  final Wallet? wallet;
  final bool asVault;
  @override
  State<_WalletEditSheet> createState() => _WalletEditSheetState();
}

class _WalletEditSheetState extends State<_WalletEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _opening;
  late final TextEditingController _notes;
  late final TextEditingController _account;
  late String _emoji;
  late int _color;
  /// 0 = use a darker shade of [_color] (single-color mode).
  late int _color2;
  late WalletCategory _category;

  /// Persisted-on-disk QR filename — what's saved or being kept on save.
  late String _qrFileName;

  /// Newly-picked file in this session, awaiting save.
  File? _stagedQrFile;

  /// Resolved on-disk path of the existing QR (loaded async).
  String? _existingQrPath;

  bool _busy = false;

  /// For new wallets we pre-generate an id so the QR file can be written
  /// before the wallet record exists.
  late final String _walletId;

  final _picker = ImagePicker();
  final _assets = WalletAssetService();

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _name = TextEditingController(text: w?.name ?? '');
    _opening = TextEditingController(
      text: formatAmountForField(w?.openingBalance),
    );
    _notes = TextEditingController(text: w?.notes ?? '');
    _account = TextEditingController(text: w?.accountNumber ?? '');
    _emoji = w?.emoji ?? '💳';
    _color = w?.colorValue ?? _colorChoices.first;
    _color2 = w?.colorValue2 ?? 0;
    _category = w?.category ?? WalletCategory.bank;
    _qrFileName = w?.qrFileName ?? '';
    _walletId = w?.id ?? const Uuid().v4();
    _resolveExistingQr();
  }

  Future<void> _resolveExistingQr() async {
    if (_qrFileName.isEmpty) return;
    final p = await _assets.qrPath(_walletId, _qrFileName);
    if (mounted) setState(() => _existingQrPath = p);
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _notes.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _pickQr() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _showError('Could not read that image. Try another file.');
        return;
      }
      // Auto-crop to a centered square — QR codes are square by nature so
      // this gets a clean result without a separate cropping UI.
      final side =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final dx = (decoded.width - side) ~/ 2;
      final dy = (decoded.height - side) ~/ 2;
      final cropped = img.copyCrop(
        decoded,
        x: dx,
        y: dy,
        width: side,
        height: side,
      );
      // Cap at 1024px to keep file sizes reasonable
      final resized = side > 1024
          ? img.copyResize(cropped, width: 1024, height: 1024)
          : cropped;
      final jpgBytes = img.encodeJpg(resized, quality: 90);

      // Stage by writing to a temp file so the existing preview UI works.
      final tmp = await File(picked.path)
          .copy('${picked.path}.cropped.jpg');
      await tmp.writeAsBytes(jpgBytes, flush: true);
      if (!mounted) return;
      setState(() => _stagedQrFile = tmp);
    } catch (e) {
      _showError('Couldn\'t process image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _removeQr() {
    setState(() {
      _stagedQrFile = null;
      _qrFileName = '';
      _existingQrPath = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final state = context.read<AppState>();
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final opening =
        double.tryParse(_opening.text.trim().replaceAll(',', '')) ?? 0;
    final account = _account.text.trim();

    setState(() => _busy = true);

    var finalQrFileName = _qrFileName;
    if (_stagedQrFile != null) {
      finalQrFileName = await _assets.saveQr(
        walletId: _walletId,
        source: _stagedQrFile!,
      );
    } else if (_qrFileName.isEmpty &&
        (widget.wallet?.qrFileName.isNotEmpty ?? false)) {
      // User removed the existing QR
      await _assets.deleteForWallet(_walletId);
    }

    if (widget.wallet == null) {
      await state.addWallet(
        id: _walletId,
        name: name,
        category: _category,
        emoji: _emoji,
        colorValue: _color,
        colorValue2: _color2,
        openingBalance: opening,
        notes: _notes.text.trim(),
        isVault: widget.asVault,
        accountNumber: account,
        qrFileName: finalQrFileName,
      );
    } else {
      final w = widget.wallet!
        ..name = name
        ..emoji = _emoji
        ..colorValue = _color
        ..colorValue2 = _color2
        ..category = _category
        ..openingBalance = opening
        ..notes = _notes.text.trim()
        ..accountNumber = account
        ..qrFileName = finalQrFileName;
      await state.updateWallet(w);
    }
    if (mounted) {
      setState(() => _busy = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.wallet != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Edit wallet' : 'New wallet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text('Icon',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiChoices.map((e) {
                final selected = _emoji == e;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? Color(_color).withOpacity(0.9)
                          : Color(_color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(e,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Primary color',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorChoices.map((c) {
                final selected = _color == c;
                return _ColorDot(
                  color: Color(c),
                  selected: selected,
                  onTap: () => setState(() => _color = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Second color',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(_color).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _color2 == 0 ? 'Solid' : 'Gradient',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(_color),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // "None" → use a darker shade of primary
                GestureDetector(
                  onTap: () => setState(() => _color2 = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color2 == 0
                            ? Color(_color)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.block_rounded,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.45),
                      ),
                    ),
                  ),
                ),
                ..._colorChoices.where((c) => c != _color).map((c) {
                  final selected = _color2 == c;
                  return _ColorDot(
                    color: Color(c),
                    selected: selected,
                    onTap: () => setState(() => _color2 = c),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),
            // Live gradient preview
            Container(
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(_color),
                    _color2 == 0
                        ? Color(_color).withOpacity(0.7)
                        : Color(_color2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(_color).withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Wallet name',
                hintText: 'e.g. BDO Checking',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WalletCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: WalletCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _opening,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: isEdit
                    ? 'Opening balance'
                    : 'Current balance (opening)',
                prefixText: '₱ ',
                helperText: isEdit
                    ? 'Adjust only if you mistyped at setup. Use transactions otherwise.'
                    : 'How much is in this wallet right now?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _account,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Account number / mobile (optional)',
                hintText: 'e.g. 0917-123-4567',
                prefixIcon: Icon(Icons.tag_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            _QrSection(
              walletColor: Color(_color),
              stagedFile: _stagedQrFile,
              existingPath: _existingQrPath,
              hasQr:
                  _stagedQrFile != null || (_existingQrPath?.isNotEmpty ?? false),
              onPick: _pickQr,
              onRemove: _removeQr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(_color),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? 'Save changes' : 'Create wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }
}

class _QrSection extends StatelessWidget {
  const _QrSection({
    required this.walletColor,
    required this.stagedFile,
    required this.existingPath,
    required this.hasQr,
    required this.onPick,
    required this.onRemove,
  });

  final Color walletColor;
  final File? stagedFile;
  final String? existingPath;
  final bool hasQr;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final showFile = stagedFile ??
        (existingPath != null ? File(existingPath!) : null);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: walletColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: walletColor.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_rounded, color: walletColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'QR code (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (hasQr)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onPick,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: walletColor.withOpacity(0.40),
                      width: 1.5,
                    ),
                  ),
                  child: showFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(
                            showFile,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        )
                      : Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 28,
                          color: walletColor,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasQr
                          ? (stagedFile != null
                              ? 'New QR ready to save'
                              : 'QR attached')
                          : 'Add your wallet QR',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a saved QR — PesoFlow auto-crops to a clean square so it scans well later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.65),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onPick,
                      icon: Icon(
                        hasQr ? Icons.swap_horiz_rounded : Icons.add,
                        size: 16,
                      ),
                      label: Text(hasQr ? 'Replace' : 'Pick image'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: walletColor,
                        side: BorderSide(color: walletColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
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
