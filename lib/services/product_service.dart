import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';

class ProductService {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  ProductService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : firestore = firestore ?? FirebaseFirestore.instance,
      storage = storage ?? FirebaseStorage.instance;

  Future<List<Product>> fetchProducts() async {
    try {
      final snapshot = await firestore.collection('fashion_products').get();

      return snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw Exception(
            'Bạn chưa có quyền đọc dữ liệu Firestore. Hãy cập nhật Firestore Rules.',
          );
        case 'unavailable':
          throw Exception(
            'Không thể kết nối Firestore. Vui lòng kiểm tra mạng.',
          );
        case 'failed-precondition':
          throw Exception(
            'Firestore chưa sẵn sàng hoặc thiếu cấu hình cần thiết.',
          );
        default:
          throw Exception('Lỗi Firestore (${error.code}): ${error.message}');
      }
    } catch (error) {
      throw Exception('Không thể tải dữ liệu từ Firebase: $error');
    }
  }

  Future<int> seedSampleProducts() async {
    try {
      final jsonString = await rootBundle.loadString(
        'sample_data/fashion_products.json',
      );
      final jsonList = jsonDecode(jsonString) as List<dynamic>;

      final batch = firestore.batch();
      final collection = firestore.collection('fashion_products');

      for (final item in jsonList) {
        final map = Map<String, dynamic>.from(item as Map);
        map.putIfAbsent('quantity', () => 0);
        final docRef = collection.doc();
        batch.set(docRef, map);
      }

      await batch.commit();
      return jsonList.length;
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw Exception(
            'Bạn chưa có quyền ghi dữ liệu Firestore. Hãy cập nhật Firestore Rules.',
          );
        case 'unavailable':
          throw Exception(
            'Không thể kết nối Firestore. Vui lòng kiểm tra mạng.',
          );
        default:
          throw Exception('Lỗi Firestore (${error.code}): ${error.message}');
      }
    } catch (error) {
      throw Exception('Không thể nạp dữ liệu mẫu: $error');
    }
  }

  Future<void> addProduct({
    required String name,
    required String category,
    required double price,
    required int quantity,
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    try {
      final normalizedName = _normalize(name);
      final query = await firestore
          .collection('fashion_products')
          .where('nameKey', isEqualTo: normalizedName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        throw Exception('Sản phẩm đã tồn tại. Vui lòng dùng tên khác.');
      }

      final ext = fileExtension.toLowerCase().replaceAll('.', '');
      final imageRef = storage
          .ref()
          .child('product_images')
          .child(
            '${DateTime.now().millisecondsSinceEpoch}_$normalizedName.$ext',
          );

      await imageRef.putData(imageBytes);
      final imageUrl = await imageRef.getDownloadURL();

      await firestore.collection('fashion_products').add({
        'name': name.trim(),
        'nameKey': normalizedName,
        'category': category.trim(),
        'price': price,
        'quantity': quantity,
        'imageUrl': imageUrl,
      });
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw Exception(
            'Bạn chưa có quyền ghi dữ liệu/ảnh. Hãy cập nhật Firestore & Storage Rules.',
          );
        case 'unavailable':
          throw Exception(
            'Không thể kết nối Firebase. Vui lòng kiểm tra mạng.',
          );
        default:
          throw Exception('Lỗi Firebase (${error.code}): ${error.message}');
      }
    }
  }

  Future<void> updateProduct({
    required Product product,
    required String name,
    required String category,
    required double price,
    required int quantity,
    Uint8List? imageBytes,
    String? fileExtension,
  }) async {
    try {
      final normalizedName = _normalize(name);
      final query = await firestore
          .collection('fashion_products')
          .where('nameKey', isEqualTo: normalizedName)
          .get();

      final hasDuplicate = query.docs.any((doc) => doc.id != product.id);
      if (hasDuplicate) {
        throw Exception('Sản phẩm đã tồn tại. Vui lòng dùng tên khác.');
      }

      var imageUrl = product.imageUrl;

      if (imageBytes != null && fileExtension != null) {
        final ext = fileExtension.toLowerCase().replaceAll('.', '');
        final imageRef = storage
            .ref()
            .child('product_images')
            .child(
              '${DateTime.now().millisecondsSinceEpoch}_$normalizedName.$ext',
            );

        await imageRef.putData(imageBytes);
        imageUrl = await imageRef.getDownloadURL();
        await _deleteImageFromUrl(product.imageUrl);
      }

      await firestore.collection('fashion_products').doc(product.id).update({
        'name': name.trim(),
        'nameKey': normalizedName,
        'category': category.trim(),
        'price': price,
        'quantity': quantity,
        'imageUrl': imageUrl,
      });
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw Exception(
            'Bạn chưa có quyền sửa dữ liệu/ảnh. Hãy cập nhật Firestore & Storage Rules.',
          );
        case 'unavailable':
          throw Exception(
            'Không thể kết nối Firebase. Vui lòng kiểm tra mạng.',
          );
        default:
          throw Exception('Lỗi Firebase (${error.code}): ${error.message}');
      }
    }
  }

  Future<void> deleteProduct(Product product) async {
    try {
      await firestore.collection('fashion_products').doc(product.id).delete();
      await _deleteImageFromUrl(product.imageUrl);
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw Exception(
            'Bạn chưa có quyền xóa dữ liệu/ảnh. Hãy cập nhật Firestore & Storage Rules.',
          );
        case 'unavailable':
          throw Exception(
            'Không thể kết nối Firebase. Vui lòng kiểm tra mạng.',
          );
        default:
          throw Exception('Lỗi Firebase (${error.code}): ${error.message}');
      }
    }
  }

  Future<void> deleteAllProducts() async {
    try {
      final snapshot = await firestore.collection('fashion_products').get();
      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      for (final doc in snapshot.docs) {
        final imageUrl = (doc.data()['imageUrl'] ?? '').toString();
        await _deleteImageFromUrl(imageUrl);
      }
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw Exception(
            'Bạn chưa có quyền xóa dữ liệu/ảnh. Hãy cập nhật Firestore & Storage Rules.',
          );
        case 'unavailable':
          throw Exception(
            'Không thể kết nối Firebase. Vui lòng kiểm tra mạng.',
          );
        default:
          throw Exception('Lỗi Firebase (${error.code}): ${error.message}');
      }
    }
  }

  String _normalize(String value) {
    final lower = value.trim().toLowerCase();
    final normalized = lower.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }

  Future<void> _deleteImageFromUrl(String imageUrl) async {
    if (imageUrl.isEmpty || !imageUrl.contains('firebasestorage')) {
      return;
    }

    try {
      final ref = storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (_) {}
  }
}
