unit Zero2Kafka;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Crt,
  Kafka, KafkaClass, zmq, ZMQClass;

type

  { TMyKafkaConsumer }

  TMyKafkaConsumer = class
    constructor Create();
    procedure OnKafkaMessageReceived(InMessage: String; InKey: String; OutMsg: Prd_kafka_message_t);
    procedure OnKafkaMessageEOF(InMessage: String);
    procedure OnKafkaMessageErr(InError: String);
    procedure OnKafkaTick(InWhat: String);
  end;

procedure StartZeroMQProducer_21(InIniFileName: String);
procedure StartZeroMQConsumer_22(InIniFileName: String);
procedure StartKafkaConsumer_23(InIniFileName: String);

implementation

procedure WriteStatus(InString: String);
begin
  Writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + InString);
end;

// callback for Kafka send message
procedure Zero2Kafka_dr_msg_cb (rk: Prd_kafka_t; rkmessage: Prd_kafka_message_t; opaque: Pointer); cdecl;
begin
  if (rkmessage^.err <> 0) then begin
    WriteStatus(Format('Message delivery failed: %s', [rd_kafka_err2str(rkmessage^.err)]));
  end
  else begin
    WriteStatus(Format('Message delivered (bytes: %d, partition: %d)', [rkmessage^.len, rkmessage^.partion]));
  end;
end;


{ TMyKafkaConsumer }

constructor TMyKafkaConsumer.Create();
begin
  inherited Create();
end;

procedure TMyKafkaConsumer.OnKafkaMessageReceived(InMessage: String;
  InKey: String; OutMsg: Prd_kafka_message_t);
begin
  WriteStatus('ReceiveMessage: ' + InMessage);
end;

procedure TMyKafkaConsumer.OnKafkaMessageEOF(InMessage: String);
begin
  WriteStatus('ReceiveKafkaEOF');
end;

procedure TMyKafkaConsumer.OnKafkaMessageErr(InError: String);
begin
  WriteStatus('ReceiveKafkaERR: ' + InError);
end;

procedure TMyKafkaConsumer.OnKafkaTick(InWhat: String);
begin
  // WriteStatus('ReceiveKafkaTick: ' + InWhat);
end;


procedure StartZeroMQProducer_21(InIniFileName: String);
var My0MQContext: T0MQContext;
    My0MQSocket: T0MQSocket;
    My0MQSetup: T0MQSetup;
    MyString: String;
    MyError: Integer;
begin
  My0MQSocket := nil;

  try
    // read kafka and 0mq configuration
    ZeroMQReadConfiguration(InIniFileName, 'ZERO_SENDER',  My0MQSetup);

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

    while true do begin
      if KeyPressed then begin           //  <--- CRT function to test key press
        if ReadKey = ^C then begin       // read the key pressed
          WriteStatus('Ctrl-C pressed');
          Break;
        end;
      end;

      MyString := Format('<xml date="%s"/>', [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now)]);
      try
        MyError := My0MQSocket.Send(MyString);
        if MyString <> '' then begin
          WriteStatus('SendMessage: ' + MyString);
        end;
        Sleep(100);
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

procedure StartZeroMQConsumer_22(InIniFileName: String);
var MyProducer: TKafkaProducer;
    MyKafkaSetup: TKafkaSetup;

    My0MQContext: T0MQContext;
    My0MQSocket: T0MQSocket;
    My0MQSetup: T0MQSetup;

    MyError: Integer;
    MyString: String;
    MyKey: String;
    F: Integer;
    My_dr_msg_cb: TProc_dr_msg_cb;  // Callback for Kafka Producer
begin
  MyProducer := nil;
  My0MQSocket := nil;

  try
    // read kafka and 0mq configuration
    KafkaReadConfiguration(InIniFileName, 'kafka_producer', MyKafkaSetup);
    ZeroMQReadConfiguration(InIniFileName, 'ZERO_RECEIVER',  My0MQSetup);

    // create kafka producer
    MyProducer := TKafkaProducer.Create(True);

    // create 0mq pusher socket
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

    // Start producer
    My_dr_msg_cb := @Zero2Kafka_dr_msg_cb;
    MyProducer.StartProducer(MyKafkaSetup, My_dr_msg_cb);

    F := 0;
    // start reading messages from ZeroMQ socket
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
          F := F +1;
          WriteStatus('ReceivedMessage: ' + MyString);
          WriteStatus('Send message to kafka');

          MyKey := IntToStr(F mod 100);  // Fake Key
          MyProducer.ProduceMessage(MyKey, MyString);

          WriteStatus('Message Sent to Kafka Topic');
        end;
      except
        on E: Exception do begin
          WriteStatus('Error: ' + E.Message);
        end;
      end;
    end;

    if My0MQSocket <> nil then FreeAndNil(My0MQSocket);
    if My0MQContext <> nil then FreeAndNil(My0MQContext);
    if MyProducer <> nil then FreeAndNil(MyProducer);
  except
    on E: Exception do begin
      WriteStatus('Error: ' + E.Message);
      WriteStatus('ZeroMQDumpSetup: ' + ZeroMQDumpSetup(My0MQSetup));
      if My0MQSocket <> nil then FreeAndNil(My0MQSocket);
      if My0MQContext <> nil then FreeAndNil(My0MQContext);
      if MyProducer <> nil then FreeAndNil(MyProducer);
    end;
  end;
end;

procedure StartKafkaConsumer_23(InIniFileName: String);
var MyConsumer: TKafkaConsumer;
    MyKafkaSetup: TKafkaSetup;

    MySpecificKafkaConsumer: TMyKafkaConsumer;
    MyMaxReadBytes: Integer;
begin
  MyMaxReadBytes := 128;   // I want only 128 bytes messages - rest is trimmed
  MyConsumer := nil;
  MySpecificKafkaConsumer := nil;

  try
    // read kafka and 0mq configuration
    KafkaReadConfiguration(InIniFileName, 'kafka_consumer', MyKafkaSetup);

    // create kafka consumer
    MyConsumer := TKafkaConsumer.Create(True);

    // create callback object in which I will receive kafka messages and
    // send it to 0mq socket
    MySpecificKafkaConsumer := TMyKafkaConsumer.Create;

    // start kafka consumer
    MyConsumer.StartConsumer(MyKafkaSetup,
                             @MySpecificKafkaConsumer.OnKafkaMessageReceived,
                             @MySpecificKafkaConsumer.OnKafkaMessageEOF,
                             @MySpecificKafkaConsumer.OnKafkaMessageErr,
                             @MySpecificKafkaConsumer.OnKafkaTick,
                             MyMaxReadBytes);  // for test receive only 128 bytes

    if MySpecificKafkaConsumer <> nil then FreeAndNil(MySpecificKafkaConsumer);
    if MyConsumer <> nil then FreeAndNil(MyConsumer);
  except
    on E: Exception do begin
      WriteStatus('Error: ' + E.Message);
      if MySpecificKafkaConsumer <> nil then FreeAndNil(MySpecificKafkaConsumer);
      if MyConsumer <> nil then FreeAndNil(MyConsumer);
    end;
  end;
end;


end.

