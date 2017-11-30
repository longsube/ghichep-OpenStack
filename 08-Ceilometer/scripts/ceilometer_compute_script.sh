#!/bin/bash -ex
source config.cfg
source functions.sh


echocolor "Config Ceilometer Agent"
apt-get install -y ceilometer-agent-compute

echocolor "Config Ceilometer"
ceilometer_com=/etc/ceilometer/ceilometer.conf
test -f $ceilometer_com.orig || cp $ceilometer_com $ceilometer_com.orig

## [DEFAULT] section
ops_edit $ceilometer_com DEFAULT rpc_backend rabbit
ops_edit $ceilometer_com DEFAULT auth_strategy keystone
ops_edit $ceilometer_com DEFAULT instance_usage_audit = True
ops_edit $ceilometer_com DEFAULT instance_usage_audit_period = hour
ops_edit $ceilometer_com DEFAULT notify_on_state_change = vm_and_task_state
ops_edit $ceilometer_com DEFAULT notification_driver = messagingv2

## [keystone_authtoken] section
ops_edit $ceilometer_com keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $ceilometer_com keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
ops_edit $ceilometer_com keystone_authtoken auth_type password
ops_edit $ceilometer_com keystone_authtoken project_domain_id default
ops_edit $ceilometer_com keystone_authtoken user_domain_id default
ops_edit $ceilometer_com keystone_authtoken project_name service
ops_edit $ceilometer_com keystone_authtoken username ceilometer
ops_edit $ceilometer_com keystone_authtoken password $CEILOMETER_PASS


## [service_credentials] section
ops_edit $ceilometer_com service_credentials \
os_auth_url http://$CTL_MGNT_IP:5000/v2.0
ops_edit $ceilometer_com service_credentials os_username ceilometer
ops_edit $ceilometer_com service_credentials os_tenant_name service
ops_edit $ceilometer_com service_credentials os_password $CEILOMETER_PASS
ops_edit $ceilometer_com service_credentials os_endpoint_type internalURL
ops_edit $ceilometer_com service_credentials os_region_name RegionOne


## [oslo_messaging_rabbit] section
ops_edit $ceilometer_com oslo_messaging_rabbit rabbit_host $CTL_MGNT_IP
ops_edit $ceilometer_com oslo_messaging_rabbit rabbit_userid openstack
ops_edit $ceilometer_com oslo_messaging_rabbit rabbit_password $RABBIT_PASS

EOF

echocolor "Restart service"
sleep 3
service ceilometer-agent-compute restart
service nova-compute restart
