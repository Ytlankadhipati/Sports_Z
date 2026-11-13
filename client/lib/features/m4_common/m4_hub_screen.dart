import 'package:flutter/material.dart';
import 'package:sports_z/features/coach_links/presentation/screens/coach_links_screen.dart';
import 'package:sports_z/features/connections/presentation/screens/connections_screen.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/messages/presentation/screens/conversations_screen.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/access_grants_screen.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/blocked_users_screen.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/privacy_center_screen.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/view_as_screen.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// Single entry point to every M4 screen. Push it from anywhere:
///   Navigator.of(context).push(MaterialPageRoute(builder: (_) => const M4HubScreen()));
/// Until the Home / Account screens link to the individual screens, this is
/// how testers reach them.
class M4HubScreen extends StatelessWidget {
  const M4HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String code, Widget screen) {
      return M4Card(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Text(code, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return M4Page(
      title: 'Network & privacy',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          item(Icons.chat_bubble_outline, 'Messages', 'M01–M05', const ConversationsScreen()),
          item(Icons.people_outline, 'Connections', 'C01–C02', const ConnectionsScreen()),
          item(Icons.sports, 'Coach links', 'L01–L02', const CoachLinksScreen()),
          item(Icons.lock_outline, 'Privacy', 'PR01', const PrivacyCenterScreen()),
          item(Icons.key_outlined, 'Access grants', 'PR06–07', const AccessGrantsScreen()),
          item(Icons.visibility_outlined, 'View as', 'PR08', const ViewAsScreen()),
          item(Icons.block, 'Blocked users', 'PR09', const BlockedUsersScreen()),
        ],
      ),
    );
  }
}
