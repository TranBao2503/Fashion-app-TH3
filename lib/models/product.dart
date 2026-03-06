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
      price: _readPrice(map['price']),
      quantity: _readQuantity(map['quantity']),
      imageUrl: _normalizeImageUrl(rawImage),
    );
  }

  static double _readPrice(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    final raw = value.toString().trim().toLowerCase();
    if (raw.isEmpty) {
      return 0;
    }

    var normalized = raw
        .replaceAll('vnd', '')
        .replaceAll('vnđ', '')
        .replaceAll('đ', '')
        .replaceAll(' ', '');

    // Keep only digits and separators, then normalize decimal separator.
    normalized = normalized.replaceAll(RegExp(r'[^0-9,\.]'), '');

    if (normalized.contains(',') && normalized.contains('.')) {
      // Common vi-VN currency format like 700.000,50 => 700000.50
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',') && !normalized.contains('.')) {
      normalized = normalized.replaceAll(',', '.');
    } else {
      // Treat dots as thousand separators if there are multiple dots.
      final dotCount = '.'.allMatches(normalized).length;
      if (dotCount > 1) {
        normalized = normalized.replaceAll('.', '');
      }
    }

    return double.tryParse(normalized) ?? 0;
  }

  static int _readQuantity(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    final normalized = value.toString().replaceAll(RegExp(r'[^0-9\-]'), '');
    return int.tryParse(normalized) ?? 0;
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    final normalizedKeys = keys.map((key) => key.trim().toLowerCase()).toSet();

    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    for (final entry in map.entries) {
      final entryKey = entry.key.toString().trim().toLowerCase();
      if (!normalizedKeys.contains(entryKey)) {
        continue;
      }

      final value = entry.value;
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

    normalized = normalized.replaceAll('\\u0026', '&');

    if (normalized.contains('images.unsplash.com/') &&
        !normalized.contains('?')) {
      normalized = '$normalized?auto=format&fit=crop&w=1200&q=80';
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    return '';
  }
}
