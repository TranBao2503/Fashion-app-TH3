# fashion_store_app

Ứng dụng Flutter đa nền tảng hiển thị danh sách sản phẩm thời trang từ Firebase Firestore.

## Chức năng đã có

- Hiển thị danh sách bằng GridView (responsive theo kích thước màn hình).
- Xử lý đủ 3 trạng thái:
	- Loading: hiển thị `CircularProgressIndicator`.
	- Success: map dữ liệu Firestore vào model `Product` và render `Card`.
	- Error + Retry: hiển thị thông báo lỗi + nút `Thử lại` để gọi lại dữ liệu.
- Tổ chức code tách file rõ ràng: `models`, `services`, `screens`, `widgets`.

## 1) Cấu hình Firebase (chạy một lần)

> Lưu ý: hiện tại terminal chưa đăng nhập Firebase CLI, nên cần login trước.

```bash
firebase login
```

Sau đó, chạy cấu hình FlutterFire trong thư mục project:

```bash
dart pub global run flutterfire_cli:flutterfire configure --project <YOUR_FIREBASE_PROJECT_ID> --platforms android,ios,macos,web,linux,windows
```

Lệnh trên sẽ tự tạo file `lib/firebase_options.dart` và cập nhật file cấu hình nền tảng cần thiết.

## 2) Tạo collection Firestore

Tạo collection tên:

```text
fashion_products
```

Mỗi document cần các field:

- `name` (string)
- `category` (string)
- `price` (number)
- `imageUrl` (string)

## 3) Dữ liệu mẫu

File dữ liệu mẫu đã chuẩn bị tại:

- `sample_data/fashion_products.json`

Bạn có thể copy từng object để thêm vào collection `fashion_products` trên Firebase Console.

## 4) Chạy app

```bash
flutter pub get
flutter run
```
