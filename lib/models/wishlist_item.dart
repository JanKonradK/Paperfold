class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.title,
    required this.author,
  });

  final int id;
  final String title;
  final String author;

  factory WishlistItem.fromDb(Map<String, dynamic> row) {
    return WishlistItem(
      id: row['id'] as int,
      title: row['title'] as String? ?? '',
      author: row['author'] as String? ?? '',
    );
  }
}
