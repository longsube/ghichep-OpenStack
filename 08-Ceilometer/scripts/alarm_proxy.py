#!/usr/bin/python
from flask import Flask, request
import requests
import json
import logging
app = Flask(__name__)


logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO)
loger = logging.getLogger(__name__)

@app.route("/image", methods=['POST'])
def alarm_image():
    traits = json.loads(request.data)['reason_data']['event']['traits']
    try:
        name=filter(lambda x: x[0] == 'name', traits)[0][-1]
        resource_id=filter(lambda x: x[0] == 'resource_id', traits)[0][-1]
        time_update=filter(lambda x: x[0] == 'created_at', traits)[0][-1]
        notify='''
            *UPDATE IMAGE SUCCESSFULLY*
        IMAGE_NAME: `{0}`
        IMAGE_ID: `{1}`
        TIME_UPDATE: `{2}`
            '''.format(name, resource_id, time_update)
        json_payload = {
                "text" : notify,
                "channel" : "#vsc-channel-demo",
                "username" : "incoming-webhook Bot",
                #"icon_emoji" : ":computer:"
        }

        headers = {'content-type': 'application/json', 'accept': 'application'}
        requests.post(url='https://hooks.slack.com/services/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',
                                       data=json.dumps(json_payload),
                                       headers=headers)
    except Exception as e:
          loger.critical(e)
    return "Image job was started"



@app.route("/volume", methods=['POST'])
def alarm_volume():
    traits = json.loads(request.data)['reason_data']['event']['traits']
    try:
        name=filter(lambda x: x[0] == 'display_name', traits)[0][-1]
        size=filter(lambda x: x[0] == 'size', traits)[0][-1]
        status=str(filter(lambda x: x[0] == 'status', traits)[0][-1])
        host=filter(lambda x: x[0] == 'host', traits)[0][-1]
        user_id=filter(lambda x: x[0] == 'user_id', traits)[0][-1]
        tenant_id=filter(lambda x: x[0] == 'tenant_id', traits)[0][-1]
        created_at=filter(lambda x: x[0] == 'created_at', traits)[0][-1]
        notify='''
            *VOLUME {0}*
        VOLUME_NAME: `{1}`
        SIZE: `{2}` GB
        STATUS: `{3}`
        HOST: `{4}`
        USER_ID: `{5}`
        TENANT_ID: `{6}`
        {7}_AT: `{8}`
            '''.format(str.upper(status), name, size, status, host, user_id, tenant_id, str.upper(status), created_at)
        json_payload = {
                "text" : notify,
                "channel" : "#vsc-channel-demo",
                "username" : "incoming-webhook Bot",
                #"icon_emoji" : ":computer:"
        }

        headers = {'content-type': 'application/json', 'accept': 'application'}
        requests.post(url='https://hooks.slack.com/services/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',
                                       data=json.dumps(json_payload),
                                       headers=headers)



    except Exception as e:
          loger.critical(e)
    return "Volume job was started"
  #  print traits
  #  return lol

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5123)
