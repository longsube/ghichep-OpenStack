# 1 Kiến trúc Ceilometer-Grocchi-Aodh

![alt text](http://image.prntscr.com/image/2d4ac06c066a4fa2a3cee537eb33074a.png)

## 1.1 Thu thập dữ liệu

![alt text](http://image.prntscr.com/image/70fccb182bf94a3d8a91c13294193784.png)

Mỗi một project muốn thao tác được phải gửi các event (sự kiện) vào các Oslo bus về bất cứ gì có thể có liên quan đến người dùng. Nhưng không phải tất cả các project đều làm thế và chúng ta thường dùng các công cụ khác không cùng chung bus như OpenStack đã định nghĩa. Ceilometer project có 2 phương thức để thu thập dữ liêu:

- Bus listener agent: lấy sự kiện trên notification bus và chuyển thành mẫu cho Ceilometer. Đây là phương pháp được khuyến nghị trong thu thập dữ liệu. 

- Polling agent: phương pháp ít được khuyến khích sử dụng, sẽ đẩy vào API hoặc công cụ khác để thu thập thông tin ở từng khoảng thời gian định kỳ. Phương pháp này không phổ biến vì lượng tải quá lớn nó có thể tạo ra trên API services. 
Phương pháp đầu tiên được hỗ trợ bởi ceilometer-notification agent, giám sát các message queues để cảnh báo. Pollong agent có thể cấu hình để đẩy tới local hypervisor hoặc remote API (public REST API của dịch vụ và SNMP/IPMI daemons của host)

### 1.1.1 Notification agent (lắng nghe dữ liệu)

![alt text](http://image.prntscr.com/image/da7d67e17120455f9210081632180b32.png)

Trái tim của hệ thống này là daemon thông báo (agent-notification) giám sát các message bus để lấy dữ liệu cung cấp bởi các project của OpenStack như Nova, Glance, Cinder, Neutron, Swift, Keystone, Heat cũng như trong bản thân Ceilometer.

Daemon cảnh báo tải một hoặc nhiều listener plugin, sử dụng namespace ceilometer.notification . Mỗi plugin có thể lắng nghe nhiều topics, nhưng mặc định chỉ nghe từ notifications.info . Listener bắt các bản tin khỏi topics và phân phối tới plugin phù hợp (endpoint) để xử lý thành các Events và Samples.

Các plugin hướng Sample cung cấp phương thức để liệt kê các loại sự kiện nó tìm kiếm và một callback  để xử lý các bản tin. Tên của callback để enable hoặc disable nó dùng pipeline của notification daemon. Các bản tin tới được lọc dựa theo giá trị từng loại sự kiện trước khi chuyển qua callback, nên các plugin chỉ nhân các sự kiện mà nó muốn biết. VD, một callback cần sự kiện compute.instance.create.end dưới ceilometer.compute.notification có thể gọi các thông tin về sự kiện này trên nova exchange dùng notification.info topic. Có thể dùng wildcard,vd: compute.instance.* để gọi 1 chuỗi sự kiện.

Tương tự, nếu enable, các thông tin sẽ được chuyển thành Events và có thể lọc dựa theo khai báo event_type bởi các dịch vụ khác.

### 1.1.2 Polling agents (Yêu cầu dữ liệu)

![alt text](http://image.prntscr.com/image/24b4ab1988414f15a465f996ed21e54f.png)

Polling tài nguyên tính toán được thực hiện bởi polling agent chạy trên node compute (giao tiếp với hypervisor hiệu quả nhất), thường gọi là compute-agent. Polling qua API cho các tài nguyên không tính toán được thực hiện bởi agent chạy trên node controller, thường gọi là central-agent. Một single agent có thể thực hiện cả 2 vai trò trên khi được triển khai dạng all-in-one. Ngược lại, có thể triển khai nhiều instances của 1 agent, trong trường hợp tải được share. Daemon polling agent được cấu hình để chạy 1 hoặc nhiều pollster plugin dùng namespace ceilometer.poll.compute hoặc ceilometer.poll.central

Các agent định kỳ hỏi mỗi pollster về các instance của mẫu. Tần xuất polling được điều khiển qua cấu hình pipeline. Agent framwork sau đó chuyển các mẫu tới pipeline để xử lý.

Lưu ý có một thông số cấu hình là shuffle_time_before_polling_task trong ceilomter.conf. Enable thông số này bằng cách đặt một số nguyên > 0 để xáo trộn các agent khi gửi polling task, việc này để tránh việc quá nhiều request được gửi tới các thành phần như nova, neutron,.. trong một khoảng thời gian ngắn. Thêm nữa, có một tùy chọn để chuyển các mẫu với độ trễ thấp nhất (tiêu tốn tải) bằng cấu hình batch_polled_samples  giá trị False trong ceilometer.conf.


## 1.2.	Xử lý dữ liệu

![alt text](http://image.prntscr.com/image/744a1b6a4369468082f1ffdf88b8dce9.png) 

Ceilometer cung cấp khả năng tập trung dữ liệu bởi agent, thao tác dữ liệu đó, và publish nó ra các hệ thống khác qua các pipeline. Tính năng này được thực hiện bởi notification agent.

### 1.2.1.Chuyển đổi dữ liệu

![alt text](http://image.prntscr.com/image/3f49740ef64d45a5b1e16d1e487172a8.png)

Các thông tin thu thập từ polling và notification agent chứa một lượng lớn dữ liệu và nếu kết hợp với cách tính thời gian, có thể sinh ra nhiều dữ liệu hơn. Ceilometer cung cấp nhiều phương thức chuyển đổi có thể dùng để thao tác dữ liệu trong pipeline.
### 1.2.2 Publishing dữ liệu
![alt text](http://image.prntscr.com/image/06ace1d45a1041d181e12d0d15d79706.png)

Hiện tại, dữ liệu xử lý có thể phát hành ra ngoài dùng 3 phương thức: notifier, một phương thức thông báo dựa trên publisher đẩy các mẫu tới một message queue, sau đó được sử dụng bởi collector hoặc hệ thống ngoài; udp, phát hành các mẫu dùng bản tin UDP; và kafka, phát hành dữ liệu tới một Kafka message queue để sử dụng bởi bất kỳ hệ thống nào hỗ trợ Kafka.

## 1.3.	Lưu trữ dữ liệu

![alt text](http://image.prntscr.com/image/ae8c9c5a6588431c8e1e03c98a0f466b.png)  

### 1.3.1 Collector Service

Collector daemon tập hợp các sự kiện đã được xử lý và dữ liệu đo đạc được thu thập bởi notification và polling agents. Nó phê duyệt các dữ liệu đầu vào, sau đó ghi các bản tin vào một nơi chỉ định: database, file hoặc http.

### 1.3.2 Database hỗ trợ

Trong phiên bản Juno và Kilo, Ceilometer được chia làm 3 thành phần: alarm, event và metering. Điều này cho phép người triển khai tiếp tục lưu trữ toàn bộ dữ liệu trên 1 database hoặc chia dữ liệu ra các database riêng, tùy mục đích sử dụng. VD: có thể lưu trữ dữ liệu cảnh báo trong SQL backend trong khi lưu trữ dữ liệu về sự kiện và dữ liệu đo đạc trong NoSQL Backend.

Dịch vụ lưu trữ cho Ceilometer được thiết kế để giải quyết các use cases mà tính chính xác của dữ liệu cần đươc đảm bảo. Để giải quyết việc trả lời các request, các query dữ liệu trong thời gian dài, các giải phảp cắt nhỏ dữ liệu theo từng mốc thời gian, như Gnocchi được ưu tiên.
Ghi chú: 

- Ở bản Liberty, việc hỗ trợ cảnh báo, và database của nó được thực hiện bởi Aodh
- Nên truy cập database qua API, không query trực tiếp.

## 1.4.	Truy cập dữ liệu

![alt text](http://image.prntscr.com/image/e42c3fba17d94533991311c0302bdef9.png)  

Nếu dữ liệu thu thập từ polling và notification agent được lưu trữ trong Ceilometer database, các schema của database này có thể tăng lên theo thời gian. Nên dùng REST API để truy cập dữ liệu  thay vì truy cập thẳng vào database.


# 2.Gnocchi
## 2.1 Vấn đề
Ceilometer hiện đang giải quyết 2 vấn đê:

- Lưu trữ metric: là một danh sách các timestamp, value cho một thực thể, thực thể này có thể là bất cứ gì từ nhiệu độ trong DC tới CPU sử dụng cho 1 VM.
- Lưu trữ event: danh sách các sự kiện xảy ra trong OpenStack, một API request đã được nhận, một VM được khởi chạy, một image được upload, một server lỗi,…
2 vấn đề này cần thiết cho mọi use case. Metric cho giám sát, billing và alarming, events cho audit, phân tích hiệu năng, debug,…

Tuy nhiên, trong khi việc thu thập event của Ceilometer là rất ổn, metric đang chịu nhiều vấn đề phực tạp trong thiết kế và hiệu năng.

Có một thứ gọi là free form metadata gẵn với từng metric, đó là vẫn đề lớn nhất trong thiết kế. Nó lưu trữ quá nhiều thông tin thừa và khó để tối ưu việc query. Nói cách khác, hệ thống như RRD đã tồn tại trong một thời gian, lưu trữ một lượng lớn metric mà không gặp quá nhiều vấn đề. Metadata gắn với các metric trở thành một vấn đề khác.

Có 2 vấn đề cần giải quyết: lưu trữ metric và lưu trữ thông tin (metadata) về tài nguyên.

## 2.2.	Prototype Implementation

![alt text](http://image.prntscr.com/image/fc76a7580ff94fdca33c2df684ee39d5.png)

Giải pháp sử dụng Gnocchi Project. Nó cung cấp một vùng lưu trữ dạng time serie và mọt indexer nhanh và có thể mở rộng.
Nó cung cấp một REST API. REST API cung cấp 2 loại tài nguyên:

•	Thực thể, là thứ cần đo lường.
•	Tài nguyên, có nhiều thông tin, và được kết nối tới bất kỳ một số lượng thực thể.
2 loại này được quản lý và cung cấp bởi Gnocchi và lưu trữ trong các datastore khác nhau. Phụ thuộc vào một loại lưu trữ có thể gây nên hư hỏng dữ liệu.

### 2.2.1 Time series Storage

Storage driver chịu trách nhiệm lưu trữ các metric ở dạng tập hợp. Có nghĩa là bạn có thể tập hợp dữ liệu theo yêu cầu người dùng khi họ tạo các thực thể, trước khi lưu trữ metric.

Mô hình của time series storage là dựa theo việc sử dụng của Pandas và Swift.

Swift cung cấp một không gian gần như vô tạn để lưu trữ dữ liệu. là một phần trong đám mây OpenStack và có khả năng mở rộng.

### 2.2.2 Resource Indexer

Mô hình dựa trên SQLAlchemy, bởi SQL nhanh, có khả năng đánh index,… SQL đã được triẻn khai trong OpenStack.

### 2.2.3 Kiến trúc

Gnocchi bao gồm nhiều dịch vụ: HTTP REST API, một statsd-compatible daemon có thể tùy chọn, và một daemon xử lý bất đồng bộ. Dữ liệu được nhận thông qua HTTP REST API và statsd daemon. Daemon xử lý bất đồng bộ, gọi là gnocchi-metricd, thực hiện các tác vụ xử lý dữ liệu nhận được ở background (phân tích, thống kê,…) 

Cả HTTP REST API và daemon xử lý bất đồng bộ đều là stateless và có thể mở rộng. Các thành phần xử lý bổ xung có thể thêm vào thùy thuộc vào tải.

## 2.3 Back-end

Gnocchi sử dụng 2 loại back-end cho lưu trữ dữ liệu: một cho lưu trữ time-series (thông tin dữ liệu theo thời gian) (The storage driver) và một cho việc đánh chỉ mục dữ liệu (the index driver).

Storage chịu trách nhiệm lưu trữ các thông số đo lường của metric. Nó nhận các timestamps (mốc thời gian) và giá trị, sau đó xử lý tạm các dữ liệu đó dựa theo archive policies (các policies cho việc lưu trữ dữ liệu) được định nghĩa trước.

Indexer chịu trách nhiệm cho việc lưu trữ các chỉ mục của tất cả các tài nguyên, dựa theo loại và thuộc tính. Gnocchi chỉ có các loại resource từ các project OpenStack, nhưng cung cấp một generic type để chúng ta có thể tự tạo thêm các resource cơ bản và đảm trách các thuộc tính của resource đó. Indexer cũng phụ trách việc kết nối các resource với metric.

### 2.3.1 Chọn Back-end như thế nào?

Gnocchi hỗ trợ 4 loại Storage driver:

- File
- Swift
- Ceph (khuyến nghị)
- InfluxDB (thử nghiệm)

Ba Driver đầu tiên phụ thuộc vào một thư viện đưng giữa, là Carbonara, đảm trách việc xử lý time series, vì không có driver nào trong 3 loại trên tích hợp khả năng xử lý time series. InFluxDB không cần lớp này vì bản thân nó là một database dạng time series. Tuy nhiên, InfluxFB driver vẫn còn đang thử nghiệm và còn khá nhiều bug.

Ba Storage driver dựa theo Carbonara thì hoạt động tốt cũng như có khả năng mở rộng. Ceph và Swift có khả năng mở rộng cao hơn File Driver.

### 2.3.2 Phân hoạch Gnocchi Storage thế nào?
Gnocchi dùng một định dạng có thể chỉnh sửa trong thư viện Carbonara. Trong Gnocchi, một time serie là một tập hợp các điểm, mỗi điểm được gán một đơn vị đo lường, hoặc mẫu, trong một khoảng thời gian của time serie. Định dạng lưu trữ được nén bằng nhiều công nghệ, do đó việc tính toán kích thước một time serie có thể ước tính với công thức sau:

number of points × 9 bytes = size in bytes

Số lượng point muốn giữ được tính theo công thức sau:

number of points = timespan ÷ granularity

VD: nếu muốn giữ dữ liệu của một năm với khoảng lấy mẫu là 1 phút:

number of points = (365 days × 24 hours × 60 minutes) ÷ 1 minute

number of points = 525 600

Kết quả:

size in bytes = 525 600 × 9 = 4 730 400 bytes = 4 620 KiB

Ở trên là một time serie. Nếu archive policy sử dụng 8 phương thức thu nạp mặc định (mean, min, max, sum, std, median, count, 95pct) với cùng thông số “1năm, 1 phút” dung lượng tối đa cần sẽ là: 8 x 4.5 MB = 36 MB

### 2.3.3 Đặt archive policy và glanurity thế nào?

Trong Gnocchi, archive policy được diễn tả bởi số lượng các point. Nếu archive policy định nghĩa một policy với 10 point và khoảng lấy mẫu là 1 giây, time serie archive sẽ giữ dữ liệu trong 10 giây, mỗi point thể hiện dữ liệu tổng 1 giây. Có nghĩa là time serie sẽ lưu lớn nhất là 10 giây giữa point mới nhất và cũ nhất. Nhưng không có nghĩa là 10 giây liên tục: có thể không đều nếu dữ liệu không liên tục.

Không có dữ liệu quá hạn theo timestamp. Bạn không thể xóa các point dữ liệu cũ.

Do vậy, cả archive policy và khoảng lấy mẫu phụ thuộc vào các use case cụ thể. Dựa vào cách sử dụng dữ liêu, bạn có thể định nghĩa các archive policies.Một use case đơn giản với khoảng lấy mẫu thấp:

3600 points with a granularity of 1 second = 1 hour

1440 points with a granularity of 1 minute = 24 hours

1800 points with a granularity of 1 hour = 30 days

365 points with a granularity of 1 day = 1 year

Dung lượng tiêu tốn cho một method là: 7205 points × 17.92 = 126 KB. Nếu dùng 8 method cơ bản, metric sẽ chiếm: 8 × 126 KB = 0.98 MB

## 2.4.	Cấu hình Gnocchi

Cấu hình Gnocchi đặt tại /etc/ceilometer/ceilometer.conf, ta có bảng thông số sau:

Tên cấu hình	Tác dụng

storage.driver	Storage driver cho metrics.

indexer.url	URL cho indexer.

storage.file_*	Tùy chọn cho lưu trữ file nếu dùng file storage driver

storage.swift_*	Tùy chọn để truy cập vào Swift nếu dùng Swift Storage driver

storage.ceph_*	Tùy chọn để truy cập Ceph nếu dùng Ceph Storage driver

Gnocchi cung cấp các loại storage driver sau:

- File (mặc định)
- Swift
- Ceph
- InfluxDB(thử nghiệm)

Gnocchi cung cấp các indexer driver sau:

- PostgreSQL (khuyến nghị)
- MySQL

### 2.4.1.Cấu hình WSGI pipeline

API server dựa vào Paste Deployment để quản lý cấu hình. Có thể sửa /etc/gnocchi/api-paste.ini  để chỉnh WSGI pipeline của Gnocchi REST HTTP server. Mặc định, không có lớp xác thực ở giữa, nên tất cả request phải có header để xác thực.

Gnocchi dễ dàng kết nối với OpenStack Keystone. Nếu cài keystone flavor dùng pip, sửa api-paste.ini để thêm lớp xác thực Keystone:

[pipeline:main]

pipeline = keystone_authtoken gnocchi

Nếu dùng CORS (VD để dùng với Grafana), có thể thêm CORS middleware vào server pipeline:

[pipeline:main]

pipeline = keystone_authtoken cors gnocchi

### 2.4.2.Carbona based drivers (file, swift, ceph)

Để đảm bảo tính nhất quán (consistency) trên tất cả gnocchi-api và gnocchi-metricd (gọi chung là worker), các driver cần một cơ chế lock phân tán. Cơ chế này được cung cấp bởi thư viện tooz.

Mặc định, backend được cấu hình cho tooz tương tự như indexer (PostgréQL hoặc MySQL). Điều này cho phép lock các workers trên nhiều node tách biệt.

Để phục vụ việc triển khai mọt hệ thống nhiều node một cách bền vững, coordinator có thể được thay đổi thông qua cấu hình storage.coordination_url tới một trong các tooz backend khác.

VD, để dùng Redis backend:

coordination_url = redis://<sentinel host>?sentinel=<master name>

hoặc cách khác, để dùng Zookeeper backend:

coordination_url = zookeeper:///hosts=<zookeeper_host1>&hosts=<zookeeper_host2>

### 2.4.3 Ceph driver 

Mỗi nhóm thông số giám sát được được lưu trữ trong một rados object. Các object này được đặt tên là: measures_<metric_id>_<random_uuid>_<timestamp>

Cũng có một object rỗng đặc biệt là measures có list các thông số để xử lý lưu trong các giá trị xattr của nó.

Bởi cơ chế bất đồng bộ khi lưu trữ các thông số trong Gnocchi, gnocchi-metricd cần phải biết danh sách các object đang chờ được xử lý:

- Danh sách rados object không phải là giải pháp vì mất quá nhiều thời gian.
- Dùng các định dạng đặc biệt trong 1 rados object, khiến cho phải ‘lock’ mỗi khi cần thay đổi.

Thay vào đó, các xattr của một rados object rỗng được sử dụng. Không cần ‘lock’để thêm/bớt một xattr.

Nhưng phụ thuộc vào filesysyem dùng bởi ceph OSD, các xattr này có giới hạn ở số lượng và kích thước nếu Ceph không được cấu hình đúng. Tham khảo Ceph extended attributes documentation.

Sau đó, mỗi file Carbonara sinh ra được lưu trong 1 rados object. Mỗi metric có một rados object cho mỗi tập hợp trong archive policy.

Bởi thế, việc làm đầy OSD có thể không cân bằng khi so với RBD. Các object sẽ lớn và cái khác thì nhỏ, dựa vào archives policy được set up như thế nào.

Có thể tưởng tượng một tình huống như là lưu trữ 1 point/1 giây qua 1 năm, rados object size sẽ  là ~384 MB.

Trong khi ở một tình huống thực tế hơn, một rados object 4MB (như RBD user) sẽ cho ra:

- 20 ngày với 1 point/giây
- 100 ngay với 1 point/5giây

Như vậy, trong thực tế, mối liên hệ trực tiếp giữa archive polivy và kích thước của rados object tạo bởi Gnocchi là không phải vấn đề.

Gnocchi có thể dùng thư viện cradox Python. Thư viện này là một Python binding tới librados viết bởi Cython, hướng đến thay thế một thư viện khác với ctype cung cấp bởi Ceph.

Cython binding mới sẽ chia thời gian gnocchi-metricd để xử lý các thông số bằng một hệ số lớn hơn.

Vậy, nếu việc cài đặt Ceph không dùng phiên bản mới nhất, cradox có thể cài để nâng cao hiệu năng của Ceph backend.

##2.5.Chạy Gnocchi

Để chạy Gnocchi, khởi chạy HTTP Server và metrci daemon:

gnocchi-api

gnocchi-metricd

### 2.5.1.Khởi chạy như một ứng dụng WSGI

Khuyến nghị chạy Gnocchi thông qua WSGI như mod_wsgi hoặc bất cứ ứng dụng WSGi nào khác. File gnocchi/rest/app.wsgi cho phép enable Gnocchi như một ứng dụng WSGI. Để cài đặt WSGI tham khảo tài liệu pedan deployment

### 2.5.2.Scale out lớp Gnocchi HTTP REST API  như thế nào?

Lớp Gnocchi API chạy trên WSGI, tức là nó có thể dùng Apache httpd và mod_wsgi, hoặc các HTTP daemon như uwsgi. Có thể cấu hình số lượng process và thread dựa theo số lượng CPU, khoảng 1.5 x CPU numbers. Nếu 1 server không đủ, có thể scale out trên các Server khác.

### 2.5.3.Cần bao nhiêu metricd worker?

Mặc định, gnocchi-metricd daemon tận dụng toàn bộ CPU để tối đa khả năng tính toán các metric. Có thể sử dụng lệnh gnocchi status để query HTTP API và lấy các trạng thái của cluster phục vụ việc tính toán. Lệnh này chỉ ra số lượng metric cần xử lý, gọi là backlog xử lý cho gnocchi-metricd. Cho tới khi các backlog này không tiếp tục tăng, tức là gnocchi-metricd vẫn còn xử lý được số lượng metric đang được gửi. Trong trường hợp số lượng này vẫn tiếp tục tăng, cần phải tăng số lượng của gnocchi-metricd daemon. Có thể chạy số lượng bất kỳ metricd daemon trên số lượng bất kỳ server.

### 2.5.4.Giám sát Gnocchi thế nào?

Endpoint /v1/status của HTTP API trả về các giá trị khác nhau, như là số lượng thông số cần xử lý (thông sô backlog), là thứ mà chúng ta có thể dễ dàng giám sat. Chắc chắn HTTP Server và gnocchi-metricd daemon đang chạy và không ghi bất cứ cảnh báo nào vào log, đây là dấu hiệu của một hệ thống đang chạy tốt.


### 2.5.5.Sao lưu và phục hồi Gnocchi thế nào?

Để khôi phục, cần phải backup cả index và storage. Có nghĩa là tạo một database dump (PostgréQL hoặc MySQL) và tạo các snapshot hoặc copy của data storage (Ceph, Swift, hoặc các file system). Các bước khôi phục không phức tạp hơn so với khi triển khai: khôi phục index và các bản storage backup, cài đặt lại Gnocchi nếu cần và khởi động lại nó.

### 2.5.6.Sử dụng Statsd Daemon

Statsd là một daemon mạng lắng nghe các thống kế gửi qua mạng dùng TCP hoặc UDP, và sau đó gửi các tập hợp đến 1 backend khác.

Gnocchi cung cấp một daemon tương thích với giao thức statsd và có thể lắng nghe các metric gửi qua mạng, gọi là gnocchi-statsd.

Để enable statsd trong Gnocchi, cần cấu hình tùy chọn [statsd]  trong file cấu hình.Cấn cung cấp 1 resource ID, nơi mà các metrics có thể được gắn vào. Một user và project ID có thể được liên kết với resource và metric, và môt archive policy name có thể dùng để tạo metric.

Tất cả metric có thể được tạo động khi các metric được gửi tới gnocchi-statsd,  và gắn với tên của Resource ID được cấu hình.

Gnocchi-statsd có thể mở rộng, nhưng sẽ có nhược điểm do tính chất của giao thức statsd. Có nghĩa là nếu bạn dùng các metric thuộc loại counter hoặc sampling, bạn nên gửi tất cả các metric này tới cùng daemon, hoặc không dùng tất cả. Các loại khác (timing hoặc gauge) không có hạn chế này, nhưng lưu ý rằng có thể có nhiều hơn các thông số nếu gửi cùng một metric tới các gnocchi-statsd server khác nhau, nếu mà cả cache cũng như độ trễ khi flush của nó không được đồng bộ giống nhau.

# 3. Aodh

![alt text](http://image.prntscr.com/image/5727b6721a844595850b26d22b6bcca9.png)

Aodh là một project dùng để cảnh báo. Aodh là một project độc lập với ceilometer và gnocchi. Aodh tách ra từ tính năng cảnh báo của ceilometer. Tính năng cảnh báo được yêu cầu tách từ bản Liberty và được hoàn toàn tách riêng biệt ở bản Mitaka.

Aodh sử dụng Ceilometer hoặc gnocchi như là nơi lưu trữ.  Mỗi một aodh service có thể mở rộng . Chúng ta có thể đặt trigger cảnh báo.
