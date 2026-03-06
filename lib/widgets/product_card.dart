import 'package:flutter/material.dart';

import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryImageUrl = _normalizeUrl(product.imageUrl);
    final proxyImageUrl = _toProxyUrl(primaryImageUrl);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Colors.grey.shade100,
                        child: primaryImageUrl.isNotEmpty
                            ? _ProductImage(
                                primaryUrl: primaryImageUrl,
                                fallbackUrl: proxyImageUrl,
                              )
                            : const Icon(Icons.checkroom, size: 36),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 0,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, size: 18),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit?.call();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${product.price.toStringAsFixed(0)} đ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Còn: ${product.quantity}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return '';
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    return '';
  }

  String _toProxyUrl(String url) {
    if (url.isEmpty) {
      return '';
    }

    final withoutScheme = url.replaceFirst(RegExp(r'^https?://'), '');
    final encoded = Uri.encodeComponent(withoutScheme);
    return 'https://images.weserv.nl/?url=$encoded';
  }
}

class _ProductImage extends StatefulWidget {
  final String primaryUrl;
  final String fallbackUrl;

  const _ProductImage({required this.primaryUrl, required this.fallbackUrl});

  @override
  State<_ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<_ProductImage> {
  static const String _finalFallbackUrl =
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1000&q=80';

  late List<String> _candidates;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates();
  }

  @override
  void didUpdateWidget(covariant _ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryUrl != widget.primaryUrl) {
      _candidates = _buildCandidates();
      _activeIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) {
      return const Icon(Icons.image_not_supported, size: 36);
    }

    final activeUrl = _candidates[_activeIndex];

    return Image.network(
      activeUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (_activeIndex < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _activeIndex += 1;
              });
            }
          });
        }

        return const Icon(Icons.image_not_supported, size: 36);
      },
    );
  }

  List<String> _buildCandidates() {
    final values = <String>[
      widget.primaryUrl,
      widget.fallbackUrl,
      _finalFallbackUrl,
    ];

    final unique = <String>[];
    for (final value in values) {
      if (value.isEmpty) {
        continue;
      }
      if (!unique.contains(value)) {
        unique.add(value);
      }
    }

    return unique;
  }
}
