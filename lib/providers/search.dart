import 'package:paperfold/dao/search_repository.dart';
import 'package:paperfold/models/search_result_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return const SearchRepository();
});

final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final searchResultProvider =
    FutureProvider.autoDispose<SearchResultData>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final repository = ref.watch(searchRepositoryProvider);
  final trimmed = query.trim();

  if (trimmed.isEmpty) {
    return SearchResultData.empty;
  }

  return repository.search(trimmed);
});
