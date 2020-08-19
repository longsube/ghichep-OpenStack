#!/bin/bash
#===============================================================================
#
#          FILE:  install_manila.sh
# 
#         USAGE:  ./install_manila.sh 
# 
#   DESCRIPTION:  Config OpenStack Manila Service
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Truong Thanh Ha (), truongthanhha@vnpt.vn
#       COMPANY:  VNPT
#       VERSION:  1.0
#       CREATED:  13/11/2018 04:22:34 PM ICT
#      REVISION:  ---
#===============================================================================

source $(dirname $0)/functions.sh
source $(dirname $0)/../config.cfg


function create_db ()
{
    echocolor "Create Database for Manila"
    sleep 5
    cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE manila;
GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'localhost' IDENTIFIED BY '$MANILA_DBPASS'
GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'%' IDENTIFIED BY '$MANILA_DBPASS'"
FLUSH PRIVILEGES;
EOF

}    # ----------  end of function create_db  ----------



function install_package ()
{
    echocolor "Install Manila package"
    sleep 5
    run_command apt-get install manila-api manila-scheduler python-manilaclient manila-share python-pymysql -y

}    # ----------  end of function install_package  ----------


function create_project ()
{
    echocolor "Creating Manila Endpoint"
    sleep 5
    source /usr/share/admin-openrc

    echocolor "Create info for Manila user && Shared File Systems"
	sleep 3
	openstack user create  --domain default --password $MANILA_PASS manila
    openstack role add --project service --user manila admin
	openstack service create --name manila --description "OpenStack Shared File Systems" share
	
    openstack endpoint create --region $1 share public http://$2:8786/v1/%\(tenant_id\)s
    openstack endpoint create --region $1 share internal http://$2:8786/v1/%\(tenant_id\)s
    openstack endpoint create --region $1 share admin http://$2:8786/v1/%\(tenant_id\)s
    	
	echocolor "Create Shared File Systems v2"
	sleep 3
	openstack service create --name manilav2 --description "OpenStack Shared File Systems V2" sharev2
	
	openstack endpoint create --region $1 sharev2 public http://$2:8786/v2/%\(tenant_id\)s  
    openstack endpoint create --region $1 sharev2 internal http://$2:8786/v2/%\(tenant_id\)s
    openstack endpoint create --region $1 sharev2 admin http://$2:8786/v2/%\(tenant_id\)s
	

}    # ----------  end of function create_project  ----------



function config_manila ()
{

    manila_ctl=/etc/manila/manila.conf
    test -f $manila_ctl.orig || cp $manila_ctl $manila_ctl.orig

    echocolor "Config file manila.conf"
    sleep 5
	
	ops_edit $manila_ctl DEFAULT host $CONTROLLER_SHARE
	ops_edit $manila_ctl DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL1_MGNT_IP:5672,openstack:$RABBIT_PASS@$CTL2_MGNT_IP:5672,openstack:$RABBIT_PASS@$CTL3_MGNT_IP:5672
	ops_edit $manila_ctl DEFAULT default_share_type default_share_type
	ops_edit $manila_ctl DEFAULT share_name_template share-%s
	ops_edit $manila_ctl DEFAULT rootwrap_config /etc/manila/rootwrap.conf
	ops_edit $manila_ctl DEFAULT api_paste_config /etc/manila/api-paste.ini
	ops_edit $manila_ctl DEFAULT auth_strategy keystone
	ops_edit $manila_ctl DEFAULT my_ip $1
	ops_edit $manila_ctl DEFAULT enabled_share_backends generic
	ops_edit $manila_ctl DEFAULT enabled_share_protocols NFS
	ops_edit $manila_ctl DEFAULT driver_handles_share_servers True

	ops_edit $manila_ctl database connection mysql+pymysql://manila:$MANILA_DBPASS@$VIP_MGNT_IP/manila

	ops_edit $manila_ctl keystone_authtoken memcached_servers $CTL1_MGNT_IP:11211,$CTL2_MGNT_IP:11211,$CTL3_MGNT_IP:11211
	ops_edit $manila_ctl keystone_authtoken auth_uri http://$VIP_MGNT_IP:5000
	ops_edit $manila_ctl keystone_authtoken auth_url http://$VIP_MGNT_IP:5000
	ops_edit $manila_ctl keystone_authtoken auth_type password
	ops_edit $manila_ctl keystone_authtoken project_domain_name default
	ops_edit $manila_ctl keystone_authtoken user_domain_name default
	ops_edit $manila_ctl keystone_authtoken project_name service
	ops_edit $manila_ctl keystone_authtoken username manila
	ops_edit $manila_ctl keystone_authtoken  password $MANILA_PASS

	ops_edit $manila_ctl neutron url http://$VIP_MGNT_IP:9696
	ops_edit $manila_ctl neutron auth_uri http://$VIP_MGNT_IP:5000
	ops_edit $manila_ctl neutron auth_url http://$VIP_MGNT_IP:5000
	ops_edit $manila_ctl neutron memcached_servers $CTL1_MGNT_IP:11211,$CTL2_MGNT_IP:11211,$CTL3_MGNT_IP:11211
	ops_edit $manila_ctl neutron auth_type password
	ops_edit $manila_ctl neutron project_domain_name default
	ops_edit $manila_ctl neutron user_domain_name default
	ops_edit $manila_ctl neutron region_name $REGION
	ops_edit $manila_ctl neutron project_name service
	ops_edit $manila_ctl neutron username neutron
	ops_edit $manila_ctl neutron password $NEUTRON_PASS

	ops_edit $manila_ctl nova auth_uri http://$VIP_MGNT_IP:5000
	ops_edit $manila_ctl nova auth_url http://$VIP_MGNT_IP:35357
	ops_edit $manila_ctl nova memcached_servers $CTL1_MGNT_IP:11211,$CTL2_MGNT_IP:11211,$CTL3_MGNT_IP:11211
	ops_edit $manila_ctl nova auth_type password
	ops_edit $manila_ctl nova project_domain_name default
	ops_edit $manila_ctl nova user_domain_name default
	ops_edit $manila_ctl nova region_name $REGION
	ops_edit $manila_ctl nova project_name service
	ops_edit $manila_ctl nova username nova
	ops_edit $manila_ctl nova password $NOVA_PASS

	ops_edit $manila_ctl cinder auth_uri http://$VIP_MGNT_IP:5000
	ops_edit $manila_ctl cinder auth_url http://$VIP_MGNT_IP:35357
	ops_edit $manila_ctl cinder memcached_servers $CON1_IP:11211
	ops_edit $manila_ctl cinder auth_type password
	ops_edit $manila_ctl cinder project_domain_name default
	ops_edit $manila_ctl cinder user_domain_name default
	ops_edit $manila_ctl cinder region_name $REGION
	ops_edit $manila_ctl cinder project_name service
	ops_edit $manila_ctl cinder username cinder
	ops_edit $manila_ctl cinder password $CINDER_PASS

	ops_edit $manila_ctl generic share_backend_name GENERIC
	ops_edit $manila_ctl generic share_driver manila.share.drivers.generic.GenericShareDriver
	ops_edit $manila_ctl generic driver_handles_share_servers True
	ops_edit $manila_ctl generic service_instance_flavor_id $SERVICE_INSTANCE_FLAVOR_ID
	ops_edit $manila_ctl generic service_image_name $SERVICE_IMAGE_NAME
	ops_edit $manila_ctl generic service_instance_user $SERVICE_INSTANCE_USER
	ops_edit $manila_ctl generic service_instance_password $SERVICE_INSTANCE_PASSWORD
	ops_edit $manila_ctl generic interface_driver manila.network.linux.interface.OVSInterfaceDriver
	


    echocolor "Remove Manila default db "
    sleep 5
    rm -f /var/lib/manila/manila.sqlite

}    # ----------  end of function api  ----------



function dbsync ()
{
    echocolor "Syncing Manila DB"
    sleep 5
	su -s /bin/sh -c "manila-manage db sync" manila


}    # ----------  end of function dbsync  ----------



function restart_services ()
{
    echocolor "Restarting Manila service ..."
    sleep 5
    service manila-scheduler restart
    service manila-api restart
    service manila-share restart

}    # ----------  end of function restart_services  ----------



function verify ()
{
    echocolor "Verify Manila Service"
    sleep 20
    source /usr/share/admin-openrc
    manila service-list

}    # ----------  end of function verify  ----------



function upload_image ()
{


    echocolor "Upload  Manila IMAGE "
    sleep 3
	source /usr/share/admin-openrc

    mkdir images_manila
    cd images_manila /
    wget http://tarballs.openstack.org/manila-image-elements/images/manila-service-image-master.qcow2
	
	echocolor "Convert Image from qcow2 to raw. Please wait..."
	qemu-img convert -f qcow2 -O raw manila-service-image-master.qcow2 manila-service-image-master.raw

	echocolor "Upload image. It's take few minutes. Please wait..."

    openstack image create "manila-service-image"  --file manila-service-image-master.raw \
    --disk-format raw --container-format bare \
    --public

    openstack image list
}    # ----------  end of function verify  ----------


if [ $# -eq 1 ]; then
    echocolor "Config OpenStack Nova Services on $1"
    sleep 5
    create_db
    create_project "$REGION" "$VIP_MGNT_IP"
	upload_image
    install_package
    config_manila "$CTL1_MGNT_IP"
    dbsync
    restart_services
    verify 
else
    echocolor "Config OpenStack Nova Services"
    sleep 5
    install_package
    hostname=`cat /etc/hostname`
    if [[ "$hostname" == controller2* ]]; then
        config_manila "$CTL2_MGNT_IP"
    elif [[ "$hostname" == controller3* ]]; then
        config_manila "$CTL3_MGNT_IP"
    fi
    rm /var/lib/manila/manila.sqlite
    restart_services
    verify
fi
