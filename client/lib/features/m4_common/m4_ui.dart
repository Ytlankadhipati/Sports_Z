import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/m4_common/counterpart.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

const m4Bottom = Color(0xFF120D02);

/// Shared dark page shell for all M4 screens (same look as Saved).
class M4Page extends StatelessWidget {
  const M4Page({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: m4Bottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.mustard900, m4Bottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 2),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders loading / error (with retry) / data for any AsyncValue.
Widget m4Async<T>(
  AsyncValue<T> value, {
  required Widget Function(T data) data,
  required VoidCallback onRetry,
}) {
  return value.when(
    loading: () =>
        const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    error: (error, _) => M4Message(
      icon: Icons.error_outline,
      text: apiErrorText(error),
      actionLabel: 'Retry',
      onAction: onRetry,
    ),
    data: data,
  );
}

class M4Message extends StatelessWidget {
  const M4Message({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 44),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.gold),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class M4Card extends StatelessWidget {
  const M4Card({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

class M4Avatar extends StatelessWidget {
  const M4Avatar(this.who, {super.key, this.radius = 22});
  final Counterpart who;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = who.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.mustard700,
      backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty)
          ? Text(
              who.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class M4StatusChip extends StatelessWidget {
  const M4StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' || 'active' => AppColors.success,
      'requested' => AppColors.goldBright,
      'declined' || 'ended' || 'revoked' || 'blocked' => AppColors.error,
      _ => Colors.white54,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class M4Pill extends StatelessWidget {
  const M4Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.gold,
        backgroundColor: Colors.white12,
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
      ),
    );
  }
}

InputDecoration m4Input(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: const TextStyle(color: Colors.white60),
  hintStyle: const TextStyle(color: Colors.white30),
  filled: true,
  fillColor: Colors.white.withValues(alpha: 0.07),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  counterStyle: const TextStyle(color: Colors.white38),
);

ButtonStyle m4PrimaryButton() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.gold,
  foregroundColor: Colors.black,
  minimumSize: const Size.fromHeight(50),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

void m4Snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs [action]; shows [success] on completion or the API error text on failure.
Future<bool> m4Run(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) m4Snack(context, success);
    return true;
  } catch (error) {
    if (context.mounted) m4Snack(context, apiErrorText(error));
    return false;
  }
}
