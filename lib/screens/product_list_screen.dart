import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'product_detail_screen.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/product_card.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService();
  late Future<List<Product>> _productsFuture;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _internetMonitorTimer;
  bool _isSaving = false;
  int _selectedTabIndex = 0;
  bool _isOffline = false;
  bool _isCheckingInternet = false;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProductsWithInternetCheck();
    _syncInternetState();
    _internetMonitorTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _syncInternetState();
    });
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      _syncInternetState(refreshWhenOnline: true);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _internetMonitorTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (!mounted) {
      return;
    }

    _syncInternetState(refreshWhenOnline: true);

    setState(() {
      _productsFuture = _fetchProductsWithInternetCheck();
    });
  }

  Future<void> _syncInternetState({bool refreshWhenOnline = false}) async {
    if (_isCheckingInternet) {
      return;
    }

    _isCheckingInternet = true;
    final hasInternet = await _hasRealInternetAccess();
    _isCheckingInternet = false;

    if (!mounted) {
      return;
    }

    if (!hasInternet) {
      if (_isOffline) {
        return;
      }

      _isOffline = true;
      setState(() {
        _productsFuture = Future.error(
          Exception('Mất internet. Vui lòng bật mạng và thử lại!'),
        );
      });
      return;
    }

    final wasOffline = _isOffline;
    _isOffline = false;

    if (wasOffline || refreshWhenOnline) {
      setState(() {
        _productsFuture = _productService.fetchProducts();
      });
    }
  }

  Future<List<Product>> _fetchProductsWithInternetCheck() async {
    final hasInternet = await _hasRealInternetAccess();
    if (!hasInternet) {
      _isOffline = true;
      throw Exception('Mất internet. Vui lòng bật mạng và thử lại!');
    }

    _isOffline = false;
    return _productService.fetchProducts();
  }

  Future<bool> _hasRealInternetAccess() async {
    Future<bool> pingUrl(String rawUrl) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      try {
        final uri = Uri.parse(rawUrl);
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 3));
        request.followRedirects = true;
        final response = await request.close().timeout(
          const Duration(seconds: 3),
        );
        await response.drain<void>();
        return response.statusCode >= 200 && response.statusCode < 500;
      } catch (_) {
        return false;
      } finally {
        client.close(force: true);
      }
    }

    final hasGoogle204 = await pingUrl(
      'https://clients3.google.com/generate_204',
    );
    if (hasGoogle204) {
      return true;
    }

    return pingUrl('https://www.gstatic.com/generate_204');
  }

  // ignore: unused_element
  Future<void> _showAddProductDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController();
    Uint8List? imageBytes;
    String? imageExt;
    String? imageName;
    bool isDialogSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                withData: true,
              );

              if (result == null || result.files.isEmpty) {
                return;
              }

              final file = result.files.first;
              if (file.bytes == null) {
                return;
              }

              setDialogState(() {
                imageBytes = file.bytes;
                imageName = file.name;
                imageExt = file.extension ?? 'jpg';
              });
            }

            Future<void> saveProduct() async {
              if (_isSaving || isDialogSaving) {
                return;
              }

              final name = nameController.text.trim();
              final category = categoryController.text.trim();
              final priceText = priceController.text.trim();
              final price = double.tryParse(priceText);
              final quantityText = quantityController.text.trim();
              final quantity = int.tryParse(quantityText);

              if (name.isEmpty ||
                  category.isEmpty ||
                  price == null ||
                  price <= 0 ||
                  quantity == null ||
                  quantity < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đầy đủ thông tin hợp lệ.'),
                  ),
                );
                return;
              }

              if (imageBytes == null || imageExt == null) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn ảnh sản phẩm.')),
                );
                return;
              }

              setDialogState(() {
                isDialogSaving = true;
              });

              setState(() {
                _isSaving = true;
              });

              final navigator = Navigator.of(dialogContext);

              try {
                await _productService.addProduct(
                  name: name,
                  category: category,
                  price: price,
                  quantity: quantity,
                  imageBytes: imageBytes!,
                  fileExtension: imageExt!,
                );

                if (!mounted) {
                  return;
                }

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Thêm sản phẩm thành công.')),
                );
                _retry();
              } catch (error) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('Thêm sản phẩm thất bại: $error')),
                );
              } finally {
                setDialogState(() {
                  isDialogSaving = false;
                });
                if (mounted) {
                  setState(() {
                    _isSaving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Thêm sản phẩm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên sản phẩm',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Hạng mục'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Giá'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số lượng'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: pickImage,
                      child: const Text('Chọn ảnh'),
                    ),
                    if (imageName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        imageName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: (_isSaving || isDialogSaving)
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: (_isSaving || isDialogSaving) ? null : saveProduct,
                  child: (_isSaving || isDialogSaving)
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }

  Future<void> _showEditProductDialog(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: product.name);
    final categoryController = TextEditingController(text: product.category);
    final priceController = TextEditingController(
      text: product.price.toStringAsFixed(0),
    );
    final quantityController = TextEditingController(
      text: product.quantity.toString(),
    );
    Uint8List? imageBytes;
    String? imageExt;
    String? imageName;
    bool isDialogSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                withData: true,
              );

              if (result == null || result.files.isEmpty) {
                return;
              }

              final file = result.files.first;
              if (file.bytes == null) {
                return;
              }

              setDialogState(() {
                imageBytes = file.bytes;
                imageName = file.name;
                imageExt = file.extension ?? 'jpg';
              });
            }

            Future<void> updateProduct() async {
              if (_isSaving || isDialogSaving) {
                return;
              }

              final name = nameController.text.trim();
              final category = categoryController.text.trim();
              final priceText = priceController.text.trim();
              final price = double.tryParse(priceText);
              final quantityText = quantityController.text.trim();
              final quantity = int.tryParse(quantityText);

              if (name.isEmpty ||
                  category.isEmpty ||
                  price == null ||
                  price <= 0 ||
                  quantity == null ||
                  quantity < 0) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đầy đủ thông tin hợp lệ.'),
                  ),
                );
                return;
              }

              setDialogState(() {
                isDialogSaving = true;
              });

              setState(() {
                _isSaving = true;
              });

              final navigator = Navigator.of(dialogContext);

              try {
                await _productService.updateProduct(
                  product: product,
                  name: name,
                  category: category,
                  price: price,
                  quantity: quantity,
                  imageBytes: imageBytes,
                  fileExtension: imageExt,
                );

                if (!mounted) {
                  return;
                }

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Sửa sản phẩm thành công.')),
                );
                _retry();
              } catch (error) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('Sửa sản phẩm thất bại: $error')),
                );
              } finally {
                setDialogState(() {
                  isDialogSaving = false;
                });
                if (mounted) {
                  setState(() {
                    _isSaving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Sửa sản phẩm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên sản phẩm',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Hạng mục'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Giá'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số lượng'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: pickImage,
                      child: const Text('Đổi ảnh'),
                    ),
                    if (imageName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        imageName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: (_isSaving || isDialogSaving)
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: (_isSaving || isDialogSaving)
                      ? null
                      : updateProduct,
                  child: (_isSaving || isDialogSaving)
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('TH3-Trần Vĩnh Bảo-2351060419'),
        centerTitle: false,
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 32,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Đang tải dữ liệu...',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            final rawError = snapshot.error.toString();
            final errorMessage = rawError.startsWith('Exception: ')
                ? rawError.substring(11)
                : rawError;

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Không thể tải dữ liệu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _retry,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('Chưa có sản phẩm nào.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 700 ? 2 : 3;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ProductCard(
                    product: product,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(product: product),
                        ),
                      );
                    },
                    onEdit: _isSaving
                        ? null
                        : () => _showEditProductDialog(product),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: Colors.white,
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
