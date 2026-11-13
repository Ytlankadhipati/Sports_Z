import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/providers.dart';
import 'package:sports_z/features/connections/data/models/connection_item.dart';
import 'package:sports_z/features/connections/data/repositories/connections_repository.dart';

final connectionsRepositoryProvider = Provider<ConnectionsRepository>(
  (ref) => ConnectionsRepository(ref.watch(dioProvider)),
);

/// Everything except blocked (requested + accepted + declined).
final connectionsProvider = FutureProvider.autoDispose<List<ConnectionItem>>(
  (ref) => ref
      .watch(connectionsRepositoryProvider)
      .list(status: 'requested,accepted'),
);

/// PR09 Blocked users (only rows the current user blocked).
final blockedUsersProvider = FutureProvider.autoDispose<List<ConnectionItem>>((
  ref,
) async {
  final all = await ref
      .watch(connectionsRepositoryProvider)
      .list(status: 'blocked');
  return all.where((c) => c.blockedByMe).toList();
});
