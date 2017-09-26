unit Kafka2Zero;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Crt,
  Kafka, KafkaClass, zmq, ZMQClass;

type

  { TKafkaConsumer2ZeroMQ }

  TKafkaConsumer2ZeroMQ = class
    _0MQSocket: T0MQSocket;

    constructor Create(In0MQSocket: T0MQSocket);
    procedure OnKafkaMessageReceived(InMessage: String; InKey: String; OutMsg: Prd_kafka_message_t);
    procedure OnKafkaMessageEOF(InMessage: String);
    procedure OnKafkaMessageErr(InError: String);
    procedure OnKafkaTick(InWhat: String);
  end;

procedure StartKafkaProducer_11(InIniFileName: String);
procedure StartKafkaConsumer_12(InIniFileName: String);
procedure StartZeroMQConsumer_13(InIniFileName: String);

implementation

procedure WriteStatus(InString: String);
begin
  Writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + InString);
end;

// callback for Kafka send message
procedure Kafka2Zero_dr_msg_cb (rk: Prd_kafka_t; rkmessage: Prd_kafka_message_t; opaque: Pointer); cdecl;
begin
  if (rkmessage^.err <> 0) then begin
    WriteStatus(Format('Message delivery failed: %s', [rd_kafka_err2str(rkmessage^.err)]));
  end
  else begin
    WriteStatus(Format('Message delivered (bytes: %d, partition: %d)', [rkmessage^.len, rkmessage^.partion]));
  end;
end;


{ TKafkaConsumer2ZeroMQ }

constructor TKafkaConsumer2ZeroMQ.Create(In0MQSocket: T0MQSocket);
begin
  _0MQSocket := In0MQSocket;
end;

procedure TKafkaConsumer2ZeroMQ.OnKafkaMessageReceived(InMessage: String;
  InKey: String; OutMsg: Prd_kafka_message_t);
var MyError: Integer;
begin
  WriteStatus('ReceiveMessage: ' + InMessage);
  WriteStatus('Send Message');
  try
    MyError := _0MQSocket.Send(InMessage);
    if MyError > 0 then begin
      WriteStatus('Message Sent: ' + InMessage)
    end
  except
    on E: Exception do begin
      WriteStatus('Error: ' + e.Message);
    end;
  end
end;

procedure TKafkaConsumer2ZeroMQ.OnKafkaMessageEOF(InMessage: String);
begin
  WriteStatus('ReceiveKafkaEOF');
end;

procedure TKafkaConsumer2ZeroMQ.OnKafkaMessageErr(InError: String);
begin
  WriteStatus('ReceiveKafkaERR: ' + InError);
end;

procedure TKafkaConsumer2ZeroMQ.OnKafkaTick(InWhat: String);
begin
  // WriteStatus('ReceiveKafkaTick: ' + InWhat);
end;


procedure StartKafkaProducer_11(InIniFileName: String);
var MyProducer: TKafkaProducer;
    MyKafkaSetup: TKafkaSetup;
    F: Integer;
    My_dr_msg_cb: TProc_dr_msg_cb;
    MyKey, MyMessage: String;
begin
  MyProducer := nil;
  try
    KafkaReadConfiguration(InIniFileName, 'kafka_producer', MyKafkaSetup);

    MyProducer := TKafkaProducer.Create(True);

    My_dr_msg_cb := @Kafka2Zero_dr_msg_cb;
    MyProducer.StartProducer(MyKafkaSetup, My_dr_msg_cb);

    for F := 0 to 1000 do begin
      if KeyPressed then begin           //  <--- CRT function to test key press
        if ReadKey = ^C then begin       // read the key pressed
          WriteStatus('Ctrl-C pressed');
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
      WriteStatus('Error: ' + E.Message);
      if MyProducer <> nil then FreeAndNil(MyProducer);
    end;
  end;
end;

procedure StartKafkaConsumer_12(InIniFileName: String);
var MyConsumer: TKafkaConsumer;
    MyKafkaSetup: TKafkaSetup;

    My0MQContext: T0MQContext;
    My0MQSocket: T0MQSocket;
    My0MQSetup: T0MQSetup;

    MySpecificKafkaConsumer: TKafkaConsumer2ZeroMQ;
    MyMaxReadBytes: Integer;
begin
  MyMaxReadBytes := 128;   // I want only 128 bytes messages - rest is trimmed
  MyConsumer := nil;
  My0MQSocket := nil;
  MySpecificKafkaConsumer := nil;

  try
    // read kafka and 0mq configuration
    KafkaReadConfiguration(InIniFileName, 'kafka_consumer', MyKafkaSetup);
    ZeroMQReadConfiguration(InIniFileName, 'ZERO_SENDER',  My0MQSetup);

    // create kafka consumer
    MyConsumer := TKafkaConsumer.Create(True);

    // create 0mq pusher socket
    My0MQContext := T0MQContext.Create();
    My0MQSocket := T0MQSocket.Create(My0MQContext._Context);

    // setup and connect 0mqsocket
    // we can support PUBLISH-SUBSCRIBE pattern or PUSH-PULL pattern
    if My0MQSetup.socket_type = 'PUB' then begin
      My0MQSocket.GetSocket(ZMQ_PUB);
    end
    else begin
      My0MQSocket.GetSocket(ZMQ_PUSH);
    end;
    My0MQSocket.SetSockOptInteger(ZMQ_SNDHWM, My0MQSetup.hwm);
    My0MQSocket.SetSockOptInteger(ZMQ_SNDTIMEO, My0MQSetup.send_timeout);
    My0MQSocket.ConnectSocket(My0MQSetup.address);

    // create callback object in which I will receive kafka messages and
    // send it to 0mq socket
    MySpecificKafkaConsumer := TKafkaConsumer2ZeroMQ.Create(My0MQSocket);

    // start kafka consumer
    MyConsumer.StartConsumer(MyKafkaSetup,
                             @MySpecificKafkaConsumer.OnKafkaMessageReceived,
                             @MySpecificKafkaConsumer.OnKafkaMessageEOF,
                             @MySpecificKafkaConsumer.OnKafkaMessageErr,
                             @MySpecificKafkaConsumer.OnKafkaTick,
                             MyMaxReadBytes);  // for test receive only 128 bytes

    if MySpecificKafkaConsumer <> nil then FreeAndNil(MySpecificKafkaConsumer);
    if My0MQSocket <> nil then FreeAndNil(My0MQSocket);
    if My0MQContext <> nil then FreeAndNil(My0MQContext);
    if MyConsumer <> nil then FreeAndNil(MyConsumer);
  except
    on E: Exception do begin
      WriteStatus('Error: ' + E.Message);
      WriteStatus('ZeroMQDumpSetup: ' + ZeroMQDumpSetup(My0MQSetup));
      if MySpecificKafkaConsumer <> nil then FreeAndNil(MySpecificKafkaConsumer);
      if My0MQSocket <> nil then FreeAndNil(My0MQSocket);
      if My0MQContext <> nil then FreeAndNil(My0MQContext);
      if MyConsumer <> nil then FreeAndNil(MyConsumer);
    end;
  end;
end;

procedure StartZeroMQConsumer_13(InIniFileName: String);
var My0MQContext: T0MQContext;
    My0MQSocket: T0MQSocket;
    My0MQSetup: T0MQSetup;
    MyString: String;
    MyError: Integer;
begin
  My0MQSocket := nil;

  try
    // read 0mq configuration
    ZeroMQReadConfiguration(InIniFileName, 'ZERO_RECEIVER',  My0MQSetup);


    // create 0mq puller socket
    My0MQContext := T0MQContext.Create();
    My0MQSocket := T0MQSocket.Create(My0MQContext._Context);

    // setup and connect 0mqsocket
    // we can support PUBLISH-SUBSCRIBE pattern or PUSH-PULL pattern
    if My0MQSetup.socket_type = 'SUB' then begin
      My0MQSocket.GetSocket(ZMQ_SUB);
    end
    else begin
      My0MQSocket.GetSocket(ZMQ_PULL);
    end;
    My0MQSocket.SetSockOptInteger(ZMQ_SNDHWM, My0MQSetup.hwm);
    My0MQSocket.SetSockOptInteger(ZMQ_SNDTIMEO, My0MQSetup.send_timeout);
    My0MQSocket.BindSocket(My0MQSetup.address);

    while true do begin
      if KeyPressed then begin           //  <--- CRT function to test key press
        if ReadKey = ^C then begin       // read the key pressed
          WriteStatus('Ctrl-C pressed');
          Break;
        end;
      end;

      MyString := '';
      try
        MyError := My0MQSocket.Recv(MyString, ZMQ_DONTWAIT, 100);
        if MyString <> '' then begin
          WriteStatus('ReceivedMessage: ' + MyString);
        end;
      except
        on E: Exception do begin
          WriteStatus('Error: ' + E.Message);
        end;
      end;
    end;

    if My0MQSocket <> nil then FreeAndNil(My0MQSocket);
    if My0MQContext <> nil then FreeAndNil(My0MQContext);
  except
    on E: Exception do begin
      WriteStatus('Error: ' + E.Message);
      WriteStatus('ZeroMQDumpSetup: ' + ZeroMQDumpSetup(My0MQSetup));
      if My0MQSocket <> nil then FreeAndNil(My0MQSocket);
      if My0MQContext <> nil then FreeAndNil(My0MQContext);
    end;
  end;
end;


end.

