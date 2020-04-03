CTL:

## 1. Mô hình cài đặt
- Mô hình cài đặt Lab OPS Pike trên Ubuntu 16.04 64-bit
  
  ![](../images/manila.jpg)
  
<a name=2></a>
## 2. IP Planning
- Phân hoạch địa chỉ Ip và yêu cầu phần cứng

  ![](../images/ip_pike.png)
  
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
  ```












MANILA:



 





CEPH1:
read -d '' MON_CAPS << EOF
allow r,
allow command "auth del",
allow command "auth caps",
allow command "auth get",
allow command "auth get-or-create"
EOF

ceph auth get-or-create client.manila -o /etc/ceph/manila.keyring \
mds 'allow *' \
osd 'allow rw' \
mon "$MON_CAPS"

Chuyen manila.keyring va ceph.conf sang host manila

scp ceph.conf manila.keyring manila:/etc/ceph


MANILA:
#### 4.1. Cài đặt ceph-common
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

vim /etc/ceph/ceph.conf
[client.manila]
client mount uid = 0
client mount gid = 0
log file = /var/log/ceph/ceph-client.manila.log
admin socket = /var/run/ceph/ceph-$name.$pid.asok
keyring = /etc/ceph/manila.keyring


vim /etc/manila/manila.conf
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



CTL:
vim /etc/manila/manila.conf
enabled_share_protocols = NFS,CIFS,CEPHFS

manila service-list
+----+------------------+----------------------+------+---------+-------+----------------------------+
| Id | Binary           | Host                 | Zone | Status  | State | Updated_at                 |
+----+------------------+----------------------+------+---------+-------+----------------------------+
| 1  | manila-scheduler | controller           | nova | enabled | up    | 2017-11-12T03:31:46.000000 |
| 2  | manila-share     | manila@cephfsnative1 | nova | enabled | up    | 2017-11-12T03:31:45.000000 |
+----+------------------+----------------------+------+---------+-------+----------------------------+


manila type-create cephfsnativetype false
manila type-key cephfsnativetype set vendor_name=Ceph storage_protocol=CEPHFS

Tao share co kich thuoc 1GB
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

manila share-export-location-list cephnativeshare1
+--------------------------------------+-------------------------------------------------------------------------+-----------+
| ID                                   | Path                                                                    | Preferred |
+--------------------------------------+-------------------------------------------------------------------------+-----------+
| f10556f1-1e9e-43a6-b59b-65c7325cad98 | 10.10.10.75:6789:/volumes/_nogroup/3964d311-1bc6-4e63-bbc7-3dea8a99f2e9 | False     |
+--------------------------------------+-------------------------------------------------------------------------+-----------+


Allow access to CephFS native share
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


Lenh nay tuong duong voi lenh:
ceph --name=client.manila --keyring=/etc/ceph/manila.keyring auth \
get-or-create client.longlq -o longlq.keyring



root@controller:~# manila access-list cephnativeshare1
+--------------------------------------+-------------+-----------+--------------+--------+------------------------------------------+----------------------------+----------------------------+
| id                                   | access_type | access_to | access_level | state  | access_key                               | created_at                 | updated_at                 |
+--------------------------------------+-------------+-----------+--------------+--------+------------------------------------------+----------------------------+----------------------------+
| ebce9ebe-4a45-4985-acb1-2fb66092b648 | cephx       | longlq    | rw           | active | AQC3xQda3brFCxAAcoGdpTewNYKPmFn6RlzaXQ== | 2017-11-12T03:53:26.000000 | 2017-11-12T03:53:25.000000 |
+--------------------------------------+-------------+-----------+--------------+--------+------------------------------------------+----------------------------+----------------------------+

Test tren VM



Test tren 1 host client bat ky da cai ceph-fuse

Tao /etc/ceph/longlq.keyring
[client.longlq]
        key = AQC3xQda3brFCxAAcoGdpTewNYKPmFn6RlzaXQ==

vim ceph.conf
[client]
        client quota = true
        mon host = 10.10.10.75:6789

mount -t ceph 10.10.10.75:6789:/volumes/_nogroup/3964d311-1bc6-4e63-bbc7-3dea8a99f2e9 /root/test -o name=longlq,secretfile=/etc/ceph/longlq.keyring

ceph-fuse --keyring=/etc/ceph/longlq.keyring -n client.longlq --client-mountpoint=/volumes/_nogroup/3964d311-1bc6-4e63-bbc7-3dea8a99f2e9  /root/test





GENERIC DRIVER:

MANILA:
apt-get install neutron-plugin-linuxbridge-agent

vim /etc/manila/manila.conf

[DEFAULT]
...
enabled_share_backends = generic
enabled_share_protocols = NFS

[neutron]
...
url = http://controller:9696
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = Welcome123

[nova]
...
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = Welcome123

[cinder]
...
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = cinder
password = Welcome123

[generic]
share_backend_name = GENERIC
share_driver = manila.share.drivers.generic.GenericShareDriver
driver_handles_share_servers = True
service_instance_flavor_id = 100
service_image_name = manila-service-image
service_instance_user = manila
service_instance_password = manila
interface_driver = manila.network.linux.interface.BridgeInterfaceDriver

wget http://tarballs.openstack.org/manila-image-elements/images/manila-service-image-master.qcow2

openstack image create "manila-service-image" \
--file manila-service-image-master.qcow2 \
--disk-format qcow2 \
--container-format bare \
--public

openstack flavor create manila-service-flavor --id 100 --ram 256 --disk 0 --vcpus 1

openstack image list

manila type-create generic True

manila type-key generic set share_backend_name=GENERIC

neutron net-list
+--------------------------------------+-------------+----------------------------------+-----------------------------------------------------+
| id                                   | name        | tenant_id                        | subnets                                             |
+--------------------------------------+-------------+----------------------------------+-----------------------------------------------------+
| 30be2092-c9c2-4016-a3df-a0e9acf55467 | ext_net     | 7ad8a1c31cad414cbe36229f9bc88301 | 0fb050f3-c15f-4df7-b74a-dfd5317a6063 172.16.69.0/24 || e21800f7-96a0-4beb-a169-95ad399703ec | private_net | 7ad8a1c31cad414cbe36229f9bc88301 | 9c7960cb-c6ef-4bf1-b394-ec329f535c93 20.20.20.0/24  |
+--------------------------------------+-------------+----------------------------------+-----------------------------------------------------+
Với Share-network ta sẽ cần net-id và subnet-id private của project.
Mình đang ở project admin do vậy sẽ lấy subnet và net id của admin là dải `private-net`

manila share-network-create --name share-net-admin --neutron-subnet-id 9c7960cb-c6ef-4bf1-b394-ec329f535c93 --neutron-net-id e21800f7-96a0-4beb-a169-95ad399703ec

+-------------------+--------------------------------------+
| Property          | Value                                |
+-------------------+--------------------------------------+
| network_type      | None                                 |
| name              | share-net-admin                      |
| segmentation_id   | None                                 |
| created_at        | 2017-11-12T11:35:11.479471           |
| neutron_subnet_id | 9c7960cb-c6ef-4bf1-b394-ec329f535c93 |
| updated_at        | None                                 |
| mtu               | None                                 |
| gateway           | None                                 |
| neutron_net_id    | e21800f7-96a0-4beb-a169-95ad399703ec |
| ip_version        | None                                 |
| cidr              | None                                 |
| project_id        | 7ad8a1c31cad414cbe36229f9bc88301     |
| id                | 79579473-fc17-4340-875c-12f73da5bb71 |
| description       | None                                 |
+-------------------+--------------------------------------+

manila create --share-type generic --name share-02  --share-network share-net-admin  nfs 1
manila create --share-type lvm --name share-lvm nfs 4 


manila show share-01
+---------------------------------------+----------------------------------------------------------------------+
| Property                              | Value                                                                |
+---------------------------------------+----------------------------------------------------------------------+
| status                                | available                                                            |
| share_type_name                       | generic                                                              |
| description                           | None                                                                 |
| availability_zone                     | nova                                                                 |
| share_network_id                      | 3267b2ad-3363-415c-ab45-ff83ac4ad2e7                                 |
| export_locations                      |                                                                      |
|                                       | path = 10.254.0.5:/shares/share-ee8315bf-14bd-4f80-a158-71978f4fab39 |
|                                       | preferred = False                                                    |
|                                       | is_admin_only = False                                                |
|                                       | id = b069fdf2-3b90-409b-a837-949f1871cc5f                            |
|                                       | share_instance_id = ee8315bf-14bd-4f80-a158-71978f4fab39             |
|                                       | path = 10.254.0.5:/shares/share-ee8315bf-14bd-4f80-a158-71978f4fab39 |
|                                       | preferred = False                                                    |
|                                       | is_admin_only = True                                                 |
|                                       | id = e43ef971-c0f0-45cc-ac8d-12769c763ea7                            |
|                                       | share_instance_id = ee8315bf-14bd-4f80-a158-71978f4fab39             |
| share_server_id                       | 5c713092-301f-4af7-b59c-c72314a2c4d6                                 |
| share_group_id                        | None                                                                 |
| host                                  | manila@generic#GENERIC                                               |
| revert_to_snapshot_support            | False                                                                |
| access_rules_status                   | active                                                               |
| snapshot_id                           | None                                                                 |
| create_share_from_snapshot_support    | False                                                                |
| is_public                             | False                                                                |
| task_state                            | None                                                                 |
| snapshot_support                      | False                                                                |
| id                                    | 44d0bc96-84d7-44b6-9fe5-981a9e508637                                 |
| size                                  | 1                                                                    |
| source_share_group_snapshot_member_id | None                                                                 |
| user_id                               | af6f231daa524fb8bac9409ec469c921                                     |
| name                                  | share-01                                                             |
| share_type                            | 06ca8ed9-1153-4cad-b605-d4b6697f0da5                                 |
| has_replicas                          | False                                                                |
| replication_type                      | None                                                                 |
| created_at                            | 2017-11-12T17:31:17.000000                                           |
| share_proto                           | NFS                                                                  |
| mount_snapshot_support                | False                                                                |
| project_id                            | 7ad8a1c31cad414cbe36229f9bc88301                                     |
| metadata                              | {}                                                                   |
+---------------------------------------+----------------------------------------------------------------------+

cho phep may ao IP 20.20.20.108 mount FS
manila access-allow --access-level ro share-01 ip 20.20.20.108
manila access-list share-01
+--------------------------------------+-------------+---------------+--------------+---------+------------+----------------------------+------------+| id                                   | access_type | access_to     | access_level | state   | access_key | created_at                 | updated_at |
+--------------------------------------+-------------+---------------+--------------+---------+------------+----------------------------+------------+| 3a0dec44-cee0-422f-9565-0c5884df5b46 | ip          | 172.16.69.178 | rw           | active  | None       | 2017-11-12T17:44:30.000000 | None       |
| 60b9545d-2d1f-4ae9-9e72-d48cf44fff6e | ip          | 20.20.20.100  | rw           | denying | None       | 2017-11-13T02:50:09.000000 | None       || |+--------------------------------------+-------------+---------------+--------------+---------+------------+----------------------------+------------+



Các access list của share-01 được đặt trong VM share, ta có thể kiểm tra bằng cách ssh vào share VM, user:manila, pass:manila
cat /etc/exports 
/shares/share-ee8315bf-14bd-4f80-a158-71978f4fab39	172.16.69.178(rw,sync,wdelay,hide,nocrossmnt,secure,no_root_squash,no_all_squash,no_subtree_check,secure_locks,acl,anonuid=65534,anongid=65534,sec=sys,rw,no_root_squash,no_all_squash)
/shares/share-ee8315bf-14bd-4f80-a158-71978f4fab39	20.20.20.108(rw,sync,wdelay,hide,nocrossmnt,secure,no_root_squash,no_all_squash,no_subtree_check,secure_locks,acl,anonuid=65534,anongid=65534,sec=sys,rw,no_root_squash,no_all_squash)


tren may ao:
centos
yum install nfs-utils -y

ubuntu
apt-get install nfs-common -y

mount -t nfs 10.254.0.5:/shares/share-ee8315bf-14bd-4f80-a158-71978f4fab39 /mnt/

vim /etc/fstab
10.254.0.5:/shares/share-ee8315bf-14bd-4f80-a158-71978f4fab39 /mnt/ nfs rw,hard,intr,rsize=8192,wsize=8192,timeo=14 0 0

Tham khao:

[1] - https://docs.openstack.org/manila/pike/contributor/cephfs_driver.html

fixbug 'NetworkException: Unable to find 'security_group' in request body
2017-09-13 13:19:56.795 TRACE oslo_messag': https://review.openstack.org/#/c/518601/

khoi dong lai host manila se mat tat ca cau hinh linux bridge
sudo manila-rootwrap /etc/manila/rootwrap.conf ip link add tap74250790-48 type veth peer name ns-74250790-4$

fix: cat /etc/sudoers.d/manila_sudoers 
Defaults:manila !requiretty

manila ALL = (root) NOPASSWD: /usr/local/bin/manila-rootwrap /etc/manila/rootwrap.conf *


