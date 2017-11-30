#!/usr/bin/python
from flask import Flask, request
import jenkins
import json

app = Flask(__name__)

@app.route("/image", methods=['POST'])
def alarm():
    traits = json.loads(request.data)['reason_data']['event']['traits']
  #  traits = json.loads(request.data)
#    STATUS = filter(lambda x: x[0] == 'status', traits)[0][-1],
#    "RESOURCE_ID": filter(lambda x: x[0] == 'resource_id', traits)[0][-1],
 #   "TIME_UPDATE": filter(lambda x: x[0] == 'created_at', traits)[0][-1]

    print traits
 #   print STATUS
    return 'Done'

if __name__ == "__main__":
    app.run(host='0.0.0.0',port=5123)
