class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final int quantity;
  final String imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final rawImage = _readString(map, const [
      'imageUrl',
      'imageURL',
      'ImageUrl',
    ]);

    return Product(
      id: id,
      name: _readString(map, const ['name', 'Name']),
      category: _readString(map, const ['category', 'Category']),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      imageUrl: _normalizeImageUrl(rawImage),
    );
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return '';
  }

  static String _normalizeImageUrl(String url) {
    if (url.isEmpty) {
      return '';
    }

    var normalized = url
        .replaceAll('\\/', '/')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();

    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'")) ||
        (normalized.startsWith('`') && normalized.endsWith('`'))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    return '';
  }
}
