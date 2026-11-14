import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/providers.dart';
import 'package:sports_z/features/privacy_access/data/models/access_grant_item.dart';
import 'package:sports_z/features/privacy_access/data/models/privacy_models.dart';
import 'package:sports_z/features/privacy_access/data/repositories/privacy_access_repository.dart';

final privacyAccessRepositoryProvider = Provider<PrivacyAccessRepository>(
  (ref) => PrivacyAccessRepository(ref.watch(dioProvider)),
);

/// 'owner' = grants over MY data, 'grantee' = access others gave me.
final accessGrantsProvider = FutureProvider.autoDispose
    .family<List<AccessGrantItem>, String>(
      (ref, role) =>
          ref.watch(privacyAccessRepositoryProvider).grants(role: role),
    );

final privacySchemaProvider = FutureProvider.autoDispose<PrivacySchema>(
  (ref) => ref.watch(privacyAccessRepositoryProvider).schema(),
);

final privacySettingsProvider =
    FutureProvider.autoDispose<PrivacySettingsValue>(
      (ref) => ref.watch(privacyAccessRepositoryProvider).mySettings(),
    );

final profilePreviewProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, audience) =>
          ref.watch(privacyAccessRepositoryProvider).previewAs(audience),
    );
