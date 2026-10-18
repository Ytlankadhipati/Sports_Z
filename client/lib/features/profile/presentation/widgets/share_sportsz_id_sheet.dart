import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// Shares [text] and, when available, the ID card picture [cardPng].
/// Replaceable in tests.
typedef ShareIdCallback = Future<void> Function(
  String text,
  Uint8List? cardPng,
);

String sportszIdShareText(String sportszId) => 'My SportsZ ID: $sportszId';

Future<void> _defaultShare(String text, Uint8List? cardPng) async {
  if (cardPng == null) {
    await SharePlus.instance.share(ShareParams(text: text));
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [
        XFile.fromData(cardPng, mimeType: 'image/png', name: 'sportsz-id.png'),
      ],
      fileNameOverrides: ['sportsz-id.png'],
    ),
  );
}

/// I02: opens the share sheet for the athlete's SportsZ ID card.
Future<void> showShareSportsZIdSheet(
  BuildContext context, {
  required String sportszId,
  Future<Uint8List?> Function()? captureCard,
  ShareIdCallback? onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (_) => ShareSportsZIdSheet(
      sportszId: sportszId,
      captureCard: captureCard,
      onShare: onShare ?? _defaultShare,
    ),
  );
}

class ShareSportsZIdSheet extends StatelessWidget {
  final String sportszId;
  final Future<Uint8List?> Function()? captureCard;
  final ShareIdCallback onShare;

  const ShareSportsZIdSheet({
    super.key,
    required this.sportszId,
    required this.onShare,
    this.captureCard,
  });

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: sportszId));
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('SportsZ ID copied')));
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    try {
      final png = await captureCard?.call();
      await onShare(sportszIdShareText(sportszId), png);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share your SportsZ ID',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.lightGold,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                sportszId,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.deepAccent,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('share_sheet_share'),
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share),
              label: const Text('Share ID card'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('share_sheet_copy'),
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy),
              label: const Text('Copy SportsZ ID'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
