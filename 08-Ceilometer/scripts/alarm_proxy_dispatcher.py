#!/usr/bin/python
from flask import Flask, request
import requests
import json
import logging
import send_mail
app = Flask(__name__)


logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO)
loger = logging.getLogger(__name__)

@app.route("/event", methods=['POST'])
def alarm_vm():
    event_type =  json.loads(request.data)['event_type']
    traits = json.loads(request.data)['traits']
    print traits
    status=None
    try:
        name=filter(lambda x: x[0] == 'display_name', traits)[0][-1]
        type=filter(lambda x: x[0] == 'instance_type', traits)[0][-1]
        host=filter(lambda x: x[0] == 'host', traits)[0][-1]
        user_id=filter(lambda x: x[0] == 'user_id', traits)[0][-1]
        tenant_id=filter(lambda x: x[0] == 'tenant_id', traits)[0][-1]
        instance_id=filter(lambda x: x[0] == 'instance_id', traits)[0][-1]
        if 'compute.instance.create.end' in event_type:
            status='create'
            subject='[SCV-MyCloudVNN]: Instance Create'
        elif 'compute.instance.delete.end' in event_type:
            status='delete'
            subject='[SCV-MyCloudVNN]: Instance Delete'
        if status != None:
            body='''
                *INSTANCE  {0}*
            VM_NAME: {1}
            VM_ID: {2}
            TYPE: {3}
            HOST: {4}
            USER_ID: {5}
            TENANT_ID: {6}
                '''.format(str.upper(status), name, instance_id, type, host, user_id, tenant_id)

            send_mail.send_mail(subject,body)
    except Exception as e:
          loger.critical(e)
    return "VM job was started"

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5123)


