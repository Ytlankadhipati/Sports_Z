import 'package:flutter/material.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// X01: "Log out?" confirmation dialog.
///
/// Returns true only when the user taps "Log out". Cancel, tapping outside
/// the dialog and the back button all return false.
Future<bool> showLogoutDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const LogoutDialog(),
  );
  return result == true;
}

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again to use SportsZ.'),
      actions: [
        TextButton(
          key: const Key('logout_dialog_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('logout_dialog_confirm'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Log out'),
        ),
      ],
    );
  }
}
