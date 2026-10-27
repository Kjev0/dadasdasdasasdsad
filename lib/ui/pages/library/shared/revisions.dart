import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/library.dart';
import '../../../../core/util/cancel_token.dart';

/// Watches the change counter of a library [topic] so the calling provider
/// refetches when it changes. Only real changes trigger a rebuild (the
/// stream's initial loading → 0 transition does not).
int watchLibrary(Ref ref, LibraryTopic topic) =>
    ref.watch(libraryRevisionProvider(topic).select((a) => a.value ?? 0));

/// Same for source auth state / provider order changes.
int watchSources(Ref ref) => ref.watch(sourcesRevisionProvider.select((a) => a.value ?? 0));

/// A [CancelToken] canceled when the provider rebuilds or is disposed, so
/// superseded requests stop early.
CancelToken providerCancelToken(Ref ref) {
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return token;
}
