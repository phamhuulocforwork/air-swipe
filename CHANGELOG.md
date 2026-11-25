# Nhật ký thay đổi

Mọi thay đổi đáng chú ý của AirSwipe được ghi lại tại đây.

## [1.0.0] - 2026-11-25

Bản phát hành đầu tiên.

### Thêm mới

- Nhận diện cử chỉ bàn tay thời gian thực bằng MediaPipe Tasks Vision (Gesture Recognizer) trên camera trước.
- Vuốt lên/xuống trên toàn hệ thống khi phát hiện lòng bàn tay mở di chuyển theo chiều dọc.
- Thực thi thao tác vuốt qua Shizuku UserService chạy với quyền shell (`input swipe`), không cần root.
- Giao diện yêu cầu và hiển thị trạng thái quyền Shizuku.
- Ô Quick Settings để bật/tắt nhanh; thêm trực tiếp từ app trên Android 13+.
- Foreground service camera kèm thông báo "Đang lắng nghe cử chỉ".
- Tùy chỉnh độ nhạy (0.08–0.40), khoảng nghỉ (0.8–3.0 giây) và chế độ chỉ vuốt lên.
- Lưu cài đặt bằng SharedPreferences.
- Chế độ gỡ lỗi: preview camera, skeleton bàn tay, FPS, độ trễ và trạng thái phát hiện tay (chạm 5 lần vào tiêu đề).
- Hỗ trợ Android 7.0 (API 24) trở lên.

### Thay đổi

- Chuyển từ Google ML Kit Pose Detection sang MediaPipe Tasks Vision để nhận diện cử chỉ bàn tay.
- Chuyển luồng thực thi vuốt từ Accessibility Service sang Shizuku.
- Làm lại giao diện theo Material 3 với tông vàng chủ đạo.

### Sửa lỗi

- Sửa lỗi skeleton hiển thị sai vị trí và cử chỉ không kích hoạt.
- Ổn định việc đọc trạng thái Shizuku, tránh crash khi Shizuku chưa chạy hoặc dùng phiên bản cũ.

### Ghi chú

- APK release hiện được ký bằng debug key, phù hợp cho cài đặt cá nhân và thử nghiệm.
- Dự án chỉ hỗ trợ Android.
