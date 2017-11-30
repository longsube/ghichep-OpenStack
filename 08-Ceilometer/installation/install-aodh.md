AODH là thành phần đảm trách cảnh báo trong ceilometer, khi các meter hoặc event vượt ngưỡng được định nghĩa trước:
 - `aodh-api`: cung cấp khả năng truy xuất thông tin cảnh báo
 - `aodh-evaluator`: quyết định khi nào phát cảnh báo dựa trên việc xâu chuỗi các thông tin thống kế vượt ngưỡng trong một khoảng thời gian
 - `aodh-listener`: quyết định thời điểm phát cảnh báo. Các cảnh báo được tạo dựa trên các luật được định nghĩa trước đối với các event.
 - `aodh-notifier`: cho phép cảnh báo được tạo dựa trên việc đánh giá ngưỡng trên một tập các mẫu


# A.Môi trường cài đặt
 - OS: Ubuntu 14.04.5 LTS 
 - Kernel: 3.16.0-77-generic
 - Platform: OpenStack Mitaka

# B. Cài đặt
## 1. Cài đặt AODH
### 1.1. Tạo Database cho aodh
```
mysql -u root -p
CREATE DATABASE aodh;
GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'localhost' IDENTIFIED BY 'AODH_DBPASS';
GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'%' IDENTIFIED BY 'AODH_DBPASS';
flush privileges;
exit;
```

### 1.2. Tạo `aodh` user
```
openstack user create --domain default --password-prompt aodh
openstack role add --project service --user aodh admin
```

### 1.3. Tạo `aodh` service
```
openstack service create --name aodh --description "Telemetry" alarming
```

### 1.4. Tạo API endpoint
```
openstack endpoint create --region RegionOne alarming public http://controller:8042
openstack endpoint create --region RegionOne alarming internal http://controller:8042
openstack endpoint create --region RegionOne alarming admin http://controller:8042
```

### 1.5. Cài đặt các paskage `aodh`
```
apt-get install aodh-api aodh-evaluator aodh-notifier \
  aodh-listener aodh-expirer python-ceilometerclient

```

### 1.6. Sửa file cấu hình `/etc/apdh/aodh.conf`
```
[DEFAULT]
...
rpc_backend = rabbit
auth_strategy = keystone

[oslo_messaging_rabbit]
...
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = RABBIT_PASS
[database]
...
connection = mysql+pymysql://aodh:AODH_DBPASS@controller/aodh
[keystone_authtoken]
...
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = aodh
password = AODH_PASS
[service_credentials]
auth_type = password
auth_url = http://controller:5000/v3
project_domain_name = default
user_domain_name = default
project_name = service
username = aodh
password = AODH_PASS
interface = internalURL
region_name = RegionOne
```

### 1.7. Sửa file cấu hình `/etc/aodh/api_paste.ini`
```
[filter:authtoken]
...
oslo_config_project = aodh
```

### 1.8. Tạo các bảng trong DB
```
su -s /bin/sh -c "aodh-dbsync" aodh
```

### 1.9. Khởi động lại dịch vụ `aodh`
```
cd /etc/init/; for i in $(ls aodh-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
```

## 2. Cấu hình ceilometer
### 2.1. Get file định nghĩa event cho Ceilometer
```
curl -L 'https://raw.githubusercontent.com/openstack/ceilometer/stable/mitaka/etc/ceilometer/event_definitions.yaml' > /etc/ceilometer/event_definitions.yaml
curl -L 'https://raw.githubusercontent.com/openstack/ceilometer/stable/mitaka/etc/ceilometer/event_pipeline.yaml' > /etc/ceilometer/event_pipeline.yaml
```

### 2.2 Sửa `event_pipeline` để xuất các event
```
sinks:
    - name: event_sink
      transformers:
      triggers:
      publishers:
          - notifier://
          - notifier://?topic=alarm.all
          - notifier://?topic=event
```

### 2.3. Cấu hình `/etc/ceilometer/ceilometer.conf` để sử dụng `aodh`
```
[DEFAULT]
event_pipeline_cfg_file = event_pipeline.yaml
pipeline_cfg_file = pipeline.yaml
pipeline_polling_interval = 20
event_alarm_topic = alarm.all
evaluation_interval = 60
alarm_max_actions = -1

[api]
aodh_is_enabled = True
host = 0.0.0.0
port = 8777
workers = 1

[event]
definitions_cfg_file = event_definitions.yaml

[notification]
store_events = true
workers = 1
```

### 2.4. Khởi động lại dịch vụ AODH và Ceilometer
```
cd /etc/init/; for i in $(ls ceilometer-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
cd /etc/init/; for i in $(ls aodh-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
```

### 2.5. Kiểm tra event của AODH
```
ceilometer event-list
ceilometer event-type-list
```

Tham khảo:

[1]- http://docs.openstack.org/mitaka/install-guide-ubuntu/ceilometer-aodh.html

[2]- http://docs.openstack.org/mitaka/install-guide-ubuntu/common/get_started_telemetry.html

[3]- http://docs.openstack.org/admin-guide/telemetry-data-collection.html#telemetry-data-collection

[4] http://docs.openstack.org/developer/ceilometer/events.html

[5] http://docs.openstack.org/admin-guide/telemetry-data-retrieval.html

[6] http://docs.openstack.org/mitaka/config-reference/telemetry/telemetry-config-options.html

[7] http://docs.openstack.org/admin-guide/telemetry-alarms.html