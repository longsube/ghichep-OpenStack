#!/usr/bin/python
from flask import Flask, request
import jenkins
import json

server = jenkins.Jenkins('http://172.16.69.48:8080',
                         username='admin',
                         password='287988')
app = Flask(__name__)

@app.route("/", methods=['POST'])
def jenkins():
    traits = json.loads(request.data)['reason_data']['event']['traits']
    data = {"NAME":
                filter(lambda x: x[0] == 'name', traits)[0][-1],
            "RESOURCE_ID":
                filter(lambda x: x[0] == 'resource_id', traits)[0][-1],
            "TIME_UPDATE":
                filter(lambda x: x[0] == 'created_at', traits)[0][-1]
    }
    server.build_job('image_update', data)
    return "Jenkins job was started"
  #  print traits
  #  return lol

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5123)
