  CTL:

## 1. Mô hình cài đặt
- Mô hình cài đặt Lab OPS Pike trên Ubuntu 16.04 64-bit
  
  ![MohinhCaiDat](/images/manila.jpg)
  
<a name=2></a>
## 2. IP Planning
- Phân hoạch địa chỉ Ip và yêu cầu phần cứng

  ![PhanHoachIP](/images/ip_pike.png)
  
<a name=3></a>
## 3. Thực hiện trên host Controller
- Lưu ý: 

  ```sh
  - Đăng nhập với quyền root cho tất cả các bước cài đặt
  - Các thao tác sửa file trong hướng dẫn này sử dụng lệnh vi hoặc vim
  - Password thống nhất cho tất cả các dịch vụ là Welcome123
  ```

### 3.1. Cài đặt
- Cài đặt gói để cài OpenStack PIKE

  ```sh
  apt install software-properties-common -y
  add-apt-repository cloud-archive:pike -y
  ``` 
  
- Cập nhật các gói phần mềm

  ```sh
  apt -y update && apt -y dist-upgrade
  ```

### 3.2. Tạo database cho manila
- 1. Đăng nhập vào MariaDB

  ```sh
  mysql -u root -pWelcome123
  ```
  
- 2. Tạo database cho manila

  ```sh
  CREATE DATABASE manila;
  ```
  
- 3. Cấp quyền truy cập vào cơ sở dữ liệu manila.
  
  ```sh
  GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'localhost' IDENTIFIED BY 'Welcome123';
  GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'%' IDENTIFIED BY 'Welcome123';
  FLUSH PRIVILEGES;
  exit;
  ```

### 3.3. Tạo user manila, gán quyền và tạo endpoint API cho dịch vụ manila

- Chạy script biến môi trường: `source admin-openrc`

- Tạo user manila:

  ```sh
  ~# openstack user create --domain default --password Welcome123 manila
  ```
- Thêm role admin cho user manila trên project service

  ```sh
  openstack role add --project service --user manila admin
  ```

- Tạo dịch vụ có tên manila

  ```sh
  ~# openstack service create --name manila \
  --description "OpenStack Shared File Systems" share
  ```

- Tạo dịch vụ có tên manila v2

  ```sh
  openstack service create --name manilav2 \
  --description "OpenStack Shared File Systems" sharev2
  ```

- Tạo các endpoint cho dịch vụ manila

  ```sh
  openstack endpoint create --region RegionOne \
  share public http://controller:8786/v1/%\(tenant_id\)s

  openstack endpoint create --region RegionOne \
  share internal http://controller:8786/v1/%\(tenant_id\)s

  openstack endpoint create --region RegionOne \
  share admin http://controller:8786/v1/%\(tenant_id\)s
  ```

- Tạo các endpoint cho dịch vụ manila v2

  ```sh
  openstack endpoint create --region RegionOne \
  sharev2 public http://controller:8786/v2/%\(tenant_id\)s

  openstack endpoint create --region RegionOne \
  sharev2 internal http://controller:8786/v2/%\(tenant_id\)s

  openstack endpoint create --region RegionOne \
  sharev2 admin http://controller:8786/v2/%\(tenant_id\)s
  ```

### 3.4. Cài đặt và cấu hình cho dịch vụ manila
- Cài đặt gói manila

  ```sh
  apt-get install manila-api manila-scheduler python-manilaclient -y
  ```

- Sao lưu các file `/etc/manila/manila-api.conf` trước khi cấu hình

  ```sh
  cp /etc/manila/manila.conf  /etc/manila/manila.conf.org
  ```

- Sửa các mục dưới đây ở cả 2 file `/etc/manila/manila-api.conf`
  ```sh
  [DEFAULT]
  my_ip = 10.0.0.161
  transport_url = rabbit://openstack:Welcome123@controller
  default_share_type = default_share_type
  share_name_template = share-%s
  rootwrap_config = /etc/manila/rootwrap.conf
  api_paste_config = /etc/manila/api-paste.ini
  auth_strategy = keystone

  [database]
  connection = mysql+pymysql://manila:Welcome123@controller/manila

  [keystone_authtoken]
  memcached_servers = controller:11211
  auth_uri = http://controller:5000
  auth_url = http://controller:35357
  auth_type = password
  project_domain_id = default
  user_domain_id = default
  project_name = service
  username = manila
  password = Welcome123  

  [oslo_concurrency]
  lock_path = /var/lock/manila
  ```
- Đồng bộ database cho manila

  ```sh
  su -s /bin/sh -c "manila-manage db sync" manila
  rm -f /var/lib/manila/manila.sqlite
  ```
  
- Restart dịch vụ manila.

  ```sh
  service manila-scheduler restart
  service manila-api restart
  ```

## 4. Thực hiện trên host Manila
### 4.1. Cài đặt NTP.
- Cài gói chrony.

  ```sh
  apt install chrony -y
  ```

- Mở file `/etc/chrony/chrony.conf` bằng vi và thêm vào các dòng sau:
- commnet dòng sau:

  ```sh
  #pool 2.debian.pool.ntp.org offline iburst
  ```

- Thêm các dòng sau:

  ```sh
  server controller iburst
  ```
  
- Restart dịch vụ NTP

  ```sh
  service chrony restart
  ```

- Kiểm tra Chrony

  ```sh
  chronyc sources
  ```

  Kết quả:

  ```sh
  210 Number of sources = 1
 MS Name/IP address         Stratum Poll Reach LastRx Last sample
 ===============================================================================
 ^* controller                    3   6    17    23    -10ns[+6000ns] +/-  248ms
  ```

## 4.2. Update package
- Cài đặt gói để cài OpenStack PIKE

  ```sh
  apt install software-properties-common -y
  add-apt-repository cloud-archive:pike -y
  ``` 
  
- Cập nhật các gói phần mềm

  ```sh
  apt -y update && apt -y dist-upgrade
  ```
- Cài đặt các gói client của OpenStack.

  ```sh
  apt install python-openstackclient -y
  ```
- Cài đặt Manila share
  ```sh
  apt-get install manila-share python-pymysql -y
  ```

- Sao lưu các file `/etc/manila/manila-api.conf` trước khi cấu hình

  ```sh
  cp /etc/manila/manila.conf  /etc/manila/manila.conf.org
  ```

- Sửa các mục dưới đây ở cả 2 file `/etc/manila/manila-api.conf`
  ```sh
  [DEFAULT]
  my_ip = 10.0.0.163
  transport_url = rabbit://openstack:Welcome123@controller
  default_share_type = default_share_type
  rootwrap_config = /etc/manila/rootwrap.conf
  auth_strategy = keystone

  [database]
  connection = mysql+pymysql://manila:Welcome123@controller/manila

  [keystone_authtoken]
  memcached_servers = controller:11211
  auth_uri = http://controller:5000
  auth_url = http://controller:35357
  auth_type = password
  project_domain_id = default
  user_domain_id = default
  project_name = service
  username = manila
  password = Welcome123

  [oslo_concurrency]
  lock_path = /var/lock/manila
  ```

## 4.3. Trên host Controller, dùng lệnh sau để kiểm tra các service manila
  ```sh
  manila service-list
  ```

  Kết quả:
  ```sh
  +----+------------------+----------------------+------+---------+-------+----------------------------+
  | Id | Binary           | Host                 | Zone | Status  | State | Updated_at                 |
  +----+------------------+----------------------+------+---------+-------+----------------------------+
  | 1  | manila-scheduler | controller           | nova | enabled | up    | 2017-11-27T09:42:36.000000 |
  | 2  | manila-share     | manila@cephfsnative1 | nova | enabled | up    | 2017-11-27T09:41:48.000000 |
  | 3  | manila-share     | manila@generic       | nova | enabled | up    | 2017-11-27T09:41:48.000000 |
  | 4  | manila-share     | manila@lvm           | nova | enabled | up    | 2017-11-27T09:41:45.000000 |
  +----+------------------+----------------------+------+---------+-------+----------------------------+
  


# Thực hiện tích hợp Manila & Ceph
# 5. Thực hiện trên host Ceph Mon
## 5.1. Thêm quyền cho user `client.manila`
```sh
read -d '' MON_CAPS << EOF
allow r,
allow command "auth del",
allow command "auth caps",
allow command "auth get",
allow command "auth get-or-create"
EOF
```

```sh
ceph auth get-or-create client.manila -o /etc/ceph/manila.keyring \
mds 'allow *' \
osd 'allow rw' \
mon "$MON_CAPS"
```

## 5.2. Chuyển manila.keyring và ceph.conf sang host manila
```sh
scp ceph.conf manila.keyring manila:/etc/ceph
```

# 6. Thực hiện trên host Manila
## 6.1. Cài đặt ceph-common
 - Cài đặt repo

	```sh
	wget -q -O- 'https://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' | sudo apt-key add -
	```
	Kết quả: `OK`

	```sh
	echo deb http://download.ceph.com/debian-luminous/ trusty main | sudo tee /etc/apt/sources.list.d/ceph.list
	```
- Cập nhật các gói phần mềm

	```sh
	apt-get -y update
	```
- Cài đặt `ceph-common` package
	```sh
	apt-get install ceph-common -y
  ```

## 6.2. Chỉnh sửa file `/etc/ceph/ceph.conf`
```sh
vim /etc/ceph/ceph.conf
[client.manila]
client mount uid = 0
client mount gid = 0
log file = /var/log/ceph/ceph-client.manila.log
admin socket = /var/run/ceph/ceph-$name.$pid.asok
keyring = /etc/ceph/manila.keyring
```

# 6.3. Chỉnh sửa file `/etc/manila/manila.conf`
```sh
enabled_share_protocols = NFS,CIFS,CEPHFS

[cephfsnative1]
driver_handles_share_servers = False
share_backend_name = CEPHFSNATIVE1
share_driver = manila.share.drivers.cephfs.driver.CephFSDriver
cephfs_conf_path = /etc/ceph/ceph.conf
cephfs_protocol_helper_type = CEPHFS
cephfs_auth_id = manila
cephfs_cluster_name = ceph
cephfs_enable_snapshots = false

enabled_share_backends = generic1, cephfsnative1
```


# 6.4. Kiểm tra
```sh
manila service-list
+----+------------------+----------------------+------+---------+-------+----------------------------+
| Id | Binary           | Host                 | Zone | Status  | State | Updated_at                 |
+----+------------------+----------------------+------+---------+-------+----------------------------+
| 1  | manila-scheduler | controller           | nova | enabled | up    | 2017-11-12T03:31:46.000000 |
| 2  | manila-share     | manila@cephfsnative1 | nova | enabled | up    | 2017-11-12T03:31:45.000000 |
+----+------------------+----------------------+------+---------+-------+----------------------------+
```

# 6.5. Tạo shareFS type
```sh
manila type-create cephfsnativetype false
manila type-key cephfsnativetype set vendor_name=Ceph storage_protocol=CEPHFS
```

# 6.6. Tạo shareFS có kích thước 1GB
```sh
manila create --share-type cephfsnativetype --name cephnativeshare1 cephfs 1
+---------------------------------------+--------------------------------------+
| Property                              | Value                                |
+---------------------------------------+--------------------------------------+
| status                                | creating                             |
| share_type_name                       | cephfsnativetype                     |
| description                           | None                                 |
| availability_zone                     | None                                 |
| share_network_id                      | None                                 |
| share_server_id                       | None                                 |
| share_group_id                        | None                                 |
| host                                  |                                      |
| revert_to_snapshot_support            | False                                |
| access_rules_status                   | active                               |
| snapshot_id                           | None                                 |
| create_share_from_snapshot_support    | False                                |
| is_public                             | False                                |
| task_state                            | None                                 |
| snapshot_support                      | False                                |
| id                                    | 704f9f19-686f-4bc2-8771-850f1ba18e7b |
| size                                  | 1                                    |
| source_share_group_snapshot_member_id | None                                 |
| user_id                               | af6f231daa524fb8bac9409ec469c921     |
| name                                  | cephnativeshare1                     |
| share_type                            | 576985e6-3571-4b09-8e9c-742f1772cead |
| has_replicas                          | False                                |
| replication_type                      | None                                 |
| created_at                            | 2017-11-12T03:09:13.000000           |
| share_proto                           | CEPHFS                               |
| mount_snapshot_support                | False                                |
| project_id                            | 7ad8a1c31cad414cbe36229f9bc88301     |
| metadata                              | {}                                   |
+---------------------------------------+--------------------------------------+
```

```sh
manila share-export-location-list cephnativeshare1
+--------------------------------------+-------------------------------------------------------------------------+-----------+
| ID                                   | Path                                                                    | Preferred |
+--------------------------------------+-------------------------------------------------------------------------+-----------+
| f10556f1-1e9e-43a6-b59b-65c7325cad98 | 10.10.10.75:6789:/volumes/_nogroup/3964d311-1bc6-4e63-bbc7-3dea8a99f2e9 | False     |
+--------------------------------------+-------------------------------------------------------------------------+-----------+
```

Allow access to CephFS native share
```sh
manila access-allow cephnativeshare1 cephx longlq
+--------------+--------------------------------------+
| Property     | Value                                |
+--------------+--------------------------------------+
| access_key   | None                                 |
| share_id     | 3eccea14-d2e3-48ac-8010-1691d69fb315 |
| created_at   | 2017-11-12T03:53:26.000000           |
| updated_at   | None                                 |
| access_type  | cephx                                |
| access_to    | longlq                               |
| access_level | rw                                   |
| state        | queued_to_apply                      |
| id           | ebce9ebe-4a45-4985-acb1-2fb66092b648 |
+--------------+--------------------------------------+
```

Lenh nay tuong duong voi lenh:
```sh
ceph --name=client.manila --keyring=/etc/ceph/manila.keyring auth \
get-or-create client.longlq -o longlq.keyring
```



```sh
manila access-list cephnativeshare1
+--------------------------------------+-------------+-----------+--------------+--------+------------------------------------------+----------------------------+----------------------------+
| id                                   | access_type | access_to | access_level | state  | access_key                               | created_at                 | updated_at                 |
+--------------------------------------+-------------+-----------+--------------+--------+------------------------------------------+----------------------------+----------------------------+
| ebce9ebe-4a45-4985-acb1-2fb66092b648 | cephx       | longlq    | rw           | active | AQC3xQda3brFCxAAcoGdpTewNYKPmFn6RlzaXQ== | 2017-11-12T03:53:26.000000 | 2017-11-12T03:53:25.000000 |
+--------------------------------------+-------------+-----------+--------------+--------+------------------------------------------+----------------------------+----------------------------+
```


# 7. Kiểm tra trên VM (Test tren 1 VM bat ky da cai ceph-fuse)
Tao /etc/ceph/longlq.keyring
```sh

[client.longlq]
        key = AQC3xQda3brFCxAAcoGdpTewNYKPmFn6RlzaXQ==

vim ceph.conf
[client]
        client quota = true
        mon host = 10.10.10.75:6789
```
```sh
mount -t ceph 10.10.10.75:6789:/volumes/_nogroup/3964d311-1bc6-4e63-bbc7-3dea8a99f2e9 /root/test -o name=longlq,secretfile=/etc/ceph/longlq.keyring

ceph-fuse --keyring=/etc/ceph/longlq.keyring -n client.longlq --client-mountpoint=/volumes/_nogroup/3964d311-1bc6-4e63-bbc7-3dea8a99f2e9  /root/test
```







