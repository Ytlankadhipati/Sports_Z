import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/providers.dart';
import 'package:sports_z/features/coach_links/data/models/coach_link_item.dart';
import 'package:sports_z/features/coach_links/data/repositories/coach_links_repository.dart';

final coachLinksRepositoryProvider = Provider<CoachLinksRepository>(
  (ref) => CoachLinksRepository(ref.watch(dioProvider)),
);

/// Every link the current user is part of (requested, active, declined, ended).
final coachLinksProvider = FutureProvider.autoDispose<List<CoachLinkItem>>(
  (ref) => ref.watch(coachLinksRepositoryProvider).list(),
);
