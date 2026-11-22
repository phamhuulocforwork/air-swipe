# AirSwipe

Ứng dụng Android cá nhân: camera trước nhận tay vuốt lên hoặc xuống, rồi giả lập vuốt trên app đang mở (TikTok, Reels, Shorts). Cài bằng APK sideload. Không đưa lên Google Play — accessibility dùng để tự động thao tác thường bị từ chối review.

## Dùng

1. Cài APK. Trên Android 13 trở lên: Cài đặt → Ứng dụng → AirSwipe → menu → Cho phép cài đặt bị hạn chế.
2. Mở AirSwipe, cấp quyền camera và thông báo.
3. Bấm **Mở cài đặt hỗ trợ tiếp cận**, bật AirSwipe. Service không đọc nội dung màn hình.
4. Trên Android 13 trở lên, bấm **Gắn ô Quick Settings**. Máy cũ hơn: kéo thanh thông báo → sửa ô tắt → thêm AirSwipe.
5. Bật bằng ô Quick Settings hoặc switch trên màn test. Ô Quick Settings đưa màn test lên một nhịp (Android không cho mở camera từ nền) rồi trả về app phía dưới. Sau khi bật, ra Home hoặc để ô Quick Settings tự trả về app trước. Bấm Back sẽ đóng activity và tắt camera.
6. Mở TikTok, Reels hoặc Shorts. Tay đi lên → video sau. Tay đi xuống → video trước.

Pose Detection cần thấy cổ tay hoặc ngón trỏ, không chỉ một ngón vẫy rất nhỏ. Độ nhạy và cooldown chỉnh trên màn test; số được lưu lại. Mặc định độ nhạy 0.18, cooldown 1.5 giây.

Trong lúc lắng nghe có thông báo foreground vì camera chạy nền. Tắt bằng ô Quick Settings.

## Ghi chú kỹ thuật

Luồng ảnh không dùng plugin `camera`. Plugin đó gắn CameraX vào vòng đời activity, nên camera tắt ngay khi activity bị `onStop`. AirSwipe mở CameraX trong một foreground service kiểu `camera`, lifecycle riêng giữ ở resumed, rồi gửi frame NV21 sang Dart để chạy `google_mlkit_pose_detection`.

Nếu trục dọc bị ngược trên một máy, đổi `yIncreasesDownward` trong `WristSwipeTracker` (mặc định `true`).
