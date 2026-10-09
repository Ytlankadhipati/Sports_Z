import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/sportsz_ui.dart';

Map<String, dynamic> responseData(Map<String, dynamic> data) => data;

String profileRequestError(
  Object error, {
  required bool saving,
  required String fallback,
}) {
  final apiError = apiExceptionFrom(error);
  final code = apiError?.statusCode;
  if (code != null) {
    final safe = saving
        ? safeProfileSaveError(code)
        : safeProfileLoadError(code);
    if (code == 422 && apiError != null && apiError.message.isNotEmpty) {
      return apiError.message;
    }
    if ((code >= 500 || code == 429) && apiError != null) {
      return apiError.message;
    }
    return safe;
  }
  if (apiError != null) return apiError.message;
  return fallback;
}

String safeProfileLoadError(int statusCode) => switch (statusCode) {
  401 => 'Your session has expired. Sign in again and retry.',
  403 => 'You do not have access to edit this profile.',
  404 => 'Your athlete profile could not be found.',
  _ => 'Could not load this profile section. Check your connection and retry.',
};

String safeProfileSaveError(int statusCode) => switch (statusCode) {
  401 => 'Your session has expired. Sign in again and retry.',
  403 => 'You do not have permission to update this profile.',
  404 => 'The requested profile item could not be found.',
  422 => 'Some details are invalid. Review the form and try again.',
  _ => 'Could not save your changes. Please try again.',
};

InputDecoration profileInputDecoration(
  String label, {
  IconData? icon,
  String? hint,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  prefixIcon: icon == null ? null : Icon(icon, color: AppColors.textMuted),
  filled: true,
  fillColor: AppColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.error),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.error, width: 1.5),
  ),
);

class ProfileLoadingState extends StatelessWidget {
  const ProfileLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.gold),
        SizedBox(height: 16),
        Text('Loading your profile…', style: AppTypography.bodyMedium),
      ],
    ),
  );
}

class ProfileErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ProfileErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 170,
            child: GoldButton(label: 'Retry', onPressed: onRetry),
          ),
        ],
      ),
    ),
  );
}

class ProfileSaveBar extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback? onPressed;
  final String? errorMessage;

  const ProfileSaveBar({
    super.key,
    this.label = 'Save changes',
    required this.saving,
    required this.onPressed,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null) ...[
            ProfileErrorBanner(message: errorMessage!),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: label,
              icon: Icons.check,
              loading: saving,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    ),
  );
}

class ProfileErrorBanner extends StatelessWidget {
  final String message;

  const ProfileErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
