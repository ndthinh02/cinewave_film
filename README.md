# CineWave

Ứng dụng Flutter xem phim, tìm kiếm, yêu thích và lưu tiến độ xem.

## Chạy ứng dụng

```sh
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.2.197:8080/api
```

Thiết bị phải truy cập được địa chỉ backend. Có thể thay API phim bằng
`--dart-define=MOVIE_BASE_URL=https://phimapi.com`.

## Bản phát hành

```sh
flutter build apk --release --dart-define=BACKEND_BASE_URL=https://your-backend.example/api
```

Thay địa chỉ ví dụ bằng backend HTTPS đã triển khai với chứng chỉ hợp lệ.
Giá trị mặc định là backend HTTP trong mạng local, phục vụ phát triển.
Trước khi phân phối, cấu hình application ID và khóa ký release riêng trong
`android/app/build.gradle.kts` (hiện dùng khóa debug).

## Kiểm tra

```sh
flutter analyze
flutter test
```
