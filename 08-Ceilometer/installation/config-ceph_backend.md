# Cấu hình Ceph làm Storage cho Gnocchi
## 1. Trên Ceph Cluster
### 1.1. Tạo pool metrics
```
ceph osd pool create metrics 128
```
### 1.2. Tạo user gnocchi và cấp quyền trên pool metrics
```
ceph auth get-or-create client.gnocchi mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=metrics'
```
### 1.3. Copy key sang node Gnocchi-api
```
ceph auth get-or-create client.gnocchi | ssh [gnocchi-api-server] sudo tee /etc/ceph/ceph.client.gnocchi.keyring
ssh [gnocchi-api-server] sudo chown gnocchi:gnocchi /etc/ceph/ceph.client.gnocchi.keyring
```

## 2. Trên node Gnocchi 
### 2.1. Cấu hình Gnocchi sử dụng Ceph
```
vim /etc/gnocchi/gnocchi.conf
...
[storage]
driver = ceph
ceph_pool = metrics
ceph_username = gnocchi
ceph_keyring = /etc/ceph/ceph.client.gnocchi.keyring
ceph_conffile = /etc/ceph/ceph.conf
```

### 2.2. Khởi động lại dịch vụ
```
cd /etc/init/; for i in $(ls ceilometer-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
cd /etc/init/; for i in $(ls gnocchi-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
```