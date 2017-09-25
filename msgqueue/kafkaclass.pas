unit KafkaClass;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils,
  IniFiles,

  Kafka, ctypes, Crt;

type
  TOnKafkaMessageReceived = procedure(InMessage: String; InKey: String; OutMsg: Prd_kafka_message_t) of object;
  TOnKafkaMessageEOF = procedure(InMessage: String) of object;
  TOnKafkaMessageErr = procedure(InError: String) of object;
  TOnKafkaTick = procedure(InWhat: String) of object;

  TKafkaSetup = record
    broker: String;           // '172.16.20.210:9092'
    topic: String;            // 'betslip'
    conf_section: String;     // conf ini file section with key_value pairs
    conf_properties: String;  // key=value\nkey=value\n ... properties key=value new_line....

    topic_section: String;    // topic ini file section with key_value pairs
    topic_properties: String; // key=value\nkey=value\n ... properties key=value new_line....
  end;


  { EKafkaError }
  // Error nadling
  // Methods that create objects return NULL if they fail.
  // Methods that process data may return the number of bytes processed, or -1 on an error or failure.
  // Other methods return 0 on success and -1 on an error or failure.
  // The error code is provided in errno or zmq_errno().
  // A descriptive error text for logging is provided by zmq_strerror().


  EKafkaError = class(Exception)
    public
      _ErrNo: Integer;
      _ErrMsg: String;
      constructor Create(InErrNo: Integer; InErrMsg: String);
      destructor Destroy; override;
  end;

  { TKafkaClass }

  TKafkaClass = class
    _Conf: Prd_kafka_conf_t;
    _Topic_conf: Prd_kafka_topic_conf_t;
    _Rk: Prd_kafka_t;
    _Topics: Prd_kafka_topic_partition_list_t;
    _Topic: Prd_kafka_topic_partition_t;
    _Rkmessage: Prd_kafka_message_t;
    _Rkt: Prd_kafka_topic_t;

    _RecvBuffer: array[0..(65536 * 100)-1] of char;
  public
    _BStop: Boolean;
    _KafkaSetup: TKafkaSetup;

    _OnKafkaMessageReceived: TOnKafkaMessageReceived;
    _OnKafkaMessageEOF: TOnKafkaMessageEOF;
    _OnKafkaMessageErr: TOnKafkaMessageErr;
    _OnKafkaTick: TOnKafkaTick;

    _IsConsole: Boolean;

    _IsProducer: Boolean;

    _FormatSettings: TFormatSettings;


    constructor Create(InIsConsole: Boolean);
    destructor Destroy; override;

    procedure ProcOnKafkaMessageReceived(InMessage: String; InKey: String; OutMsg: Prd_kafka_message_t);
    procedure ProcOnKafkaMessageEOF(InMessage: String);
    procedure ProcOnKafkaMessageErr(InError: String);


    procedure CleanUpConsumer;
    procedure CleanUpProducer;

    function SetConfPropertie(InPropertie: String; InPropertieValue: String): Trd_kafka_conf_res_t;
    function SetTopicPropertie(InPropertie: String; InPropertieValue: String): Trd_kafka_conf_res_t;

    procedure CreateKafkaHandler;
    procedure CreateTopicHandler;
    procedure CreateDefaultTopicConf;
    procedure CreatingConsumer;
    procedure ConnectingToBroker(InBrokerName: String);
    procedure SettingPoll;
    procedure CreatingPartitionList;
    procedure CreatingConsumerTopic(InTopicName: String);
    procedure SubscribeToTopic(InTopicName: String);


    procedure Proc_dr_msg_cb(rk: Prd_kafka_t; rkmessage: Prd_kafka_message_t; opaque: Pointer); cdecl;

    procedure CreatingBrokers(InBrokerName: String);
    procedure SettingAcknowledge;
    procedure SettDeliveryReportCallback(InProcCallBack: TProc_dr_msg_cb);
    procedure CreatingProducer;
    procedure CreatingProducerTopic(InTopicName: String);
    procedure ProduceMessage(var InKey, InMessage: String);


    procedure WaitForMessages(InMaxMessageLength: Integer);

    procedure CloseConsumer;
    procedure FreePartitionList;
    procedure FreeKafka;

    procedure StartConsumer(InKafkaSetup: TKafkaSetup;
                            InOnKafkaMessageReceived: TOnKafkaMessageReceived;
                            InOnKafkaMessageEOF: TOnKafkaMessageEOF;
                            InOnKafkaMessageErr: TOnKafkaMessageErr;
                            InOnKafkaTick: TOnKafkaTick;
                            InMaxMessageSize: Integer
      );

    procedure StartProducer(InKafkaSetup: TKafkaSetup;InProcCallBack: TProc_dr_msg_cb);
  end;

  { TKafkaConsumer }

  TKafkaConsumer = class (TKafkaClass)
  public
    constructor Create(InIsConsole: Boolean);
    destructor Destroy; override;
  end;

  { TKafkaProducer }

  TKafkaProducer = class (TKafkaClass)
  public
    constructor Create(InIsConsole: Boolean);
    destructor Destroy; override;
  end;


var InitTKafkaSetup: TKafkaSetup = ({%H-});

function  GetKafkaErrorCode: Trd_kafka_resp_err_t;
function  GetKafkaErrorText(InErrorCode: cint): String;
procedure RaiseKafkaError(InErrNo: Integer; InErrMsg: String; InToStdOut: Boolean);
procedure RaiseKafkaErrorIfExists(InErrNo: Integer; InToStdOut: Boolean);
procedure KafkaReadConfiguration(InIniFile: TIniFile; InSection: String; var OutKafkaSetup: TKafkaSetup); overload;
procedure KafkaReadConfiguration(InIniFileName: String; InSection: String; var OutKafkaSetup: TKafkaSetup); overload;


procedure KafkaWriteStatus(InString: String; InToStdOut: Boolean);


implementation

procedure KafkaWriteStatus(InString: String; InToStdOut: Boolean);
begin
  if InToStdOut then begin;
    Writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ': ' + InString);
  end;
end;

function GetKafkaErrorCode: Trd_kafka_resp_err_t;
begin
  Result := (Kafka.rd_kafka_last_error);
end;

function GetKafkaErrorText(InErrorCode: cint): String;
var MyErrPChar: PChar;
    MyResult: String;
begin
  MyResult:= '';
  if InErrorCode <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
    MyErrPChar := rd_kafka_err2name(InErrorCode);
    MyResult := String(MyErrPChar);
  end;
  Result := MyResult;
end;

procedure RaiseKafkaError(InErrNo: Integer; InErrMsg: String; InToStdOut: Boolean);
begin
  KafkaWriteStatus('Kafka error code: ' + IntToStr(InErrNo), InToStdOut);
  KafkaWriteStatus('Kafka error: ' + InErrMsg, InToStdOut);
  raise EKafkaError.Create(InErrNo, InErrMsg);
end;

procedure RaiseKafkaErrorIfExists(InErrNo: Integer; InToStdOut: Boolean);
begin
  if InErrNo <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
    RaiseKafkaError(InErrNo, rd_kafka_err2name(InErrNo), InToStdOut);
  end;
end;

{ TKafkaProducer }

constructor TKafkaProducer.Create(InIsConsole: Boolean);
begin
  inherited Create(InIsConsole);
  _IsProducer := True;
end;

destructor TKafkaProducer.Destroy;
begin
  inherited Destroy;
end;

{ TKafkaConsumer }

constructor TKafkaConsumer.Create(InIsConsole: Boolean);
begin
  inherited Create(InIsConsole);
  _IsProducer := False;
end;

destructor TKafkaConsumer.Destroy;
begin
  inherited Destroy;
end;

{ EKafkaError }

constructor EKafkaError.Create(InErrNo: Integer; InErrMsg: String);
begin
  inherited Create(InErrMsg);
  _ErrNo := InErrNo;
  _ErrMsg := InErrMsg;
end;

destructor EKafkaError.Destroy;
begin
  inherited Destroy;
end;

{ TKafkaClass }

constructor TKafkaClass.Create(InIsConsole: Boolean);
begin
  inherited Create;
  _FormatSettings.DecimalSeparator := '.';
  _FormatSettings.ThousandSeparator := ',';
  _FormatSettings.DateSeparator:='-';
  _FormatSettings.TimeSeparator:=':';
  _FormatSettings.LongDateFormat:='yyyy-mm-dd';
  _FormatSettings.ShortDateFormat:='yyyy-mm-dd';
  _FormatSettings.LongTimeFormat:='hh:nn:ss.zzz';
  _FormatSettings.ShortTimeFormat:='hh:nn:ss.zzz';

  _IsConsole := InIsConsole;
  _IsProducer := False;
end;

destructor TKafkaClass.Destroy;
begin
  try
    if _IsProducer = False then begin
      CleanUpConsumer;
    end
    else begin
      CleanUpProducer;
    end;
  except
    // I dont care about error
  end;
  inherited Destroy;
end;

procedure TKafkaClass.ProcOnKafkaMessageReceived(InMessage: String; InKey: String;
  OutMsg: Prd_kafka_message_t);
var MyMsgTime1: TDateTime;
    MyMsgTime2: TDateTime;
    MyDelta: Int64;
    MyFormatSettings: TFormatSettings;
begin
  try
    MyFormatSettings.DecimalSeparator := '.';
    MyFormatSettings.ThousandSeparator := ',';
    MyFormatSettings.DateSeparator:='-';
    MyFormatSettings.TimeSeparator:=':';
    MyFormatSettings.LongDateFormat:='yyyy-mm-dd';
    MyFormatSettings.ShortDateFormat:='yyyy-mm-dd';
    MyFormatSettings.LongTimeFormat:='hh:nn:ss.zzz';
    MyFormatSettings.ShortTimeFormat:='hh:nn:ss.zzz';
    try
      MyMsgTime1 := StrToDateTime(InMessage, MyFormatSettings);
    except
      MyMsgTime1 := Now;
    end;
    MyMsgTime2 := Now;
    MyDelta := Trunc((MyMsgTime2 - MyMsgTime1) / OneMillisecond);
    KafkaWriteStatus('RecvMessage: ' + InKey + '=' + InMessage + '; Delta: ' + IntToStr(MyDelta), _IsConsole);
  except
    on E: Exception do begin
      KafkaWriteStatus('RecvMessageError: ' + E.Message + '; Key: ' + InKey + '=' + InMessage, _IsConsole);
    end;
  end;
end;

procedure TKafkaClass.ProcOnKafkaMessageEOF(InMessage: String);
begin

end;

procedure TKafkaClass.ProcOnKafkaMessageErr(InError: String);
begin

end;

procedure TKafkaClass.CleanUpConsumer;
var MyRun: Integer;
begin
  if _Rk <> nil then begin
    MyRun := 5;
    while (MyRun > 0) and (rd_kafka_wait_destroyed(1000) = -1) do begin
      MyRun := MyRun - 1;
      KafkaWriteStatus('Waiting for librdkafka to decommission\n', _IsConsole);
    end;

    if (MyRun <= 0) then begin
      // rd_kafka_dump(@stdout, _Rk);
    end;
  end;

  CloseConsumer;
  FreePartitionList;
  FreeKafka;
end;

procedure TKafkaClass.CleanUpProducer;
var MyRetVal: Trd_kafka_conf_res_t;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  KafkaWriteStatus('Closing Producer', _IsConsole);
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyLastErrorCode := RD_KAFKA_CONF_OK;

  // Wait for final messages to be delivered or fail.
  // rd_kafka_flush() is an abstraction over rd_kafka_poll() which
  // waits for all messages to be delivered.
  KafkaWriteStatus('Flushing final messages..', _IsConsole);
  rd_kafka_flush(_rk, 10*1000); // wait for max 10 seconds

  KafkaWriteStatus('Destroy topic object', _IsConsole);
  rd_kafka_topic_destroy(_rkt);

  KafkaWriteStatus('Destroy producer instance', _IsConsole);
  rd_kafka_destroy(_rk);

  KafkaWriteStatus('Free partition list', _IsConsole);
end;

function TKafkaClass.SetConfPropertie(InPropertie: String;
  InPropertieValue: String): Trd_kafka_conf_res_t;
var MyRetVal: Trd_kafka_conf_res_t;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyRetVal := RD_KAFKA_CONF_OK;
  KafkaWriteStatus('SetConfPropertie ' + InPropertie + '=' + InPropertieValue, _IsConsole);

  MyRetVal := rd_kafka_conf_set(_Conf, PChar(InPropertie), PChar(InPropertieValue), PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    KafkaWriteStatus('Failed ' + InPropertie + ': ' + InPropertieValue + '-> ' + IntToStr(MyRetVal) + ':' + String(errstr), _IsConsole);
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyRetVal, String(errstr), _IsConsole);
  end;
  Result := MyRetVal;
end;

function TKafkaClass.SetTopicPropertie(InPropertie: String;
  InPropertieValue: String): Trd_kafka_conf_res_t;
var MyRetVal: Trd_kafka_conf_res_t;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyRetVal := RD_KAFKA_CONF_OK;

  KafkaWriteStatus('SettTopicPropertie ' + InPropertie + '=' + InPropertieValue, _IsConsole);

  MyRetVal := rd_kafka_topic_conf_set(_Topic_conf, Pchar(InPropertie), PChar(InPropertieValue), PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    KafkaWriteStatus('TopicFailed ' + InPropertie + ': ' + InPropertieValue + '-> ' + IntToStr(MyRetVal) + ':' + String(errstr), _IsConsole);
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyRetVal, String(errstr), _IsConsole);
  end;
  Result := MyRetVal;
end;

procedure TKafkaClass.CreateKafkaHandler;
begin
  KafkaWriteStatus('Creating Kafka Handler', _IsConsole);
  _Conf := rd_kafka_conf_new();
  RaiseKafkaErrorIfExists(GetKafkaErrorCode, _IsConsole);
end;

procedure TKafkaClass.CreateTopicHandler;
begin
  KafkaWriteStatus('Creating Topic Handler', _IsConsole);
  _Topic_conf := rd_kafka_topic_conf_new();
  RaiseKafkaErrorIfExists(GetKafkaErrorCode, _IsConsole);
end;

procedure TKafkaClass.CreateDefaultTopicConf;
var MyRetVal: Trd_kafka_conf_res_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyRetVal := RD_KAFKA_CONF_OK;

  KafkaWriteStatus('Creating default topic conf', _IsConsole);
  rd_kafka_conf_set_default_topic_conf(_Conf, _Topic_conf);
  RaiseKafkaErrorIfExists(GetKafkaErrorCode, _IsConsole);
end;

procedure TKafkaClass.CreatingConsumer;
var MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyLastErrorCode := RD_KAFKA_CONF_OK;
  _rk := nil;
  KafkaWriteStatus('Creating consumer', _IsConsole);
  _Rk := rd_kafka_new(RD_KAFKA_CONSUMER, _Conf, PChar(errstr), errstr_size);
  if _Rk = nil then begin
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyLastErrorCode, String(errstr), _IsConsole);
  end;
end;

procedure TKafkaClass.ConnectingToBroker(InBrokerName: String);
var MyRetInt32: Int32;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyRetInt32 := 0;

  KafkaWriteStatus('Connecting to brokers', _IsConsole);
  MyRetInt32 := rd_kafka_brokers_add(_Rk, PChar(InBrokerName));
  if MyRetInt32 = 0 then begin
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(-1, 'Failed connect to broker', _IsConsole)
  end;
end;

procedure TKafkaClass.SettingPoll;
var MyRetInt32: Int32;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    MyRetVal: Trd_kafka_resp_err_t;
begin
  KafkaWriteStatus('Setting poll', _IsConsole);
  MyRetVal := rd_kafka_poll_set_consumer(_rk);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyRetVal, 'Unable to set poll', _IsConsole);
  end;
end;

procedure TKafkaClass.CreatingPartitionList;
var MyLastErrorCode: Trd_kafka_resp_err_t;
begin
  _Topics := nil;
  KafkaWriteStatus('Creating partition list', _IsConsole);
  _Topics := rd_kafka_topic_partition_list_new(1);
  if _Topics <> nil then begin
    KafkaWriteStatus('rd_kafka_topic_partition_list_new count: ' + IntToStr(_Topics^.cnt), _IsConsole);
  end
  else begin
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(-1, 'Unable to create partition list', _IsConsole);
  end;
end;

procedure TKafkaClass.CreatingConsumerTopic(InTopicName: String);
var MyLastErrorCode: Trd_kafka_resp_err_t;
begin
  KafkaWriteStatus('Creating topic', _IsConsole);
  _Topic := rd_kafka_topic_partition_list_add(_Topics, PChar(InTopicName), 0);
  if _Topics <> nil then begin
    _Topics^.cnt := 1;
  end
  else begin
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(-1, 'Unable to create topic', _IsConsole);
  end;
end;

procedure TKafkaClass.SubscribeToTopic(InTopicName: String);
var MyLastErrorCode: Trd_kafka_resp_err_t;
    MyRetVal: Trd_kafka_resp_err_t;
begin
  KafkaWriteStatus('Subscribe to topic: ' + InTopicName, _IsConsole);
  MyRetVal := rd_kafka_subscribe(_Rk, _Topics);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyRetVal, 'Unable to subsribe to topic: ' + InTopicName, _IsConsole);
  end;
end;

procedure TKafkaClass.Proc_dr_msg_cb(rk: Prd_kafka_t;
  rkmessage: Prd_kafka_message_t; opaque: Pointer); cdecl;
begin
  if (rkmessage^.err <> 0) then begin
    KafkaWriteStatus(Format('Message delivery failed: %s', [rd_kafka_err2str(rkmessage^.err)]), _IsConsole);
  end
  else begin
    KafkaWriteStatus(Format('Message delivered (bytes: %d, partition: %d)', [rkmessage^.len, rkmessage^.partion]), _IsConsole);
  end;
end;

procedure TKafkaClass.CreatingBrokers(InBrokerName: String);
var MyRetVal: Trd_kafka_conf_res_t;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  KafkaWriteStatus('Creating Brokers', _IsConsole);
  MyRetVal := rd_kafka_conf_set(_conf, 'bootstrap.servers', PChar(InBrokerName), PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    KafkaWriteStatus('Failed to create brokers, rd_kafka_conf_set: ' + String(errstr), _IsConsole);
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyLastErrorCode, 'Unable to create broker: ' + String(errstr), _IsConsole);
  end;
end;

procedure TKafkaClass.SettingAcknowledge;
var MyRetVal: Trd_kafka_conf_res_t;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  KafkaWriteStatus('Setting Acknowledge', _IsConsole);
  MyRetVal := rd_kafka_conf_set(_conf, 'acks', '0', PChar(errstr), errstr_size);
  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    KafkaWriteStatus('Failed to set acks, rd_kafka_conf_set: ' + String(errstr), _IsConsole);
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyLastErrorCode, 'Unable to set acks: ' + String(errstr), _IsConsole);
  end;
end;

procedure TKafkaClass.SettDeliveryReportCallback(InProcCallBack: TProc_dr_msg_cb
  );
var MyRetVal: Trd_kafka_conf_res_t;
    MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  KafkaWriteStatus('Set Delivery Report Callback', _IsConsole);

  // Set the delivery report callback.
  // This callback will be called once per message to inform
  // the application if delivery succeeded or failed.
  // See dr_msg_cb() above.
  rd_kafka_conf_set_dr_msg_cb(_conf, InProcCallBack);
  MyLastErrorCode := GetKafkaErrorCode;
  if MyLastErrorCode <> RD_KAFKA_RESP_ERR_NO_ERROR then begin
    KafkaWriteStatus('Failed to set the delivery report callback, rd_kafka_conf_set_dr_msg_cb: ' + String(errstr), _IsConsole);
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyLastErrorCode, 'Unable to set the delivery report callback: ' + String(errstr), _IsConsole);
  end;
end;

procedure TKafkaClass.CreatingProducer;
var MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  MyLastErrorCode := RD_KAFKA_CONF_OK;
  _rk := nil;
  KafkaWriteStatus('Creating Producer', _IsConsole);
  _Rk := rd_kafka_new(RD_KAFKA_PRODUCER, _Conf, PChar(errstr), errstr_size);
  if _Rk = nil then begin
    MyLastErrorCode := GetKafkaErrorCode;
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyLastErrorCode, String(errstr), _IsConsole);
  end;
end;

procedure TKafkaClass.CreatingProducerTopic(InTopicName: String);
var MyLastErrorCode: Trd_kafka_resp_err_t;
    errstr: array[0..512] of char;
    errstr_size: Int32;
begin
  errstr := '';
  errstr_size := SizeOf(errstr);
  KafkaWriteStatus('Creating Producer Topic', _IsConsole);
  _Rkt := rd_kafka_topic_new(_rk, PChar(InTopicName), nil);
  if _Rkt = nil then begin
    MyLastErrorCode := GetKafkaErrorCode;
    KafkaWriteStatus('Failed to create producer topic: ' + IntToStr(MyLastErrorCode), _IsConsole);
    RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
    RaiseKafkaError(MyLastErrorCode, String(errstr), _IsConsole);
  end;
end;

procedure TKafkaClass.ProduceMessage(var InKey, InMessage: String);
var MyLen, MyKeyLen: Integer;
var MyRetVal: Trd_kafka_conf_res_t;
    MyTopicName: String;
begin
  MyTopicName := rd_kafka_topic_name(_rkt);
  MyLen := Length(InMessage);
  MyKeyLen := Length(InKey);

  MyRetVal := rd_kafka_produce(_rkt,
                               RD_KAFKA_PARTITION_UA,
                               RD_KAFKA_MSG_F_COPY,
                               @InMessage[1],
                               MyLen,
                               @InKey[1],
                               MyKeyLen,
                               nil);

  if MyRetVal <> RD_KAFKA_CONF_OK then begin
    KafkaWriteStatus(Format('% Failed to produce message for topic %s: %s"',
                 [MyTopicName,
                  GetKafkaErrorText(GetKafkaErrorCode)]), _IsConsole);

    if (rd_kafka_last_error() = RD_KAFKA_RESP_ERR__QUEUE_FULL)  then begin
      KafkaWriteStatus('Received message RD_KAFKA_RESP_ERR__QUEUE_FULL', _IsConsole);
      rd_kafka_poll(_rk, 1000);
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
    KafkaWriteStatus(Format('Enqueued message (%s Key) (%d bytes) for topic %s: %s', [InKey, MyLen, MyTopicName, InMessage]), _IsConsole);
    rd_kafka_poll(_rk, 0); //non-blocking
  end;
end;

procedure TKafkaClass.WaitForMessages(InMaxMessageLength: Integer);
var MyMessage: String;
    MyKey: String;
begin
  _BStop := False;
  if _OnKafkaTick <> nil then begin
    _OnKafkaTick('WAITFORMESSAGES-START');
  end;
  while true do begin
    if _BStop = true then begin
      if _OnKafkaTick <> nil then begin
        _OnKafkaTick('WAITFORMESSAGES-STOP');
      end;
      Break;
    end;

    if _IsConsole then begin
      if KeyPressed then begin           //  <--- CRT function to test key press
        if ReadKey = ^C then begin       // read the key pressed
          KafkaWriteStatus('Ctrl-C pressed', _IsConsole);
          _BStop := True;
          Break;
        end;
      end;
    end;

    _Rkmessage := nil;
    try
      _Rkmessage := rd_kafka_consumer_poll(_rk, 100);
      if _OnKafkaTick <> nil then begin
        _OnKafkaTick('WAITFORMESSAGES-POLL');
      end;
      if (_Rkmessage <> nil)  then begin
        if _Rkmessage^.err = RD_KAFKA_RESP_ERR__PARTITION_EOF then begin
          if _OnKafkaMessageEOF <> nil then begin
            _OnKafkaMessageEOF(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now, _FormatSettings) + ': RD_KAFKA_RESP_ERR__PARTITION_EOF');
          end
          else begin
            KafkaWriteStatus('Read RD_KAFKA_RESP_ERR__PARTITION_EOF', _IsConsole);
          end;
        end
        else if (_Rkmessage^.err = RD_KAFKA_RESP_ERR__UNKNOWN_PARTITION) or
                (_Rkmessage^.err = RD_KAFKA_RESP_ERR__UNKNOWN_TOPIC)
        then begin
          if _OnKafkaMessageErr <> nil then begin
            _OnKafkaMessageErr(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now, _FormatSettings) + ': RD_KAFKA_RESP_ERR__UNKNOWN_PARTITION or RD_KAFKA_RESP_ERR__UNKNOWN_TOPIC');
          end
          else begin
            KafkaWriteStatus('RD_KAFKA_RESP_ERR__UNKNOWN_PARTITION or RD_KAFKA_RESP_ERR__UNKNOWN_TOPIC', _IsConsole);
          end;
          Break;
        end
        else begin
          // I received valid message
          if _Rkmessage^.err <> 0 then begin
            if _OnKafkaMessageErr <> nil then begin
              _OnKafkaMessageErr(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now, _FormatSettings) + ': Received from topic: ' + String(PChar(_Rkmessage^.rkt)) + '; ' + 'MsgNo: ' + IntToStr(_Rkmessage^.offset) + '; ' + 'Partition: ' + IntToStr(_Rkmessage^.partion));
            end
            else begin
              if InMaxMessageLength = 0 then begin
                KafkaWriteStatus('Received from topic: ' + String(PChar(_Rkmessage^.rkt)), _IsConsole);
              end
              else begin
                KafkaWriteStatus('Received from topic: ' + Copy(String(PChar(_Rkmessage^.rkt)), 1, InMaxMessageLength), _IsConsole);
              end;
              KafkaWriteStatus('MsgNo: ' + IntToStr(_Rkmessage^.offset), _IsConsole);
              KafkaWriteStatus('Partition: ' + IntToStr(_Rkmessage^.partion), _IsConsole);
            end;
          end
          else begin
            if InMaxMessageLength = 0 then begin
              KafkaWriteStatus(Format('%s Message (topic %s, part %d, offset %d, %d bytes):',
                                     [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now, _FormatSettings),
                                      String(rd_kafka_topic_name(_Rkmessage^.rkt)),
                                       _Rkmessage^.partion,
                                       _Rkmessage^.offset,
                                       _Rkmessage^.len
                                     ]), _IsConsole);
            end
            else begin
              KafkaWriteStatus(Format('%s Message (topic %s, part %d, offset %d, %d bytes):',
                                     [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now, _FormatSettings),
                                      Copy(String(rd_kafka_topic_name(_Rkmessage^.rkt)), 1, InMaxMessageLength),
                                       _Rkmessage^.partion,
                                       _Rkmessage^.offset,
                                       _Rkmessage^.len
                                     ]), _IsConsole);
            end;
            // MyString := PChar(_Rkmessage^.key);
            MyMessage := '';
            MyKey := '';
            if _OnKafkaMessageReceived <> nil then begin
              if _Rkmessage^.len > 0 then begin
                SetString(MyMessage, PChar(_Rkmessage^.payload), _Rkmessage^.len);
              end;
              if _Rkmessage^.key_len > 0 then begin
                SetString(MyKey, PChar(_Rkmessage^.key), _Rkmessage^.key_len);
              end;
              if InMaxMessageLength = 0 then begin
                _OnKafkaMessageReceived(MyMessage, MyKey, _Rkmessage);
              end
              else begin
                _OnKafkaMessageReceived(Copy(MyMessage, 1, InMaxMessageLength), MyKey, _Rkmessage);
              end;
            end
            else begin
              if InMaxMessageLength = 0 then begin
              	KafkaWriteStatus(Format('Key: %s=%s', [MyKey, MyMessage]), _IsConsole);
              end
              else begin
              	KafkaWriteStatus(Format('Key: %s=%s', [MyKey, Copy(MyMessage, 1, 256)]), _IsConsole);
              end;
            end;
            MyMessage := '';
            MyKey := '';
          end;
        end;
        rd_kafka_message_destroy(_Rkmessage);
        _Rkmessage := nil;
      end;
    except
      on E: Exception do begin
        if _Rkmessage <> nil then begin
          rd_kafka_message_destroy(_Rkmessage);
        end;
      end;
    end;
  end;
  if _OnKafkaTick <> nil then begin
    _OnKafkaTick('WAITFORMESSAGES-END');
  end;
end;


procedure TKafkaClass.CloseConsumer;
var MyLastErrorCode: Trd_kafka_resp_err_t;
    MyRetVal: Trd_kafka_resp_err_t;
begin
  if _Rk <> nil then begin
    KafkaWriteStatus('Closing Consumer', _IsConsole);
    MyRetVal := rd_kafka_consumer_close(_Rk);
    if MyRetVal <> RD_KAFKA_CONF_OK then begin
      MyLastErrorCode := GetKafkaErrorCode;
      RaiseKafkaErrorIfExists(MyLastErrorCode, _IsConsole);
      RaiseKafkaError(MyRetVal, 'Failed to execute rd_kafka_consumer_close', _IsConsole);
    end;
    _Rk := nil;
  end;
end;

procedure TKafkaClass.FreePartitionList;
begin
  if _Topics <> nil then begin;
    KafkaWriteStatus('Free partition list', _IsConsole);
    rd_kafka_topic_partition_list_destroy(_Topics);
    _Topics :=  nil;
  end;
end;

procedure TKafkaClass.FreeKafka;
begin
  if _Rk <> nil then begin
    KafkaWriteStatus('Free Kafka', _IsConsole);
    rd_kafka_destroy(_Rk);
  end;
end;

procedure TKafkaClass.StartConsumer(InKafkaSetup: TKafkaSetup;
  InOnKafkaMessageReceived: TOnKafkaMessageReceived;
  InOnKafkaMessageEOF: TOnKafkaMessageEOF;
  InOnKafkaMessageErr: TOnKafkaMessageErr; InOnKafkaTick: TOnKafkaTick;
  InMaxMessageSize: Integer);
var F: Integer;
    MyStrings: TStrings;
    MyPropKey, MyPropValue: String;
begin
  _OnKafkaTick := InOnKafkaTick;
  MyStrings := nil;
  try
    CreateKafkaHandler;
    CreateTopicHandler;

    if InKafkaSetup.conf_properties <> '' then begin;
      MyStrings := nil;
      MyStrings := TStringList.Create;
      MyStrings.TextLineBreakStyle := tlbsCR;
      MyStrings.Text := InKafkaSetup.conf_properties;

      for F := 0 to MyStrings.Count-1 do begin
        MyPropKey := MyStrings.Names[F];
        MyPropValue := MyStrings.ValueFromIndex[F];
        if (MyPropKey <> '') and (MyPropValue <> '') and (MyPropKey[1] <> '#') then begin
          SetConfPropertie(MyPropKey, MyPropValue);
        end;
      end;
      if MyStrings <> nil then FreeAndNil(MyStrings)
    end;

    if InKafkaSetup.topic_properties <> '' then begin;
      MyStrings := nil;
      MyStrings := TStringList.Create;
      MyStrings.TextLineBreakStyle := tlbsCR;
      MyStrings.Text := InKafkaSetup.topic_properties;

      for F := 0 to MyStrings.Count-1 do begin
        MyPropKey := MyStrings.Names[F];
        MyPropValue := MyStrings.ValueFromIndex[F];
        if (MyPropKey <> '') and (MyPropValue <> '') and (MyPropKey[1] <> '#') then begin
          SetTopicPropertie(MyPropKey, MyPropValue);
        end;
      end;
      if MyStrings <> nil then FreeAndNil(MyStrings)
    end;

    CreateDefaultTopicConf;
    CreatingConsumer;
    ConnectingToBroker(InKafkaSetup.broker);
    SettingPoll;
    CreatingPartitionList;
    CreatingConsumerTopic(InKafkaSetup.topic);
    SubscribeToTopic(InKafkaSetup.topic);

    if InOnKafkaMessageReceived = nil then begin
      _OnKafkaMessageReceived := @ProcOnKafkaMessageReceived;
    end
    else begin
      _OnKafkaMessageReceived := InOnKafkaMessageReceived;
    end;

    _OnKafkaMessageErr := InOnKafkaMessageErr;
    _OnKafkaMessageEOF := InOnKafkaMessageEOF;

    WaitForMessages(InMaxMessageSize);

    CleanUpConsumer;

  except
    on E: Exception do begin
      if MyStrings <> nil then FreeAndNil(MyStrings);
      raise;
    end;
  end;

end;

procedure TKafkaClass.StartProducer(InKafkaSetup: TKafkaSetup; InProcCallBack: TProc_dr_msg_cb);
var F: Integer;
    MyStrings: TStrings;
    MyPropKey, MyPropValue: String;
begin
  _IsProducer := True;
  MyStrings := nil;
  try
    CreateKafkaHandler;
    if InKafkaSetup.conf_properties <> '' then begin;
      MyStrings := nil;
      MyStrings := TStringList.Create;
      MyStrings.TextLineBreakStyle := tlbsCR;
      MyStrings.Text := InKafkaSetup.conf_properties;

      for F := 0 to MyStrings.Count-1 do begin
        MyPropKey := MyStrings.Names[F];
        MyPropValue := MyStrings.ValueFromIndex[F];
        if (MyPropKey <> '') and (MyPropValue <> '') and (MyPropKey[1] <> '#')  then begin
          SetConfPropertie(MyPropKey, MyPropValue);
        end;
      end;
      if MyStrings <> nil then FreeAndNil(MyStrings)
    end;

    CreatingBrokers(InKafkaSetup.broker);
    SettingAcknowledge;
    SettDeliveryReportCallback(InProcCallBack);
    CreatingProducer;
    CreatingProducerTopic(InKafkaSetup.topic);

  except
    on E: Exception do begin
      if MyStrings <> nil then FreeAndNil(MyStrings);
      raise;
    end;
  end;
end;

procedure KafkaReadConfiguration(InIniFile: TIniFile; InSection: String;
  var OutKafkaSetup: TKafkaSetup);
var MyStrings: TStringList;
begin
  OutKafkaSetup := InitTKafkaSetup;
  OutKafkaSetup.broker       := InIniFile.ReadString(InSection, 'broker', '');
  OutKafkaSetup.topic        := InIniFile.ReadString(InSection, 'topic', '');

  OutKafkaSetup.conf_section:= InIniFile.ReadString(InSection, 'conf_section', '');
  if InIniFile.SectionExists(OutKafkaSetup.conf_section) then begin
    MyStrings := nil;
    try
      MyStrings := TStringList.Create;
      InIniFile.ReadSectionValues(OutKafkaSetup.conf_section, MyStrings, []);
      MyStrings.TextLineBreakStyle := tlbsCR;
      OutKafkaSetup.conf_properties := MyStrings.Text;
      if MyStrings <> nil then FreeAndNil(MyStrings);
    except
      on E: Exception do begin
        if MyStrings <> nil then FreeAndNil(MyStrings);
      end;
    end;
  end;

  OutKafkaSetup.topic_section:= InIniFile.ReadString(InSection, 'topic_section', '');
  if InIniFile.SectionExists(OutKafkaSetup.topic_section) then begin
    MyStrings := nil;
    try
      MyStrings := TStringList.Create;
      InIniFile.ReadSection(OutKafkaSetup.topic_section, MyStrings);
      MyStrings.TextLineBreakStyle := tlbsCR;
      OutKafkaSetup.topic_properties := MyStrings.Text;
      if MyStrings <> nil then FreeAndNil(MyStrings);
    except
      on E: Exception do begin
        if MyStrings <> nil then FreeAndNil(MyStrings);
      end;
    end;
  end;
end;

procedure KafkaReadConfiguration(InIniFileName: String; InSection: String;
  var OutKafkaSetup: TKafkaSetup);
var MyIniFile: TIniFile;
begin
  OutKafkaSetup := InitTKafkaSetup;
  MyIniFile := nil;
  try
    if FileExists(InIniFileName) then begin
      MyIniFile := TIniFile.Create(InIniFileName);
      KafkaReadConfiguration(MyIniFile, InSection, OutKafkaSetup);
      if MyIniFile <> nil then begin
        FreeAndNil(MyIniFile);
      end;
    end;
  except
    if MyIniFile <> nil then begin
      FreeAndNil(MyIniFile);
    end;
  end;
end;


end.

