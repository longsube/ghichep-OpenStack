# Hướng dẫn cấu hình nhận thông tin event từ Ceilometer và gửi về email

Do aodh chỉ cảnh báo các sự kiện xảy ra trong 1 tenant cố định, do đó để gửi cảnh báo tất cả các sự kiện xảy ra trong hệ thống, ta sẽ sử dụng http dispatcher của Ceilometer để gửi thông tin event tới Ceilometer proxy, từ đó cảnh báo qua email tới quản trị viên.
Các event được cảnh báo:
 - Các sự kiện liên quan đến VM (create,delete, resize, rebuild, migrate,...)

*Lưu ý:*
 - Hướng dẫn sau thực hiện trên phiên bản Mitaka.
 - aodh chỉ có thể cảnh báo các event theo từng tenant, có nghĩa là với mỗi tenant sẽ phải tạo ra các event alarm giống nhau.
 - Việc cảnh báo bằng aodh chủ yếu để kết hợp với Heat project, giúp tự động co giãn máy ảo theo nhu cầu sử dụng.


## 1. Trên node Ceilometer
### 1.1. Cấu hình file `/etc/ceilometer/ceilometer.conf`
```
[DEFAULT]
...
event_dispatchers = http
...
[dispatcher_http]
#Khai báo web proxy nhận event và port
event_target = http://10.193.0.9:5123/event
batch_mode = True

```

### 1.2. Sửa file `/usr/lib/python2.7/dist-packages/ceilometer/dispatcher/http.py` để gửi các thông tin event dưới dạng json
```
def record_events(self, events):
 ...
     try:
        event_json = json.dumps(event)
        res = requests.post(self.event_target, data=event_json,
                            headers=self.headers,
                            timeout=self.timeout)

```

## 2. Tạo webproxy
### 2.1. Cài đặt flask và tải các script
```
pip install flask
mkdir flask
cd flask
wget https://git.cloudvnpt.com/longlq/Ceilometer/raw/master/scripts/alarm_proxy_dispatcher.py
wget https://git.cloudvnpt.com/longlq/Ceilometer/raw/master/scripts/send_mail.py
chmod +x alarm_proxy_dispatcher.py
chmod +x send_mail.py
```

### 2.2. Cấu hình `send_mail.py`
Chỉnh sửa email gửi và email nhận cảnh báo
```
# Mail Account
MAIL_ACCOUNT = 'abc@gmail.com'
MAIL_PASSWORD = 'abcxyz'

# Sender Name
SENDER_NAME = u'Zabbix Alert'
recipients = ['user1@gmail.com', 'user2@gmail.com']
# Mail Server
# TLS
SMTP_SERVER = 'smtp.gmail.com'
SMTP_PORT = 587
SMTP_TLS = True
```

### 2.3. Khởi chạy flaskapp
```
export FLASK_APP=flask/alarm_proxy_dispatcher.py
flask run --host=0.0.0.0 --port=5123
```

### 2.4. Cấu hình để scipt tự động khởi chạy
```
ln alarm_proxy_dispatcher.py /etc/init.d/alarm_proxy_dispatcher.py
chmod 770 /etc/init.d/alarm_proxy_dispatcher.py
update-rc.d alarm_proxy_dispatcher.py defaults
/etc/init.d/alarm_proxy_dispatcher.py start
```
