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