import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/features/search/data/search_api.dart';
import 'package:omninest/features/search/domain/search_result.dart';

final searchApiProvider = Provider<SearchApi>((ref) {
  return SearchApi(ref.watch(apiClientProvider));
});

final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String value) => state = value;

  void clear() => state = '';
}

final searchResultsProvider = AsyncNotifierProvider.autoDispose<
  SearchResultsNotifier,
  List<SearchResult>
>(SearchResultsNotifier.new);

class SearchResultsNotifier extends AsyncNotifier<List<SearchResult>> {
  @override
  Future<List<SearchResult>> build() async {
    final query = ref.watch(searchQueryProvider);
    if (query.trim().isEmpty) return [];
    final api = ref.read(searchApiProvider);
    return api.search(query.trim());
  }

  Future<void> search(String query) async {
    ref.read(searchQueryProvider.notifier).updateQuery(query);
    ref.invalidateSelf();
  }
}
