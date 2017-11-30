#!/usr/bin/env python
import pika
import json

#Tao connect toi RabbitMQ host
connection = pika.BlockingConnection(pika.ConnectionParameters(host='10.193.0.22',credentials=pika.PlainCredentials(username='openstack', password='23926812c54237a2788d')))
channel = connection.channel()

#Khoi tao queue voi name ngau nhien
result = channel.queue_declare(exclusive=True)
queue_name = result.method.queue

#Khoi tao exchange (trong TH chua co exchange)
channel.exchange_declare(exchange='nova', exchange_type='topic')

#Gan queue voi exchange
channel.queue_bind(exchange='nova', queue=queue_name, routing_key='notifications.#')
channel.queue_bind(exchange='nova', queue=queue_name, routing_key='compute.#')




#Tao ham callback de lay du lieu trong queue
def callback_rabbitmq(ch, method, properties, body):
        """
        Method used by method nova_amq() to filter messages by type of message.

        :param ch: refers to the head of the protocol
        :param method: refers to the method used in callback
        :param properties: refers to the proprieties of the message
        :param body: refers to the message transmitted
        """

        body = json.loads(body)
 #       b = body['oslo.message']
 #       payload = json.loads(b)
        print(" [x] Received %r" % body)



channel.basic_consume(callback_rabbitmq, queue=queue_name, no_ack=True)
print(' [*] Waiting for messages. To exit press CTRL+C')

#Giu ket noi toi rabbit de lay message
channel.start_consuming()
