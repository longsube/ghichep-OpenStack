Mỗi dịch vụ của Ceilometer được thiết kế để mở rộng theo chiều ngang. Các thành phần bổ xung và node vật lý có thẻ được bổ xung phụ thuộc vào tải. Ceilometer cung cấp 3 dịch vụ lõi, data agent được thiết kế để hoạt động độc lập với collection, nhưng có thể làm việc cùng nhau để tạo thành một giải pháp hoàn chỉnh:

- Polling agent: daemon thiết kế để lấy các thông tin của dịch vụ OpenStack và build Meter.
- Notification agent: daemon thiết kế để lắng nghe cảnh báo trên message queue, dịch thành Events và Sample, và chấp nhận các pipeline action.
- Collector: deamon được thiết kế để nhận các event và metric từ notification và polling agents và lưu trữ dữ liệu vào database, file hay gnocchi
- api: dịch vụ truy vấn và xem các dữ liệu trong database
- aodh: Thành phần cảnh báo