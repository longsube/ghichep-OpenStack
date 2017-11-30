#!/usr/bin/python
# -*- coding: utf-8 -*-
import argparse
import sys
import smtplib
from email.MIMEText import MIMEText
from email.mime.multipart import MIMEMultipart
from email.Header import Header
from email.Utils import formatdate

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

def send_mail(subject, body, encoding='utf-8'):
    session = None
    msg1 = MIMEText(body, 'plain', encoding)
    msg = MIMEMultipart("test")
    msg['Subject'] = Header(subject, encoding)
    msg['To'] = ", ".join(recipients)
    msg['Date'] = formatdate()
    msg.attach(msg1)
    try:
        session = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        if Check:
            session.ehlo()
            session.starttls()
            session.ehlo()
            session.login(MAIL_ACCOUNT, MAIL_PASSWORD)
        session.sendmail(MAIL_ACCOUNT, recipients, msg.as_string())
    except Exception as e:
        raise e
    finally:
        if session:
            session.quit()

if __name__ == '__main__':
    argp = argparse.ArgumentParser(description='Lay thong tin gui mail')
    argp.add_argument('subject', type=str, help='Subject')
    argp.add_argument('body', type=str, help='Body')
    args = argp.parse_args()

    send_mail(
        subject=args.subject,
        body=args.body)
else:
         print u"""requires 3 parameters (recipient, subject, body)
 \t$ zabbix-gmail.sh recipient subject body
 """

