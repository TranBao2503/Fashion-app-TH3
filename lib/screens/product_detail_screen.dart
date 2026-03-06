import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizeUrl(product.imageUrl);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.grey.shade100,
                  child: imageUrl.isEmpty
                      ? const Center(
                          child: Icon(Icons.image_not_supported, size: 48),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.image_not_supported, size: 48),
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Danh mục', value: product.category),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Giá',
              value: '${product.price.toStringAsFixed(0)} đ',
            ),
            const SizedBox(height: 6),
            _InfoRow(label: 'Số lượng còn', value: '${product.quantity}'),
          ],
        ),
      ),
    );
  }

  String _normalizeUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
