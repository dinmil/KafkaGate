# KafkaGate

This library shows how to use Apache Kafka and FreePascal (CodeTyphon 6.40, Lazarus)
This is translation of librdkafka C library (and it contain ZeroMQ wrapper also). 
It contain examples for Win64 and Win32 (but it should be portable to Linux, etc..)
There are two ways how to write FreePascal Kafka application. 
One way is C procedural style, and the other one is Object Pascal Style.

KafkaPas is example how to create Kafka GUI application. 
KafkaGate is example how to create console application. This application is usefull if you want to connect ZeroMQ Socket and Kafka Topic. You can send and receive messages between them. 

ZeroMQ is excelent message queue library, but without broker (therefore you can lost message).
On the other hand Apache Kafka is message queue broker. So if you like ZeroMQ, but unfortunatelly you need some broker for your project, you can use Kafka to serve that purpose.

<p align="center">
  <img src="KafkaGate.png"/>
  <img src="KafkaPasProducer.png"/>
  <img src="KafkaPasConsumer.png"/>
</p>

<strong>KafkaGate Console Menu</strong>
<p align="left">
<br>writeln('Menu');
<br>writeln('1. Start consumer - C Style');
<br>writeln('2. Start producer - C Style');
<br>writeln('3. Start consumer - Pas Style');
<br>writeln('4. Start producer - Pas Style');
<br>writeln('KAFKA 2 ZEROMQ');
<br>writeln('config_file: KafkaGate.ini');
<br>writeln('Purpose of this pipeline is');
<br>writeln('- put message to kafka->consume message from kafka->send message to 0mq->receive message from 0mq');
<br>writeln('11. Start Kafka Producer');
<br>writeln('12. Start Kafka Consumer -> Start ZEROMQ PUSH');
<br>writeln('13. Start ZEROMQ PULL');
<br>writeln('ZEROMQ 2 KAFKA');
<br>writeln('config_file: KafkaGate.ini');
<br>writeln('Purpose of this pipeline is');
<br>writeln('- put message to 0mq->consume message from 0mq->send message to kafka->receive message from kafka');
<br>writeln('21. Start ZERMOQ Producer PUSH');
<br>writeln('22. Start ZEROMQ PULL -> Kafka Producer');
<br>writeln('23. Start Kafka Consumer');
</p>


</br>
New in this version from 2018-02-27
</br>
New librdkafka 11.3
</br>
Compatibility with Linux 32 and Linux 64
</br>
New Way to sebd message in Kafka Pas Application
</br>
Compiled with new Code Typhon 6.40
</br>
