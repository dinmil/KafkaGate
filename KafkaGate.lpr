program KafkaGate;

{$mode objfpc}{$H+}

uses
  {$IFOPT D-}
  // cmem, // CT570 does not like debug mode with cmem
           // Date 2017-04-24 - I noticed that Win32 version without debug info
           // and use cmem is slower than normal default memory manager
           // therefore I comment out cmem - for client application it is ok
           // for service application this will consume too much memory durring life time of application
  {$ENDIF}
  heaptrc, //lineinfo,

  {$DEFINE UseCThreads}
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}

  Classes, SysUtils, Crt,
  Kafka, KafkaClass
  { you can add units after this };

const
  MyBrokerConsumer: string = '172.16.20.210:9092';
//  MyTopicConsumer : string = 'sportfeedxml';
  MyTopicConsumer : string = 'betslip';

  MyBrokerProducer: string = '172.16.20.210:9092';
  MyTopicProducer : string = 'betslip';  // eventlotto, eventprematch, eventlive
//  MyTopicProducer : string = 'sportfeedxml';

  BStop: Boolean = False;

var
  conf: Prd_kafka_conf_t;
  topic_conf: Prd_kafka_topic_conf_t;
  rk: Prd_kafka_t;
  topics: Prd_kafka_topic_partition_list_t;
  topic: Prd_kafka_topic_partition_t;
  rkmessage: Prd_kafka_message_t;
  rkt: Prd_kafka_topic_t;

procedure WriteStatus(InString: String);
begin
  Writeln(InString);
end;


function SetPropertie(conf: Prd_kafka_conf_t; InPropertie: String; InPropertieValue: String): Trd_kafka_conf_res_t;
var MyRetVal: Trd_kafka_conf_res_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
    MyLastError: Trd_kafka_resp_err_t;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyRetVal := RD_KAFKA_CONF_OK;
  WriteStatus('Setting ' + InPropertie);
  MyRetVal := rd_kafka_conf_set(conf, PChar(InPropertie), PChar(InPropertieValue), PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    WriteStatus('Failed ' + InPropertie + ': ' + String(errstr));
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus(InPropertie + ' failed code: ' + IntToStr(MyLastError));
      WriteStatus(InPropertie + ' failed error: ' + rd_kafka_err2name(MyLastError));
    end;
    if String(errstr) <> '' then begin
      WriteStatus('errstr: ' + String(errstr));
    end;
  end;
  Result := MyRetVal;
end;

procedure ConsumeKafka_CStyle;
var MyRetVal: Trd_kafka_conf_res_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
    MyLastError: Trd_kafka_resp_err_t;
    MyRetInt32: Int32;
    MyString: String;
begin
  BStop := False;
  errstr_size := SizeOf(errstr);

  WriteStatus('Creating Kafka Handler');
  conf := rd_kafka_conf_new();
  WriteStatus('Kafka.rd_kafka_last_error: ' + IntToStr(Kafka.rd_kafka_last_error));

  WriteStatus('Creating Topic Handler');
  topic_conf := rd_kafka_topic_conf_new();
  WriteStatus('Kafka.rd_kafka_last_error: ' + IntToStr(Kafka.rd_kafka_last_error));

  (*
	c, err := kafka.NewConsumer(&kafka.ConfigMap{
		"bootstrap.servers":    broker,
		"group.id":             group,
		"session.timeout.ms":   6000,
		"default.topic.config": kafka.ConfigMap{"auto.offset.reset": "earliest"}})
  *)

  SetPropertie(conf, 'group.id', 'rdkafka_consumer_example');
  SetPropertie(conf, 'socket.keepalive.enable', 'true');

  SetPropertie(conf, 'queued.min.messages', '0');
  SetPropertie(conf, 'queued.max.messages.kbytes', '0');
  SetPropertie(conf, 'fetch.wait.max.ms', '0');
  SetPropertie(conf, 'fetch.message.max.bytes', '1048576');
  SetPropertie(conf, 'fetch.min.bytes', '1');


  errstr := '';
  WriteStatus('Setting offset.store.method');
  MyRetVal := rd_kafka_topic_conf_set(topic_conf, 'offset.store.method', 'broker', PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    WriteStatus('rd_kafka_topic_conf_set.offset.store.method failed: ' + IntToStr(Kafka.rd_kafka_last_error));
    if String(errstr) <> '' then begin
      WriteStatus('errstr: ' + String(errstr));
    end;
  end;

  errstr := '';
  WriteStatus('Creating default topic conf');
  rd_kafka_conf_set_default_topic_conf(conf, topic_conf);
  MyLastError := Kafka.rd_kafka_last_error;
  if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
    WriteStatus('rd_kafka_conf_set_default_topic_conf failed code: ' + IntToStr(MyLastError));
    WriteStatus('rd_kafka_conf_set_default_topic_conf failed error: ' + rd_kafka_err2name(MyLastError));
  end;

  errstr := '';
  rk := nil;
  WriteStatus('Creating consumer');
  rk := rd_kafka_new(RD_KAFKA_CONSUMER, conf, PChar(errstr), errstr_size);
  if rk = nil then begin
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('Create Consumer failed code: ' + IntToStr(MyLastError));
      WriteStatus('Create Consumer failed error: ' + rd_kafka_err2name(MyLastError));
    end;
    if String(errstr) <> '' then begin
      WriteStatus('errstr: ' + String(errstr));
    end;
  end;



  errstr := '';
  MyRetInt32 := 0;
  WriteStatus('Connecting to brokers');
  MyRetInt32 := rd_kafka_brokers_add(rk, PChar(MyBrokerConsumer));
  if MyRetInt32 = 0 then begin
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('Broker failed code: ' + IntToStr(MyLastError));
      WriteStatus('Broker failed error: ' + rd_kafka_err2name(MyLastError));
    end;
  end;

  errstr := '';
  WriteStatus('Setting poll');
  MyRetVal := rd_kafka_poll_set_consumer(rk);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_poll_set_consumer failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_poll_set_consumer failed error: ' + rd_kafka_err2name(MyLastError));
    end;
  end;

  topics := nil;
  WriteStatus('Creating partition list');
  topics := rd_kafka_topic_partition_list_new(1);
  if topics <> nil then begin
    WriteStatus('rd_kafka_topic_partition_list_new count: ' + IntToStr(topics^.cnt));
  end
  else begin
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_topic_partition_list_new failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_topic_partition_list_new failed error: ' + rd_kafka_err2name(MyLastError));
    end;
  end;

  WriteStatus('Creating topic');
  topic := rd_kafka_topic_partition_list_add(topics, PChar(MyTopicConsumer), 0);
  if topic <> nil then begin
    topics^.cnt := 1;
  end
  else begin
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_topic_partition_list_add failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_topic_partition_list_add failed error: ' + rd_kafka_err2name(MyLastError));
    end;
  end;

  WriteStatus('Subscribe to topic: ' + MyTopicConsumer);
  MyRetVal := rd_kafka_subscribe(rk, topics);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    WriteStatus('Failed to execute rd_kafka_subscribe: ' + IntToStr(MyRetVal));
    WriteStatus(rd_kafka_err2name(MyRetVal));
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_subscribe failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_subscribe failed error: ' + rd_kafka_err2name(MyLastError));
    end;
  end;
  WriteStatus('Topic subscribed: ' + MyTopicConsumer);

  while true do begin
    if BStop = true then Break;

    if KeyPressed then begin           //  <--- CRT function to test key press
      if ReadKey = ^C then begin       // read the key pressed
        WriteStatus('Ctrl-C pressed');
        BStop := True;
        Break;
      end;
    end;

    rkmessage := rd_kafka_consumer_poll(rk, 1);
    if (rkmessage <> nil)  then begin
      if rkmessage^.err = RD_KAFKA_RESP_ERR__PARTITION_EOF then begin
        WriteStatus('Read RD_KAFKA_RESP_ERR__PARTITION_EOF');
      end
      else if (rkmessage^.err = RD_KAFKA_RESP_ERR__UNKNOWN_PARTITION) or
              (rkmessage^.err = RD_KAFKA_RESP_ERR__UNKNOWN_TOPIC)
      then begin
        WriteStatus('RD_KAFKA_RESP_ERR__UNKNOWN_PARTITION or RD_KAFKA_RESP_ERR__UNKNOWN_TOPIC');
        Break;
      end
      else begin
        if rkmessage^.err <> 0 then begin
          WriteStatus('Received from topic: ' + String(PChar(rkmessage^.rkt)));
          WriteStatus('MsgNo: ' + IntToStr(rkmessage^.offset));
        end
        else begin
          WriteStatus(Format('%s Message (topic %s, part %d, offset %d, %d bytes):',
                                 [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
                                  String(rd_kafka_topic_name(rkmessage^.rkt)),
                                   rkmessage^.partion,
                                   rkmessage^.offset,
                                   rkmessage^.len
                                 ]));
          MyString := PChar(rkmessage^.key);
          MyString := Copy(String(PChar(rkmessage^.payload)), 1, 512);
      		WriteStatus(Format('Key: %s, %s', [String(PChar(rkmessage^.key)), MyString]) + Format(' Message: %s', [MyString]));
        end;
      end;
      rd_kafka_message_destroy(rkmessage);
    end;
  end;

  WriteStatus('Closing Consumer');
  MyRetVal := rd_kafka_consumer_close(rk);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    WriteStatus('Failed to execute rd_kafka_consumer_close: ' + IntToStr(MyRetVal));
    WriteStatus(rd_kafka_err2name(MyRetVal));
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_consumer_close failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_consumer_close failed error: ' + rd_kafka_err2name(MyLastError));
    end;
  end;

  WriteStatus('Free partition list');
  rd_kafka_topic_partition_list_destroy(topics);

  WriteStatus('Free Kafka');
  rd_kafka_destroy(rk);


  (*
  run = 5;
  while (run-- > 0 && rd_kafka_wait_destroyed(1000) == -1)
  printf("Waiting for librdkafka to decommission\n");
  if (run <= 0)
  rd_kafka_dump(stdout, rk);
  *)
end;

procedure DumpKafkaVersion;
begin
  WriteStatus('Kafka.rd_kafka_version: ' + IntToStr(Kafka.rd_kafka_version));
  WriteStatus('Kafka.rd_kafka_version_str: ' + String(Kafka.rd_kafka_version_str));
  WriteStatus('Kafka.rd_kafka_get_debug_contexts: ' + String(Kafka.rd_kafka_get_debug_contexts));
end;


procedure dr_msg_cb (rk: Prd_kafka_t; rkmessage: Prd_kafka_message_t; opaque: Pointer); cdecl;
begin
  if (rkmessage^.err <> 0) then begin
    WriteStatus(Format('Message delivery failed: %s', [rd_kafka_err2str(rkmessage^.err)]));
  end
  else begin
    WriteStatus(Format('Message delivered (bytes: %d, partition: %d)', [rkmessage^.len, rkmessage^.partion]));
  end;
end;

var My_dr_msg_cb: TProc_dr_msg_cb;

procedure ProduceKafka_CStyle;
var MyRetVal: Trd_kafka_conf_res_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
    MyLastError: Trd_kafka_resp_err_t;
    MyRetInt32: Int32;
    MyString: String;
    MyBuffer: array[0..100000-1] of char;
    MyMessageNo: Int64;
    MyLen: Int32;
    MyKey: array[0..8] of char;
    MyKeyLen: Int32;
begin
  BStop := False;
  errstr_size := SizeOf(errstr);

  WriteStatus('Creating Kafka Handler');
  conf := rd_kafka_conf_new();
  WriteStatus('Kafka.rd_kafka_last_error: ' + IntToStr(Kafka.rd_kafka_last_error));

  SetPropertie(conf, 'message.max.bytes', '1500000');
  SetPropertie(conf, 'socket.keepalive.enable', 'true');

  SetPropertie(conf, 'queue.buffering.max.messages', '10');
  SetPropertie(conf, 'queue.buffering.max.ms', '1000');
  SetPropertie(conf, 'batch.num.messages', '1');

  SetPropertie(conf, 'delivery.report.only.error', 'false');


  WriteStatus('Creating Brokers');
  MyRetVal := rd_kafka_conf_set(conf, 'bootstrap.servers', PChar(MyBrokerProducer), PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    WriteStatus('Failed to create brokers, rd_kafka_conf_set: ' + String(errstr));
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_conf_set failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_conf_set failed error: ' + rd_kafka_err2name(MyLastError));
    end;
    if String(errstr) <> '' then begin
      WriteStatus('errstr: ' + String(errstr));
    end;
  end;

  WriteStatus('Setting acks');
  MyRetVal := rd_kafka_conf_set(conf, 'acks', '0', PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    WriteStatus('Failed acks: ' + String(errstr));
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('acks failed code: ' + IntToStr(MyLastError));
      WriteStatus('acks failed error: ' + rd_kafka_err2name(MyLastError));
    end;
    if String(errstr) <> '' then begin
      WriteStatus('errstr: ' + String(errstr));
    end;
  end;

  errstr := '';
  // Set the delivery report callback.
  // This callback will be called once per message to inform
  // the application if delivery succeeded or failed.
  // See dr_msg_cb() above.
  My_dr_msg_cb := @dr_msg_cb;
  rd_kafka_conf_set_dr_msg_cb(conf, My_dr_msg_cb);
  MyLastError := Kafka.rd_kafka_last_error;
  if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
    WriteStatus('rd_kafka_conf_set_dr_msg_cb failed code: ' + IntToStr(MyLastError));
    WriteStatus('rd_kafka_conf_set_dr_msg_cb failed error: ' + rd_kafka_err2name(MyLastError));
  end;
  if String(errstr) <> '' then begin
    WriteStatus('errstr: ' + String(errstr));
  end;

  errstr := '';
  rk := nil;
  WriteStatus('Creating producer');
  rk := rd_kafka_new(RD_KAFKA_PRODUCER, conf, PChar(errstr), errstr_size);
  if rk = nil then begin
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('Create Producer failed code: ' + IntToStr(MyLastError));
      WriteStatus('Create Producer failed error: ' + rd_kafka_err2name(MyLastError));
    end;
    if String(errstr) <> '' then begin
      WriteStatus('errstr: ' + String(errstr));
    end;
  end;


  WriteStatus('Creating topic');
  rkt := rd_kafka_topic_new(rk, PChar(MyTopicProducer), nil);
  if rkt = nil then begin
    WriteStatus('Failed to create topic: ' + IntToStr(MyLastError));
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_topic_partition_list_add failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_topic_partition_list_add failed error: ' + rd_kafka_err2name(MyLastError));
    end;
    Exit;
  end;

  MyMessageNo := 0;

  while MyMessageNo < 100000000000 do begin
    FillByte(MyBuffer, SizeOf(MyBuffer), MyMessageNo);
    Sleep(1000);

    if KeyPressed then begin           //  <--- CRT function to test key press
      if ReadKey = ^C then begin       // read the key pressed
        WriteStatus('Ctrl-C pressed');
        BStop := True;
        Break;
      end;
    end;


    StrPCopy(MyBuffer, FormatDateTime(': yyyy-mm-dd hh:nn:ss.zzz', Now));
    MyLen := SizeOF(MyBuffer);
    Inc(MyMessageNo);
    FillByte(MyKey, SizeOf(MyKey), 0);
    StrPCopy(MyKey, IntToStr(MyMessageNo mod 1000));
//    StrPCopy(MyKey, 'MyKey');
    MyKeyLen := SizeOf(String(MyKey));
    MyRetVal := rd_kafka_produce(rkt,
                                 RD_KAFKA_PARTITION_UA,
                                 RD_KAFKA_MSG_F_COPY,
                                 @MyBuffer,
                                 MyLen,
                                 @MyKey[0],
                                 MyKeyLen,
                                 nil);

    if MyRetVal <> RD_KAFKA_CONF_OK then begin
      WriteStatus(Format('% Failed to produce message for topic %s: %s"',
                   [rd_kafka_topic_name(rkt),
                    rd_kafka_err2str(rd_kafka_last_error())]));

      if (rd_kafka_last_error() = RD_KAFKA_RESP_ERR__QUEUE_FULL)  then begin
        WriteStatus('Received message RD_KAFKA_RESP_ERR__QUEUE_FULL');
        rd_kafka_poll(rk, 1000);
        (*
              // If the internal queue is full, wait for
              // messages to be delivered and then retry.
              // The internal queue represents both
              // messages to be sent and messages that have
              // been sent or failed, awaiting their
              // delivery report callback to be called.
              //
              // The internal queue is limited by the
              // configuration property
              // queue.buffering.max.messages *)
              // rd_kafka_poll(rk, 1000 //block for max 1000ms;
              //goto retry;
      end;
    end
    else begin
      WriteStatus(Format('Enqueued message (%s Key) (%d bytes) for topic %s: %s', [String(MyKey), Mylen, rd_kafka_topic_name(rkt), String(MyBuffer)]));
      rd_kafka_poll(rk, 0); //non-blocking
    end;
  end;

  WriteStatus('Closing Producer');
  MyRetVal := rd_kafka_consumer_close(rk);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    WriteStatus('Failed to execute rd_kafka_consumer_close: ' + IntToStr(MyRetVal));
    WriteStatus(rd_kafka_err2name(MyRetVal));
    MyLastError := Kafka.rd_kafka_last_error;
    if MyLastError <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
      WriteStatus('rd_kafka_consumer_close failed code: ' + IntToStr(MyLastError));
      WriteStatus('rd_kafka_consumer_close failed error: ' + rd_kafka_err2name(MyLastError));
    end;
  end;

  // Wait for final messages to be delivered or fail.
  // rd_kafka_flush() is an abstraction over rd_kafka_poll() which
  // waits for all messages to be delivered.
  WriteStatus(' Flushing final messages..');
  rd_kafka_flush(rk, 10*1000); // wait for max 10 seconds

  WriteStatus('Destroy topic object');
  rd_kafka_topic_destroy(rkt);

  WriteStatus('Destroy producer instance');
  rd_kafka_destroy(rk);

  WriteStatus('Free partition list');
end;

procedure Consume_PasStyle;
var MyConsumer: TKafkaConsumer;
    MyKafkaSetup: TKafkaSetup;
begin
  MyConsumer := nil;
  try
    MyConsumer := TKafkaConsumer.Create(True);

    KafkaReadConfiguration('config.ini', 'consumer', MyKafkaSetup);

    MyConsumer.StartConsumer(MyKafkaSetup, nil, nil, nil, nil, 128);

    if MyConsumer <> nil then FreeAndNil(MyConsumer);
  except
    on E: Exception do begin
      if MyConsumer <> nil then FreeAndNil(MyConsumer);
    end;
  end;
end;

procedure Produce_PasStyle;
var MyProducer: TKafkaProducer;
    MyKafkaSetup: TKafkaSetup;
    F: Integer;
    My_dr_msg_cb: TProc_dr_msg_cb;
    MyKey, MyMessage: String;
begin
  MyProducer := nil;
  try
    MyProducer := TKafkaProducer.Create(True);

    // MyBrokerProducer: string = '172.16.20.210:9092';
    // MyTopicProducer : string = 'betslip';  // eventlotto, eventprematch, eventlive

    KafkaReadConfiguration('config.ini', 'producer', MyKafkaSetup);

    My_dr_msg_cb := @dr_msg_cb;
    MyProducer.StartProducer(MyKafkaSetup, My_dr_msg_cb);

    for F := 0 to 1000 do begin
      if KeyPressed then begin           //  <--- CRT function to test key press
        if ReadKey = ^C then begin       // read the key pressed
          WriteStatus('Ctrl-C pressed');
          BStop := True;
          Break;
        end;
      end;

      MyKey := IntToStr(F mod 100);
      MyMessage := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
      MyProducer.ProduceMessage(MyKey, MyMessage);
      Sleep(250);
    end;

    if MyProducer <> nil then FreeAndNil(MyProducer);
  except
    on E: Exception do begin
      if MyProducer <> nil then FreeAndNil(MyProducer);
    end;
  end;
end;

var MyMenu: String;
begin
  heaptrc.printfaultyblock := True;
  heaptrc.printleakedblock := True;
  heaptrc.quicktrace := True;
  heaptrc.HaltOnNotReleased := True;
  heaptrc.SetHeapTraceOutput('.\heaptrc.trc');

  DecimalSeparator := '.';
  ThousandSeparator := ',';
  DateSeparator:='-';
  TimeSeparator:=':';
  LongDateFormat:='yyyy-mm-dd';
  ShortDateFormat:='yyyy-mm-dd';
  LongTimeFormat:='hh:nn:ss.zzz';
  ShortTimeFormat:='hh:nn:ss.zzz';


  DumpKafkaVersion;
  while true do begin
    writeln('Menu');
    writeln('1. Start consumer - C Style');
    writeln('2. Start producer - C Style');
    writeln('3. Start consumer - Pas Style');
    writeln('4. Start producer - Pas Style');
    writeln('X. Exit');
    Readln(MyMenu);
    if MyMenu = '1' then begin
      ConsumeKafka_CStyle;
    end
    else if MyMenu = '2' then begin
      ProduceKafka_CStyle;
    end
    else if MyMenu = '3' then begin
      Consume_PasStyle;
    end
    else if MyMenu = '4' then begin
      Produce_PasStyle;
    end
    else if UpperCase(MyMenu) = 'X' then begin
      Break;
    end;
  end;
end.

