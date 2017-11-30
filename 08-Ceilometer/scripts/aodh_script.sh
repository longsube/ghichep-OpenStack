#!/bin/bash -ex
source lib/functions.sh
source config.cfg

cat << EOF | mysql -u root -p$MYSQL_PASS
CREATE DATABASE aodh;
GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'localhost' IDENTIFIED BY '$AODH_DBPASS';
GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'%' IDENTIFIED BY '$AODH_DBPASS';
flush privileges;
EOF

source /usr/share/admin-openrc
## Create user, end point and assign role for Ceilometer


openstack user create --domain default --password $AODH_PASS aodh 
openstack role add --project service --user aodh admin 
openstack service create --name aodh --description "Telemetry" alarming 

openstack endpoint create --region $REGION  alarming public http://$VIP_MGNT_IP:8042 
openstack endpoint create --region $REGION  alarming internal http://$VIP_MGNT_IP:8042
openstack endpoint create --region $REGION  alarming admin http://$VIP_MGNT_IP:8042 

# Install ceilometer dependencies
apt-get install aodh-api aodh-evaluator aodh-notifier \
  aodh-listener aodh-expirer python-ceilometerclient -y

echocolor "Config aodh"
sleep 5

aodh_ctl=/etc/aodh/aodh.conf
test -f $aodh_ctl.orig || cp $aodh_ctl $aodh_ctl.orig

## [DEFAULT] section
ops_edit $aodh_ctl DEFAULT rpc_backend rabbit
ops_edit $aodh_ctl DEFAULT auth_strategy keystone

## [database] section
ops_edit $aodh_ctl database connection mysql+pymysql://aodh:$AODH_DBPASS@$VIP_MGNT_IP/aodh

## [keystone_authtoken] section
ops_edit $aodh_ctl keystone_authtoken auth_uri http://$VIP_MGNT_IP:5000
ops_edit $aodh_ctl keystone_authtoken auth_url http://$VIP_MGNT_IP:35357
#ops_edit $aodh_ctl keystone_authtoken insecure True
#ops_edit $aodh_ctl keystone_authtoken auth_protocol https
ops_edit $aodh_ctl keystone_authtoken memcached_servers  $CTL1_MGNT_IP:11211,$CTL2_MGNT_IP:11211,$CTL3_MGNT_IP:11211
ops_edit $aodh_ctl keystone_authtoken auth_type password
ops_edit $aodh_ctl keystone_authtoken project_domain_name default
ops_edit $aodh_ctl keystone_authtoken user_domain_name default
ops_edit $aodh_ctl keystone_authtoken project_name service
ops_edit $aodh_ctl keystone_authtoken username aodh
ops_edit $aodh_ctl keystone_authtoken password $AODH_PASS


## [service_credentials] section
ops_edit $aodh_ctl service_credentials auth_type  password
ops_edit $aodh_ctl service_credentials auth_url http://$VIP_MGNT_IP:5000/v3
#ops_edit $aodh_ctl service_credentials insecure True
#ops_edit $aodh_ctl service_credentials auth_protocol https
ops_edit $aodh_ctl service_credentials project_domain_name  default
ops_edit $aodh_ctl service_credentials user_domain_name  default
ops_edit $aodh_ctl service_credentials project_name  service
ops_edit $aodh_ctl service_credentials username aodh
ops_edit $aodh_ctl service_credentials password $AODH_PASS
ops_edit $aodh_ctl service_credentials interface internalURL
ops_edit $aodh_ctl service_credentials region_name $REGION


## [oslo_messaging_rabbit] section
ops_edit $aodh_ctl oslo_messaging_rabbit rabbit_host $CTL1_MGNT_IP:5672,$CTL2_MGNT_IP:5672,$CTL3_MGNT_IP:5672
ops_edit $aodh_ctl oslo_messaging_rabbit rabbit_userid openstack
ops_edit $aodh_ctl oslo_messaging_rabbit rabbit_password $RABBIT_PASS


echocolor "Config api_paster.ini"
sleep 5
api_paste=/etc/aodh/api_paste.ini
test -f $api_paste.orig || cp $api_paste $api_paste.orig

ops_edit $api_paste filter:authtoken oslo_config_project aodh

echocolor "DBSync"
sleep 3
su -s /bin/sh -c "aodh-dbsync" aodh


echocolor "Config ceilometer"
sleep 5
ceilometer_ctl=/etc/ceilometer/ceilometer.conf
test -f $ceilometer_ctl.orig || cp $ceilometer_ctl $ceilometer_ctl.orig

ops_edit $ceilometer_ctl DEFAULT event_pipeline_cfg_file event_pipeline.yaml
ops_edit $ceilometer_ctl DEFAULT pipeline_cfg_file  pipeline.yaml
ops_edit $ceilometer_ctl DEFAULT pipeline_polling_interval  20
ops_edit $ceilometer_ctl DEFAULT event_alarm_topic  alarm.all
ops_edit $ceilometer_ctl DEFAULT evaluation_interval  60
ops_edit $ceilometer_ctl DEFAULT alarm_max_actions  -1

ops_edit $ceilometer_ctl api aodh_is_enabled  True
ops_edit $ceilometer_ctl api host  0.0.0.0
ops_edit $ceilometer_ctl api port 8777
ops_edit $ceilometer_ctl api workers  1

ops_edit $ceilometer_ctl event definitions_cfg_file  event_definitions.yaml

ops_edit $ceilometer_ctl notification store_events  true
ops_edit $ceilometer_ctl notification workers  1

echocolor "Restart service" 
sleep 3
cd /etc/init/; for i in $(ls ceilometer-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done
cd /etc/init/; for i in $(ls aodh-* | cut -d \. -f 1 | xargs); do sudo service $i restart; done

ceilometer  event-list
ceilometer  event-type-list
ceilometer alarm-list