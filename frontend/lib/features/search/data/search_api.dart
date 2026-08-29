import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/search/domain/search_result.dart';

class SearchApi {
  SearchApi(this._client);

  final ApiClient _client;

  Future<List<SearchResult>> search(String query, {int limit = 20}) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    final data = response.data;
    if (data == null) return [];
    final items = data['data'] as List<dynamic>? ?? [];
    return items
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
