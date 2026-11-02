# Tiệm Trà Nhỏ – App đặt trà sữa (PRM393)

Ứng dụng Flutter cho một quán trà sữa: khách xem menu, tùy chọn ly, ghim vị trí giao hàng trên bản đồ và đặt đơn; chủ quán (Seller) quản lý thực đơn và xử lý đơn theo thời gian thực.

## Tính năng

**Khách hàng**
- Đăng ký / đăng nhập bằng email hoặc Google; quên mật khẩu (Firebase gửi email đặt lại).
- Xem menu theo danh mục, tìm kiếm món và topping (gõ không dấu vẫn ra, vd "tra sua"). Menu tự cập nhật khi quán thay đổi (Firestore realtime).
- Tùy chọn size (M / L), mức đường, mức đá, topping và số lượng.
- Giỏ hàng tự gộp các ly giống nhau.
- Ghim vị trí nhận hàng trên bản đồ (thấy vị trí quán và vùng giao), tìm địa chỉ theo tên đường / tòa nhà. Vị trí ghim quyết định địa chỉ và phí ship; ô "Chi tiết thêm" chỉ để ghi số nhà, hẻm, tầng cho shipper. App nhớ vị trí và chi tiết cho lần đặt sau.
- Phí ship theo khoảng cách tới quán; vị trí ngoài vùng giao thì không đặt được.
- Khi đặt hàng, app kiểm tra lại món / topping còn bán và giá mới nhất của quán.
- Xem lịch sử và trạng thái đơn; hủy đơn khi quán chưa xác nhận.

**Chủ quán (Seller)**
- Bảng điều khiển: số đơn chờ xác nhận, tổng đơn trong ngày.
- Quản lý món và topping: thêm, sửa, xóa, ẩn / hiện, đánh dấu hết hàng; ảnh chọn từ điện thoại hoặc dán link.
- Quản lý đơn (tab **Hôm nay** / **Lịch sử**): chuyển trạng thái Pending → Preparing → Completed, hủy đơn kèm lý do. Quy tắc ở `lib/utils/order_policy.dart` (có unit test), `firestore.rules` kiểm tra lại bằng giờ server:
  - Tab Hôm nay: đơn đặt hôm nay (giờ Việt Nam) và mọi đơn chưa xong của các ngày trước. Tab Lịch sử: đơn đã xong của các ngày trước, chỉ xem, lọc theo ngày.
  - Chờ xác nhận quá 30 phút hoặc đang pha quá 2 giờ (tính từ lúc quán nhận đơn) là **quá hạn**: đơn chờ xác nhận chỉ còn được hủy, đơn đang pha được hoàn thành hoặc hủy để đóng đơn.
  - Đơn Đã hoàn thành / Đã hủy khóa hẳn; không ai xóa được đơn.
- Vị trí quán & giao hàng: nhập tọa độ (dán từ Google Maps hoặc chọn trên bản đồ) và bán kính giao.
- Đồng bộ thực đơn mẫu (chỉ bổ sung món còn thiếu, không ghi đè dữ liệu đã có).

## Phí giao hàng

Quy tắc nằm ở `lib/utils/shipping_policy.dart` (có unit test).

| Giá trị đơn | Gần (≤ 3 km) | Xa (> 3 km) |
|---|---|---|
| Dưới 50.000đ | 10.000đ | 15.000đ |
| 50.000đ – dưới 150.000đ | Freeship | 5.000đ |
| Từ 150.000đ | Freeship | Freeship |
| Ngoài bán kính giao (mặc định 7 km, Seller chỉnh được) | Không nhận đơn | Không nhận đơn |

Khoảng cách đo theo đường chim bay từ quán tới vị trí khách ghim. Khi Seller chưa cài vị trí quán, phí tính theo giá trị đơn: dưới 50.000đ là 15.000đ, 50.000–100.000đ là 10.000đ, trên 100.000đ miễn phí.

## Công nghệ

| Phần | Dùng |
|---|---|
| Giao diện | Flutter 3.24, Material 3 |
| Quản lý trạng thái | Provider |
| Đăng nhập | Firebase Authentication (email, Google) |
| Dữ liệu | Cloud Firestore |
| Ảnh món | Cloudinary (gói Free, upload preset unsigned) |
| Bản đồ | `flutter_map` + tile Esri World Street Map |
| Tìm địa chỉ | Photon (dữ liệu OpenStreetMap) |

> Không dùng trực tiếp `tile.openstreetmap.org` / `nominatim.openstreetmap.org` vì nhà mạng Việt Nam chặn các tên miền này (DNS trả về 127.0.0.1).

## Cấu trúc thư mục

```
lib/
  models/      ProductModel, ToppingModel, CartItemModel, OrderModel, UserModel
  providers/   CartProvider (giỏ hàng)
  services/    AuthService, DatabaseService (Firestore + upload ảnh), DatabaseSeeder (dữ liệu mẫu)
  screens/
    auth/      Splash (điều hướng theo role), đăng nhập / đăng ký
    customer/  Trang chủ, chi tiết món, giỏ hàng, chọn vị trí trên bản đồ, lịch sử đơn
    seller/    Bảng điều khiển, quản lý menu, quản lý đơn, vị trí quán & giao hàng
  utils/       Quy tắc phí ship (shipping_policy), xử lý đơn / quá hạn (order_policy), bỏ dấu tiếng Việt khi tìm kiếm (text_utils)
test/          Unit test cho giỏ hàng, phí ship, quy tắc xử lý đơn, tìm kiếm không dấu
firestore.rules  Quy tắc bảo mật Firestore (dán vào Firebase Console)
```

## Chạy app

Yêu cầu: Flutter 3.24 trở lên, Android Studio hoặc một máy Android thật.

```bash
flutter pub get
flutter run
```

Trên Windows, nếu gặp thông báo *"Please enable Developer Mode"*, chạy `start ms-settings:developers` và bật **Developer Mode**.

Cấu hình Firebase (project `projectmilktea`) đã có sẵn trong `lib/firebase_options.dart` và `android/app/google-services.json`.

Chạy test:

```bash
flutter test
```

## Tài khoản Seller

Có 2 cách vào Kênh Quản Trị:

1. Đăng nhập bằng email chủ quán `admin.tiemtranho@gmail.com` (hằng số `AuthService.adminEmail`). Mật khẩu hỏi nhóm, không ghi trong repo.
2. Cấp quyền cho tài khoản bất kỳ: đăng nhập app một lần, rồi vào Firebase Console → Firestore → `users` → document của tài khoản đó → đổi `role` từ `customer` thành `seller`.

Với Firestore mới chưa có dữ liệu: đăng nhập Seller và bấm biểu tượng 🔄 **Đồng bộ thực đơn** trên thanh tiêu đề của bảng điều khiển để nạp món và topping mẫu.

## Dữ liệu Firestore

| Collection | Nội dung | Ai được ghi (theo `firestore.rules`) |
|---|---|---|
| `products` | Món: tên, giá gốc, danh mục, ảnh, mô tả, `isActive`, `isAvailable` | Seller |
| `toppings` | Topping: tên, giá, ảnh | Seller |
| `orders` | Đơn hàng: `userId`, thông tin nhận hàng (`deliveryAddress` = chi tiết + địa chỉ theo vị trí ghim, `addressDetail`, `mapAddress`), tọa độ, `distanceKm`, danh sách ly, tiền, `status`, `acceptedAt` (lúc quán nhận đơn), `cancelledBy` / `cancelReason` | Khách tạo đơn và hủy đơn `Pending` của mình; Seller đổi trạng thái theo quy tắc quá hạn; không ai xóa |
| `users` | Hồ sơ: email, tên, SĐT, địa chỉ, vị trí ghim lần trước (`latitude`, `longitude`, `mapAddress`, `addressDetail`), `role` | Chính chủ (trừ `role`); Seller |
| `settings/store` | Vị trí quán: `latitude`, `longitude`, `address`, `deliveryRadiusKm` | Seller |

Khi sửa `firestore.rules`, dán lại nội dung vào Firebase Console → Firestore Database → **Rules** → **Publish**.
