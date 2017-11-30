# Kiến trúc AODH

![aodh architecture](images/aodh_architecture.jpg)

## 1. Giới thiệu

Aodh là thành phần phụ trách cảnh bảo trong prọect Ceilometer, nay đã được tách ra thành project riêng. Project này dựa trên phần code lõi của dịch vụ cảnh bảo trong Ceilometer, và được phát triển từ phiên bản OpenStack Liberty. Tất cả các phần code liên quan tới cảnh bảo đã được loại bỏ khỏi Ceilometer từ phiên bản Mitaka.

## 2. Thành phần

Aodh bao gồm 4 thành phần sau:

 - `aodh-api`: cung cấp khả năng truy xuất vào các alarm cho người dùng, người dùng có thể tạo, thêm, sửa, xóa, cấu hình các alarm này. Service này chạy dưới HA Proxy với mod_wsgi hoặc eventlet. Endpoint của service này cần đăng ký qua Keystone service catalog, bởi Ceilometer API dùng endpoint này để proxy các cảnh báo từ các Ceilometer Client. Nên cài đặt và chạy `aodh-api` trước khi chạy `ceilometer-api`. Service `aodh-api` dùng keystone để xác thực requests

 - `aodh-evaluator`: đánh giá cảnh báo qua một khoảng thời gian, mặc định là 1 phút. Service này giống như `ceilometer-alarm-evaluator`, chạy dưới pacemaker với mode active-passive, bởi nó cần từng coordination riêng cho từng `aodh-evaluator`. 

 - `aodh-listener`: đánh giá khả năng cảnh báo. Nó lắng nghe từ queue và ước lượng việc cảnh báo nếu sự kiện cho cảnh báo được nhận. Service này không cần coordination và có thể chạy trên mỗi node controller với respawn. Service này dùng một oslo.messaging listener để nhận message từ queue.

 - `aodh-notifier`: gửi các thông tin cảnh báo với các trangj thái của từng cảnh báo (ok, alarm, insufficient data). Service này không cần coordination và có thể chạy trên từng node controller như một service với respawn. Service này cần kết nối tới AMQP.
 Database mặc định cho aodh là MySQL, kết nối url có thể được định nghĩa trong file cấu hình. Binary `aodh-dbsync` chạy trước khi service aodh đầu tiên chạy.


## 3. Kiến trúc high-level

Aodh cho phép người dùng đặt cảnh báo dựa trên các ngưỡng của một tập các mẫu hoặc các sự kiện cụ thể. Một cảnh báo có thể được đặt trên một meter, hoặc kết hợp nhiều meter. VD: bạn có thể 'trigger' một cảnh báo khi lượng RAM tiêu thụ đặt tới 70% trên một máy ảo nếu máy ảo đã được bật trên 10 phút. Để cài đặt 1 cảnh báo, bạn tương tác tới `aodh-api` để chỉ định một alarm và hành động tươnng ứng.
Có nhiều dạng action, nhưng chỉ một số loại action sau được áp dụng:
 - *HTTP callback*: cung cấp một URL được gọi bất cứ khi nào cảnh báo được kích hoạt. Payload của request chứa toàn bộ thông tin vì sao alarm được kích hoạt.
 - *log*: hữu ích khi debug, lưu trữ alarm trong log file.
 - *zaqar*: gửi thông báo tới messaging service thông Zaqar API. (Zaqar là một multi-tenant cloud messaging và notification service cho web và mobile)


Tham khảo:

[1]- http://docs.openstack.org/developer/aodh/architecture.html

[2]- https://specs.openstack.org/openstack/fuel-specs/specs/9.0/fuel-aodh-integration.html

[3]- http://www.sparkmycloud.com/blog/telemetry-service-in-openstack/
