*Gnocchi bao gồm các thành phần: gnocchi-api, gnocchi-metricd, gnocchi-statsd*
# A.Môi trường cài đặt
 - OS: Ubuntu 14.04.5 LTS 
 - Kernel: 3.16.0-77-generic
 - Platform: OpenStack Mitaka

# B. Cài đặt
## 1. Cài đặt Gnocchi (thực hiện trên node Gnocchi)
### 1.1. Cài đặt git
```
apt-get install git -y
apt-get install python-pip -y
```
### 1.2. Tạo database cho Gnocchi
```
mysql -uroot -p
create database gnocchi;
grant all privileges on gnocchi.* to 'gnocchi'@'%' identified by 'Welcome123';
flush privileges;
exit;
```

### 1.3. Tạo endpoint cho Gnocchi
```
openstack user create gnocchi --domain default --password Welcome123
openstack role add --project service --user gnocchi admin
openstack service create --name gnocchi --description "Metric Service" metric
openstack endpoint create --region RegionOne metric public  http://172.16.69.46:8041
openstack endpoint create --region RegionOne metric admin  http://172.16.69.46:8041
openstack endpoint create --region RegionOne metric internal  http://172.16.69.46:8041
```

### 1.4. Download source code của Gnocchi, branch stable/3.0
```
git clone -b stable/3.0 https://github.com/openstack/gnocchi.git
cd gnocchi
```

### 1.5. Cài đặt các thư viện python cần thiết
```
apt-get install python-dev -y
pip install sqlalchemy_utils
pip install lz4
pip install -r requirements.txt
```

### 1.6. Cài đặt Gnocchi
```
python setup.py install
```

### 1.7. Tạo file cấu hình cho Gnocchi
```
oslo-config-generator --config-file=/root/gnocchi/etc/gnocchi/gnocchi-config-generator.conf --output-file=/etc/gnocchi/gnocchi.conf
cp /root/gnocchi/etc/gnocchi/policy.json /root/gnocchi/etc/gnocchi/api-paste.ini /etc/gnocchi
groupadd gnocchi
useradd -g gnocchi gnocchi
```

### 1.8. Sửa file gnocchi.conf với các nội dung sau:
```
[DEFAULT]
debug = True
log_dir = /var/log/gnocchi

[api]
[archive_policy]
[cors]
[cors.subdomain]
[database]

#khai báo DB để chứa các index của Gnocchi (có thể chọn mysql, sqllite, InflushDB)
[indexer] 
url = mysql+pymysql://gnocchi:Welcome123@10.10.10.231/gnocchi

[keystone_authtoken]
auth_uri = http://10.10.10.231:5000/v3
auth_url = http://10.10.10.231:35357/v3
auth_version = 3
auth_port = 35357
admin_tenant_name = admin
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = gnocchi
password = Welcome123


[metricd]
workers = 1
[oslo_middleware]
[oslo_policy]

[statsd]
# Sử dụng chuỗi ngẫu nhiên, có thể dùng lệnh "python -c 'import uuid; print uuid.uuid4()'"" để sinh
resource_id = 5e3fcbe2-7aab-475d-b42c-a440aa42e5ad
# sử dụng gnocchi user_id và service tenant_id
user_id = e0ca4711-1128-422c-abd6-62db246c32e7
project_id = af0c88e8-90d8-4795-9efe-57f965e67318
archive_policy_name = high
flush_delay=10

#khai báo Storage để chứa data của Gnocchi (có thẻ chọn file, ceph, swift)
[storage] 
file_basepath = /var/lib/gnocchi/
driver = file

```

### 1.9. Sửa utils.py
*Do thư viện `tooz` không có hàm `start_heart`*
```
vim /usr/local/lib/python2.7/dist-packages/gnocchi/utils.py
	def _enable_coordination(coord):
	    try:
	        coord.start()
	    except Exception as e:
	        LOG.error("Unable to start coordinator: %s", e)
	        raise Retry(e)
```
### 1.10.  Tạo service quản lý bởi init cho gnocchi-api
*Tương tự cho `gnocchi-metricd` và `gnocchi-statsd`*
```
vim /etc/init/gnocchi-api.conf


description "Gnocchi API Service"

# Service level
start on runlevel [2345]

# When to stop the service
stop on runlevel [016]

# Automatically restart process if crashed
respawn


# Specify working directory
chdir /usr/local/bin/

# Specify the process/command to start, e.g.
exec gnocchi-api

```

### 1.11. Sửa `api-paste.ini`
```
vim /etc/gnocchi/api-paste.ini
	[pipeline:main]
	pipeline = gnocchi+auth

	[filter:cors]
	paste.filter_factory = oslo_middleware.cors:filter_factory
	oslo_config_project = gnocchi

	[filter:authtoken]
	paste.filter_factory = keystonemiddleware.auth_token:filter_factory
```

### 1.12. Cài đặt gnocchi cli
```
git clone -b stable/2.2 https://github.com/openstack/python-gnocchiclient.git
cd python-gnocchiclient
pip install -r requirements.txt
python setup.py install

```

### 1.13. Sửa port cho gnocchi service
```
vim /usr/local/bin/gnocchi-api
...
parser.add_argument('--port', '-p', type=int, default=8041,
                        help='TCP port to listen on')
...
```

### 1.14. Test Gnocchi-api
```
cd /etc/init/; for i in $(ls gnocchi-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
netstat -anp | grep 8041
gnocchi status
```

### 1.14. Get file định nghĩa resource cho Gnocchi
```
curl -L 'https://raw.githubusercontent.com/openstack/ceilometer/stable/mitaka/etc/ceilometer/gnocchi_resources.yaml' > /etc/ceilometer/gnocchi_resources.yaml
```

### 1.15. Upgrade  resource type cho Gnocchi
```
gnocchi-upgrade --debug --create-legacy-resource-types -v
```

## 2. Cấu hình ceilometer
### 2.1. Cấu hình `/etc/ceilometer/ceilometer.conf để sử dụng Gnocchi làm backend 
```
[DEFAULT]
meter_dispatchers = gnocchi
rpc_backend = rabbit
auth_strategy = keystone

[cors]
[cors.subdomain]

[database]
connection = mongodb://ceilometer:Welcome123@10.10.10.231:27017/ceilometer

[notification]
disable_non_metric_meters = false

[keystone_authtoken]
auth_uri = http://10.10.10.231:5000
auth_url = http://10.10.10.231:35357
memcached_servers = 10.10.10.231:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = ceilometer
password = Welcome123

[service_credentials]
auth_type = password
auth_url = http://10.10.10.231:5000/v3
project_domain_name = default
user_domain_name = default
project_name = service
username = ceilometer
password = Welcome123
interface = internalURL
region_name = RegionOne

[matchmaker_redis]
[oslo_concurrency]
[oslo_messaging_amqp]
[oslo_messaging_notifications]

[oslo_messaging_rabbit]
rabbit_host = 10.10.10.231
rabbit_userid = openstack
rabbit_password = Welcome123

[oslo_policy]

[alarms]
gnocchi_url = http://10.10.10.231:8041

[dispatcher_gnocchi]
url = http://localhost:8041
filter_project = service
filter_service_activity = False
#Set archive policy cho các metric Ceilometer gửi tới Gnocchi
archive_policy = low 
resources_definition_file = gnocchi_resources.yaml

```

### 2.2. Khởi động lại dịch vụ Gnocchi và Ceilometer
```
cd /etc/init/; for i in $(ls ceilometer-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
cd /etc/init/; for i in $(ls gnocchi-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
```
### 2.3. Kiểm tra resource, metric, mesurements của Gnocchi
```
gnocchi resource list
gnocchi metric list
gnocchi measures show [metric_id]
```


Tham khảo:

[1]- https://github.com/tigerlinux/tigerlinux-extra-recipes/blob/master/recipes/openstack/ceilometer-with-gnocchi-backend/RECIPE-ceilometer-with-gnocchi-backend.md

[2]- http://docs.openstack.org/developer/gnocchi/install.html

[3]- http://docs.openstack.org/developer/gnocchi/configuration.html