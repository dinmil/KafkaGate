unit ZMQLogger;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  laz2_DOM, laz2_XMLRead,
  LCLIntf,

  {$ifndef cpuarm}
  sqlite3conn, SQLite3db,
  {$endif}

  IBConnection, mssqlconn,
  odbcconn, pqconnection, oracleconnection
  {$ifndef cpuarm}
  ,mysql50conn, mysql51conn, mysql55conn, mysql55, mysql51, mysql50
  ,mysql40conn, mysql41conn, mysql41, mysql40,
  {$endif cpuarm}

  FavSystem, FavUtils, FavProtoLib, FavDBConnection, FavDBUtils, FavSemaphore,
  zmq, ZMQClass
  ;

type
  T0MQLogRecord = record
    debug_level: string;      // DEBUG, INFO, NOTE, ERROR, ALERT
    severity: int64;          // 0..9
    message_type: string;     // user message type - duration, login,...
    code: int64;              // integer;

    msg_in: string;           // input into function -- formal message
    msg_out: string;          // output from function -- formal description
    debug_info: string;       // extended debug info data -- formal data

    duration: int64;          // message duration - cumulative (immediatelly before existing function - copy to http response stream)
    duration_prepare: int64;  // message preparation duration (http prepare) -- new
    msg_size: int64;          //  message size -- new

    client_timestamp: TDateTime;  // client timestamp
    server_timestamp: TDateTime;  // server timestamp

    address: string;             // ip address of machine or machine name
    application: string;         // application name
    application_path: string;    // full application path
    application_version: string; // application version
    os: string;                  // operating system
    os_version: string;          // operating system version
    thread: integer;             // thread process id
    main_thread: boolean;        // is it main thread of applicetion
    msg_id_client: int64;        // client message id
  end;

  { TLogThreadSaver }

  // This class is used to save log message to database
  TLogThreadSaver = class(TThread)
  private
    { Private declarations }
  protected
    { Protected declarations }
    procedure Execute; override;
  public
    _BFinished: Boolean;
    _PQueue: TFavQueue;

    _ProtoLog, _ProtoErr: TFavProto;

    _ThreadNo: Integer;
    _Connection: TFavConnection;
    _ConnectionParams: TFavRecConnection;
    _Query: TFavQuery;

    constructor Create(InThreadNo: Integer; InConnectionParams: TFavRecConnection; InQueue: TFavQueue);
    destructor Destroy; override;

    procedure SaveLog(InString: String);
    procedure SendShutDownMessage;
  end;


  { TLogThreadForwarder }
  // This class is used to send log message to log server via 0MQ
  // Client thread put log message to queue and forwarder thread send it to
  // log server
  TLogThreadForwarder = class(TThread)
  private
    { Private declarations }
  protected
    { Protected declarations }
    procedure Execute; override;
  public
    _BFinished: Boolean;               // finished boolean variable - if true thread is free to destroy
    _PLogQueue: TFavQueue;             // this queue holds messages which have to be sent to log server

    _LogDirectory: TFavString;         // proto files location
    _ProtoLog, _ProtoErr: TFavProto;   // proto files

    _ThreadNo: Integer;                // thread number - optional - usually there is only one log forwarder per application

    _PContext: pointer;                // pointer to 0mq context - passed in constructor - onyl one 0mq context per application
    _LogServer: T0MQSocket;            // log server socket

    _Settings: T0MQSetup;              // settings for log server queue

    _SendError: TFavInteger;           // send error counter
    _SendError0mq: TFavInteger;        // send error counter for 0mq errors
    _SendCount: TFavInteger;           // send count
    _LastErrorMessage: TFavString;     // last error message
    _LastErrorNo: TFavInteger;         // last error number
    _LastErrorTimestamp: TFavDateTime; // last error timestamp

    constructor Create(InContext: pointer;                // context is created when application starts
                       InThreadNo: Integer;               // optional thread number
                       InLogDirectory: TFavString;        // proto files log directory
                       InQueue: TFavQueue;                // queue
                       InSettings: T0MQSetup              // log server settings
                       );
    destructor Destroy; override;

    procedure ConnectToLogServer;                  // connecto to log server
    procedure SendLogMessage(InString: String);    // send one log message string
    procedure SendShutDownMessage;                 // send shutdown message for queue
    procedure ShutDown;                            // send shutdowm message and wait for the end
  end;

const LOG_LEVEL_DEBUG = 'DEBUG';
const LOG_LEVEL_INFO  = 'INFO';
const LOG_LEVEL_ALERT = 'ALERT';
const LOG_LEVEL_EMERG = 'EMERG';
const LOG_LEVEL_NONE  = 'NONE';

var InitT0MQLogRecord: T0MQLogRecord = ({%H-});
//var FAV_SYS_SEND_TO_LOG: Boolean = True;
var FAV_SYS_LOG_LEVEL: String = LOG_LEVEL_EMERG;

function  LogEncode(var InLog: T0MQLogRecord): String;
procedure LogDecode(InString: String; var OutLog: T0MQLogRecord);
procedure LogToFile(InFileName: TFavString; var InLog: T0MQLogRecord);
procedure LogToProto(InProto: TFavProto; var InLog: T0MQLogRecord);
procedure LogToDB(InConnection: TFavConnection; InQuery: TFavQuery; var InLog: T0MQLogRecord);
procedure LogPrepareQuery(InConnection: TFavConnection; OutQuery: TFavQuery);
procedure LogCreateTable(InConnection: TFavConnection);
function  LogCreateDBConnection(InConnectionParams: TFavRecConnection): TFavConnection;
procedure LogCreateMessage(var OutLog: T0MQLogRecord;
                           InDebugLevel: TFavString;
                           InSeverity: TFavInteger;
                           InMessageType: TFavString;
                           InAddress: TFavString;
                           InApplicationVersion: TFavString;
                           InErrorCode: TFavInteger;
                           InMsgIn: TFavString;
                           InMsgOut: TFavString;
                           InDebugInfo: TFavString;
                           InDuration: TFavInteger;
                           InDurationPrepare: TFavInteger;
                           InMsgSize: TFavInteger
                           );
function LogCreateMessageString(var OutLog: T0MQLogRecord;
                           InDebugLevel: TFavString;
                           InSeverity: TFavInteger;
                           InMessageType: TFavString;
                           InAddress: TFavString;
                           InApplicationVersion: TFavString;
                           InErrorCode: TFavInteger;
                           InMsgIn: TFavString;
                           InMsgOut: TFavString;
                           InDebugInfo: TFavString;
                           InDuration: TFavInteger;
                           InDurationPrepare: TFavInteger;
                           InMsgSize: TFavInteger
                           ): TFavString;
procedure LogToQueue(InProto: TFavProto; InQueue: TFavQueue; InLogMessage: TFavString);



implementation

{ TLogThreadForwarder }

procedure TLogThreadForwarder.Execute;
var MyString: String;
begin
  FavLProtoLn(_ProtoLog, dlEmerg, 'Starting thread');
  _BFinished := False;
  while true do begin
    MyString := _PLogQueue.GetData;
    if MyString = 'BSHUTDOWN=TRUE' then begin
      FavLProtoLn(_ProtoLog, dlEmerg, 'Received shutdown message');
      Break;
    end
    else begin
      // Insert data into database
      SendLogMessage(MyString);
    end;
  end;
  FavLProtoLn(_ProtoLog, dlEmerg, 'Destroying thread');
  _BFinished := True;
end;

constructor TLogThreadForwarder.Create(InContext: pointer; InThreadNo: Integer;
  InLogDirectory: TFavString; InQueue: TFavQueue; InSettings: T0MQSetup);
begin
  _BFinished := False;
  _PLogQueue := InQueue;
  _ThreadNo := InThreadNo;
  _Settings := InSettings;

  _LogDirectory := InLogDirectory;
  // ensure that last character is path separator
  _LogDirectory := FavCorrectFileName(_LogDirectory);
  if Length(_LogDirectory) > 0 then begin
    if _LogDirectory[Length(_LogDirectory)] <> FAV_SYS_PATH_DELIM then begin
      _LogDirectory := _LogDirectory + FAV_SYS_PATH_DELIM;
    end;
  end;
  _PContext := InContext;

  // create log files
  _ProtoLog := TFavProto.Create(_LogDirectory + 'LogForwarder.log', 1024 * 1024 * 10);
  _ProtoErr := TFavProto.Create(_LogDirectory + 'LogForwarder.err', 1024 * 1024 * 10);

  ConnectToLogServer;

  inherited Create(True);
end;

destructor TLogThreadForwarder.Destroy;
begin
  //  _PLogQueue.CleanQueue;
  //  FavFreeAndNil(_PLogQueue);
  if _LogServer <> nil then begin
    FavLProtoLn(_ProtoLog, dlEmerg, 'Closing socket');
    _LogServer.CloseSocket;
  end;
  FavLProtoLn(_ProtoLog, dlEmerg, 'Free LogServer socket');
  FreeAndNil(_LogServer);

  FavLProtoLn(_ProtoLog, dlEmerg, 'Destroying proto objects');
  if _ProtoLog <> nil then FavFreeAndNil(_ProtoLog);
  if _ProtoErr <> nil then FavFreeAndNil(_ProtoErr);
  inherited Destroy;
end;

procedure TLogThreadForwarder.ConnectToLogServer;
begin
  try
    FavLProtoLn(_ProtoLog, dlEmerg, 'Creating 0mq Socket: ' + _Settings.address);
    _LogServer := T0MQSocket.Create(_PContext);

    FavLProtoLn(_ProtoLog, dlEmerg, 'Get Socket: ' + _Settings.address);
    if _Settings.socket_type = 'PUB' then begin
      _LogServer.GetSocket(ZMQ_PUB);
    end
    else begin
      _LogServer.GetSocket(ZMQ_PUSH);
    end;

    FavLProtoLn(_ProtoLog, dlEmerg, 'SetHWM: ' + FavToString(_Settings.hwm));
    _LogServer.SetSockOptInteger(ZMQ_SNDHWM, _Settings.hwm);

    FavLProtoLn(_ProtoLog, dlEmerg, 'SetTimeout: ' + FavToString(_Settings.send_timeout));
    _LogServer.SetSockOptInteger(ZMQ_SNDTIMEO, _Settings.send_timeout);

    FavLProtoLn(_ProtoLog, dlEmerg, 'Connect socket: ' + _Settings.address);
    _LogServer.ConnectSocket(_Settings.address);
  except
    on E: Exception do begin
        FavLProtoLn(_ProtoLog, dlEmerg, 'ConnectToLogServer Error: ' + E.Message);
    end;
  end;
end;

procedure TLogThreadForwarder.SendLogMessage(InString: String);
//var MySendRV: Integer;
begin
  try
    if _Settings.send_timeout <= 0 then begin
      //MySendRV :=
      _LogServer.Send(PChar(InString), Length(InString), 0);
    end
    else begin
      {$WARNINGS OFF}
      // MySendRV :=
      _LogServer.Send(PChar(InString), Length(InString), ZMQ_NOBLOCK);
      {$WARNINGS ON}
    end;
    _SendCount := _SendCount + 1;
  except
    on E: E0MQError do begin
      _SendError0mq := _SendError0mq + 1;
      _LastErrorMessage := E._ErrMsg;
      _LastErrorNo := E._ErrNo;
      _LastErrorTimestamp := FavUTCNow;
      FavLProtoLn(_ProtoLog, dlEmerg, FAV_SYS_ASTERIX_LINE);
      FavLProtoLn(_ProtoLog, dlEmerg, 'SendLogMessage0mqError: ' + _LastErrorMessage);
      FavLProtoLn(_ProtoLog, dlEmerg, 'SendLogMessage0mqErrorCode: ' + FavToString(_LastErrorNo));
      FavLProtoLn(_ProtoLog, dlEmerg, 'String: ' + InString);
      FavLProtoLn(_ProtoLog, dlEmerg, FAV_SYS_ASTERIX_LINE);

      FavLProtoLn(_ProtoErr, dlEmerg, FAV_SYS_ASTERIX_LINE);
      FavLProtoLn(_ProtoErr, dlEmerg, 'SendLogMessage0mqError: ' + _LastErrorMessage);
      FavLProtoLn(_ProtoErr, dlEmerg, 'SendLogMessage0mqErrorCode: ' + FavToString(_LastErrorNo));
      FavLProtoLn(_ProtoErr, dlEmerg, 'String: ' + InString);
      FavLProtoLn(_ProtoErr, dlEmerg, FAV_SYS_ASTERIX_LINE);
    end;
    on E: Exception do begin
      _SendError := _SendError + 1;
      _LastErrorMessage := E.Message;
      _LastErrorNo := -1;
      _LastErrorTimestamp := FavUTCNow;

      FavLProtoLn(_ProtoLog, dlEmerg, FAV_SYS_ASTERIX_LINE);
      FavLProtoLn(_ProtoLog, dlEmerg, 'SendLogMessageError: ' + _LastErrorMessage);
      FavLProtoLn(_ProtoLog, dlEmerg, 'String: ' + InString);
      FavLProtoLn(_ProtoLog, dlEmerg, FAV_SYS_ASTERIX_LINE);

      FavLProtoLn(_ProtoErr, dlEmerg, FAV_SYS_ASTERIX_LINE);
      FavLProtoLn(_ProtoErr, dlEmerg, 'SendLogMessageError: ' + _LastErrorMessage);
      FavLProtoLn(_ProtoErr, dlEmerg, 'String: ' + InString);
      FavLProtoLn(_ProtoErr, dlEmerg, FAV_SYS_ASTERIX_LINE);
    end;
  end;
end;

procedure TLogThreadForwarder.SendShutDownMessage;
var MyString: String;
begin
  MyString := 'BSHUTDOWN=TRUE';
  _PLogQueue.PutData(MyString);

  // wait for thread to finish
  while _BFinished = False do begin
    Sleep(1)
  end;
end;

procedure TLogThreadForwarder.ShutDown;
begin
  SendShutDownMessage;
  while true do begin
    if _BFinished then begin
      Break;
    end;
    Sleep(10);
  end;
end;

{ TLogThreadSaver }

procedure TLogThreadSaver.Execute;
var MyString: String;
begin
  while true do begin
    MyString := _PQueue.GetData;
    if MyString = 'BSHUTDOWN=TRUE' then begin
      Break;
    end
    else begin
      // Insert data into database
      SaveLog(MyString);
    end;
  end;
  _BFinished := True;
end;

constructor TLogThreadSaver.Create(InThreadNo: Integer;
  InConnectionParams: TFavRecConnection; InQueue: TFavQueue);
begin
  _BFinished := False;
  _PQueue := InQueue;
  _ThreadNo := InThreadNo;
  _ConnectionParams := InConnectionParams;

  _Connection := LogCreateDBConnection(_ConnectionParams);

  _Query := TFavQuery.Create(nil);
  LogPrepareQuery(_Connection, _Query);

  inherited Create(True);
end;

destructor TLogThreadSaver.Destroy;
begin
//  _PQueue.CleanQueue;
//  FavFreeAndNil(_PQueue);
  if _Query <> nil then FavFreeAndNil(_Query);
  if _Connection <> nil then begin
    FavDBDestroyConnection(_Connection);
  end;
  inherited Destroy;
end;

procedure TLogThreadSaver.SaveLog(InString: String);
var MyFunctionName: TFavString;
    MyStartTime, MyFinishTime: TFavDateTime;
    MyQuery: TFavQuery;
    MyError: TFavString;
    MyIStartedTransaction: TFavBoolean;
    MyLog: T0MQLogRecord;
begin
  MyQuery := nil;
  MyFunctionName := 'LogToDB';
  FavProtoStart(_ProtoLog, _ProtoErr, '', MyFunctionName);
  MyStartTime := FavUTCNow;
  MyIStartedTransaction := False;

  try
    MyQuery := _Query;

    MyLog := InitT0MQLogRecord;
    LogDecode(InString, MyLog);

    MyIStartedTransaction := FavDbUtils.FavDBStartTransaction(_ProtoLog, _ProtoErr, _Connection);

    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'msg_in', MyLog.msg_in);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'msg_out', MyLog.msg_out);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'debug_info', MyLog.debug_info);

    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'debug_level', MyLog.debug_level, 16);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'severity', MyLog.severity);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'message_type', MyLog.message_type, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'code', MyLog.code);

    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'duration', MyLog.duration);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'duration_prepare', MyLog.duration_prepare);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'msg_size', MyLog.msg_size);

    FavDBSetParamDateTime(_ProtoLog, _ProtoErr, MyQuery, 'client_timestamp', MyLog.client_timestamp);
    FavDBSetParamDateTime(_ProtoLog, _ProtoErr, MyQuery, 'server_timestamp', FavUTCNow);

    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'address', MyLog.address, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'application', MyLog.application, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'application_path', MyLog.application_path, 128);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'application_version', MyLog.application_version, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'os', MyLog.os, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'os_version', MyLog.os_version, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'thread', MyLog.thread);
    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'main_thread', FavToString(MyLog.main_thread));

    FavDBSetParam(_ProtoLog, _ProtoErr, MyQuery, 'msg_id_client', FavToString(MyLog.msg_id_client));

    FavDBExecQuery(_ProtoLog, _ProtoErr, MyQuery);
    FavDBCloseQuery(_ProtoLog, _ProtoErr, MyQuery);

    if MyIStartedTransaction then begin
      FavDbUtils.FavDBCommitTransaction(_ProtoLog, _ProtoErr, _Connection);
      MyIStartedTransaction := False;
    end;

  except
    on E: Exception do begin
      MyFinishTime := FavUTCNow;
      MyError := E.Message;
      FavDBCloseQuery(_ProtoLog, _ProtoErr, MyQuery);
      FavProtoDuration(_ProtoLog, MyFunctionName, MyStartTime, MyFinishTime);
      FavProtoError(_ProtoLog , _ProtoErr, '', MyFunctionName, E, MyError);
      if MyIStartedTransaction then begin
        FavDbUtils.FavDBRollbackTransaction(_ProtoLog, _ProtoErr, _Connection);
        MyIStartedTransaction := False;
      end;
      raise;
    end;
  end;

  MyFinishTime := FavUTCNow;
  FavProtoDuration(_ProtoLog, MyFunctionName, MyStartTime, MyFinishTime);
  FavProtoEnd(_ProtoLog, _ProtoErr, '', MyFunctionName);
end;

procedure TLogThreadSaver.SendShutDownMessage;
var MyString: String;
begin
  MyString := 'BSHUTDOWN=TRUE';
  _PQueue.PutData(MyString);

  // wait for thread to finish
  while _BFinished = False do begin
    Sleep(1)
  end;
end;


function LogEncode(var InLog: T0MQLogRecord): String;
var MyResult: String;
begin
  MyResult := Format('<%s ' +
                     'debug_level="%s" ' +
                     'severity="%s" ' +
                     'message_type="%s" ' +
                     'code="%s" ' +

                     'msg_in="%s" ' +
                     'msg_out="%s" ' +
                     'debug_info="%s" ' +

                     'duration="%s" ' +
                     'duration_prepare="%s" ' +
                     'msg_size="%s" ' +

                     'client_timestamp="%s" ' +
                     'server_timestamp="%s" ' +

                     'address="%s" ' +
                     'application="%s" ' +
                     'application_path="%s" ' +
                     'application_version="%s" ' +
                     'os="%s" ' +
                     'os_version="%s" ' +
                     'thread="%s" ' +
                     'main_thread="%s" ' +
                     'msg_id_client="%s" ' +
                     '/>',
                   [
                     'item',
                     FavForXML(InLog.debug_level),
                     FavForXML(InLog.severity),
                     FavForXML(InLog.message_type),
                     FavForXML(InLog.code),

                     FavForXML(InLog.msg_in),
                     FavForXML(InLog.msg_out),
                     FavForXML(InLog.debug_info),

                     FavForXML(InLog.duration),
                     FavForXML(InLog.duration_prepare),
                     FavForXML(InLog.msg_size),

                     FavForXMLDateTime(InLog.client_timestamp),
                     FavForXMLDateTime(InLog.server_timestamp),

                     FavForXML(InLog.address),
                     FavForXML(InLog.application),
                     FavForXML(InLog.application_path),
                     FavForXML(InLog.application_version),
                     FavForXML(InLog.os),
                     FavForXML(InLog.os_version),
                     FavForXML(InLog.thread),
                     FavForXML(InLog.main_thread),
                     FavForXML(InLog.msg_id_client)
                     ]);
  Result := FAV_SYS_XML_HEADER + FAV_SYS_NEWLINE +
            FAV_SYS_XML_DATA_OPEN + FAV_SYS_NEWLINE +
            MyResult + FAV_SYS_NEWLINE +
            FAV_SYS_XML_DATA_CLOSE;
end;

procedure LogDecode(InString: String; var OutLog: T0MQLogRecord);
var MyDoc: TXMLDocument;
    MySrc: TXMLInputSource;
    MyParser: TDOMParser;
    MyChildData: TDOMNode;
    MyChildItem: TDOMNode;
    MyNodeName: TFavString;
    MyNodeValue: TFavString;
    F, G, H: Integer;
begin
  // I receive xml in format
  (*
  <xml>
  <data>
     <item address="192.168.0.1" ......./>
  </data>
  </xml>
  *)

  OutLog := InitT0MQLogRecord;

  MyDoc := nil;
  MySrc := nil;
  MyParser := nil;

  try
    if InString <> '' then begin
      try
        MyParser := TDOMParser.Create;
        MyParser.Options.Validate := True;
        MySrc := TXMLInputSource.Create(InString);
    //    MyParser.Options.PreserveWhitespace := True;
        try
          MyParser.Parse(MySrc, MyDoc);
        except
          on E: Exception do begin
            if (InString <> '') and (InString[1] <> '<') then begin
              raise Exception.Create(Copy(InString, 1, 255));
            end;
          end;
        end;

        if (MyDoc.DocumentElement.NodeType = ELEMENT_NODE) and (MyDoc.DocumentElement.NodeName = 'xml') then begin
          for F := 0 to MyDoc.DocumentElement.ChildNodes.Count-1 do begin
            MyChildData := MyDoc.DocumentElement.ChildNodes[F];
            if (MyChildData.NodeType = ELEMENT_NODE) and (MyChildData.NodeName = 'data') then begin
              for G := 0 to MyChildData.ChildNodes.Count-1 do begin
                MyChildItem := MyChildData.ChildNodes[G];
                if (MyChildItem.NodeType = ELEMENT_NODE) and (MyChildItem.NodeName = 'item') then begin

                  for H := 0 to MyChildItem.Attributes.Length-1 do begin
                    MyNodeName := FavCorrectXMLValue(MyChildItem.Attributes[H].NodeName);
                    MyNodeValue := FavCorrectXMLValue(MyChildItem.Attributes[H].NodeValue);
                    if MyNodeName = 'address' then begin
                      OutLog.address := MyNodeValue;
                    end
                    else if MyNodeName = 'debug_level' then OutLog.debug_level := MyNodeValue
                    else if MyNodeName = 'severity' then OutLog.severity := FavToInteger(MyNodeValue)
                    else if MyNodeName = 'message_type' then OutLog.message_type := (MyNodeValue)
                    else if MyNodeName = 'code' then OutLog.code := FavToInteger(MyNodeValue)

                    else if MyNodeName = 'msg_in' then OutLog.msg_in := MyNodeValue
                    else if MyNodeName = 'msg_out' then OutLog.msg_out := MyNodeValue
                    else if MyNodeName = 'debug_info' then OutLog.debug_info := MyNodeValue

                    else if MyNodeName = 'client_timestamp' then OutLog.client_timestamp := FavToDateTime(MyNodeValue)
                    else if MyNodeName = 'server_timestamp' then OutLog.server_timestamp := FavToDateTime(MyNodeValue)

                    else if MyNodeName = 'duration' then OutLog.duration := FavToInteger(MyNodeValue)
                    else if MyNodeName = 'duration_prepare' then OutLog.duration_prepare := FavToInteger(MyNodeValue)
                    else if MyNodeName = 'msg_size' then OutLog.msg_size := FavToInteger(MyNodeValue)

                    else if MyNodeName = 'application' then OutLog.application := MyNodeValue
                    else if MyNodeName = 'application_path' then OutLog.application_path := MyNodeValue
                    else if MyNodeName = 'application_version' then OutLog.application_version := MyNodeValue
                    else if MyNodeName = 'os' then OutLog.os := MyNodeValue
                    else if MyNodeName = 'os_version' then OutLog.os_version := MyNodeValue
                    else if MyNodeName = 'thread' then OutLog.thread := FavToInteger(MyNodeValue)
                    else if MyNodeName = 'main_thread' then OutLog.main_thread := FavToBoolean(MyNodeValue)
                    else if MyNodeName = 'msg_id_client' then OutLog.msg_id_client := FavToInteger(MyNodeValue)
                  end;
                end;
              end;
            end;
          end;
        end;

        if MySrc <> nil then FreeAndNil(MySrc);
        if MyParser <> nil then FreeAndNil(MyParser);
        if MyDoc <> nil then MyDoc.Free;
      except
        on E: Exception do begin
          if MySrc <> nil then FavFreeAndNil(MySrc);
          if MyParser <> nil then FavFreeAndNil(MyParser);
          if MyDoc <> nil then FavFreeAndNil(MyDoc);
        end;
      end;
    end;
  except
  end;
end;

procedure LogToFile(InFileName: TFavString; var InLog: T0MQLogRecord);
begin
  FavAppendToFile(InFileName, FAV_SYS_ASTERIX_LINE + FAV_SYS_NEWLINE + LogEncode(InLog) + FAV_SYS_NEWLINE);
end;

procedure LogToProto(InProto: TFavProto; var InLog: T0MQLogRecord);
begin
  FavFullProtoLn(InProto, dlDebug, FAV_SYS_NEWLINE + LogEncode(InLog));
end;

procedure LogToDB(InConnection: TFavConnection; InQuery: TFavQuery;
  var InLog: T0MQLogRecord);
var MyFunctionName: TFavString;
    MyStartTime, MyFinishTime: TFavDateTime;
    MyError: TFavString;
    MyIStartedTransaction: TFavBoolean;
    _ProtoLog, _ProtoErr: TFavProto;
begin
  _ProtoLog := nil;
  _ProtoErr := nil;
  MyFunctionName := 'LogToDB';
  FavProtoStart(_ProtoLog, _ProtoErr, '', MyFunctionName);
  MyStartTime := FavUTCNow;
  MyIStartedTransaction := False;


  try
    MyIStartedTransaction := FavDbUtils.FavDBStartTransaction(_ProtoLog, _ProtoErr, InConnection);

    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'debug_level', InLog.debug_level, 16);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'severity', InLog.severity);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'message_type', InLog.message_type, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'code', InLog.code);

    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'msg_in', InLog.msg_in);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'msg_out', InLog.msg_out);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'debug_info', InLog.debug_info);

    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'duration', InLog.duration);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'duration_prepare', InLog.duration_prepare);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'msg_size', InLog.msg_size);

    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'address', InLog.address, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'application', InLog.application, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'application_path', InLog.application_path, 128);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'application_version', InLog.application_version, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'os', InLog.os, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'os_version', InLog.os_version, 32);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'thread', InLog.thread);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'main_thread', FavToString(InLog.main_thread), 1);
    FavDBSetParam(_ProtoLog, _ProtoErr, InQuery, 'msg_id_client', InLog.msg_id_client);

    FavDBSetParamDateTime(_ProtoLog, _ProtoErr, InQuery, 'client_timestamp', InLog.client_timestamp);
    FavDBSetParamDateTime(_ProtoLog, _ProtoErr, InQuery, 'server_timestamp', FavUTCNow);

    FavDBExecQuery(_ProtoLog, _ProtoErr, InQuery);
    FavDBCloseQuery(_ProtoLog, _ProtoErr, InQuery);

    if MyIStartedTransaction then begin
      FavDbUtils.FavDBCommitTransaction(_ProtoLog, _ProtoErr, InConnection);
      MyIStartedTransaction := False;
    end;

  except
    on E: Exception do begin
      MyFinishTime := FavUTCNow;
      MyError := E.Message;
      FavDBCloseQuery(_ProtoLog, _ProtoErr, InQuery);
      FavProtoDuration(_ProtoLog, MyFunctionName, MyStartTime, MyFinishTime);
      FavProtoError(_ProtoLog , _ProtoErr, '', MyFunctionName, E, MyError);

      if MyIStartedTransaction then begin
        FavDbUtils.FavDBRollbackTransaction(_ProtoLog, _ProtoErr, InConnection);
        MyIStartedTransaction := False;
      end;
      raise;
    end;
  end;

  MyFinishTime := FavUTCNow;
  FavProtoDuration(_ProtoLog, MyFunctionName, MyStartTime, MyFinishTime);
  FavProtoEnd(_ProtoLog, _ProtoErr, '', MyFunctionName);
end;

procedure LogPrepareQuery(InConnection: TFavConnection; OutQuery: TFavQuery);
begin
  OutQuery.SQLConnection := InConnection;
  OutQuery.Name := 'LogDB';

  if InConnection is TPQConnection then begin
    OutQuery.SQL.Text :=
      'insert into log_log (' + FAV_SYS_NEWLINE +
      '    id, ' + FAV_SYS_NEWLINE +

      '    debug_level, ' + FAV_SYS_NEWLINE +
      '    severity, ' + FAV_SYS_NEWLINE +
      '    message_type, ' + FAV_SYS_NEWLINE +
      '    code, ' + FAV_SYS_NEWLINE +

      '    msg_in, ' + FAV_SYS_NEWLINE +
      '    msg_out, ' + FAV_SYS_NEWLINE +
      '    debug_info, ' + FAV_SYS_NEWLINE +

      '    client_timestamp, ' + FAV_SYS_NEWLINE +
      '    server_timestamp, ' + FAV_SYS_NEWLINE +

      '    duration, ' + FAV_SYS_NEWLINE +
      '    duration_prepare, ' + FAV_SYS_NEWLINE +
      '    msg_size, ' + FAV_SYS_NEWLINE +

      '    address, ' + FAV_SYS_NEWLINE +
      '    application, ' + FAV_SYS_NEWLINE +
      '    application_path, ' + FAV_SYS_NEWLINE +
      '    application_version, ' + FAV_SYS_NEWLINE +
      '    os, ' + FAV_SYS_NEWLINE +
      '    os_version, ' + FAV_SYS_NEWLINE +
      '    thread, ' + FAV_SYS_NEWLINE +
      '    main_thread, ' + FAV_SYS_NEWLINE +
      '    msg_id_client) ' + FAV_SYS_NEWLINE +
      'values (' + FAV_SYS_NEWLINE +
      '    (select nextval(''"SEQ_LOG_LOG"'')), ' + FAV_SYS_NEWLINE +

      '    :debug_level, ' + FAV_SYS_NEWLINE +
      '    :severity, ' + FAV_SYS_NEWLINE +
      '    :message_type, ' + FAV_SYS_NEWLINE +
      '    :code, ' + FAV_SYS_NEWLINE +

      '    :msg_in, ' + FAV_SYS_NEWLINE +
      '    :msg_out, ' + FAV_SYS_NEWLINE +
      '    :debug_info, ' + FAV_SYS_NEWLINE +

      '    :client_timestamp, ' + FAV_SYS_NEWLINE +
      '    :server_timestamp, ' + FAV_SYS_NEWLINE +

      '    :duration, ' + FAV_SYS_NEWLINE +
      '    :duration_prepare, ' + FAV_SYS_NEWLINE +
      '    :msg_size, ' + FAV_SYS_NEWLINE +

      '    :address, ' + FAV_SYS_NEWLINE +
      '    :application, ' + FAV_SYS_NEWLINE +
      '    :application_path, ' + FAV_SYS_NEWLINE +
      '    :application_version, ' + FAV_SYS_NEWLINE +
      '    :os, ' + FAV_SYS_NEWLINE +
      '    :os_version, ' + FAV_SYS_NEWLINE +
      '    :thread, ' + FAV_SYS_NEWLINE +
      '    :main_thread, ' + FAV_SYS_NEWLINE +
      '    :msg_id_client) ';
  end
  else if (InConnection is TMySQL40Connection) or
          (InConnection is TMySQL41Connection) or
          (InConnection is TMySQL50Connection) or
          (InConnection is TMySQL50Connection) or
          (InConnection is TMySQL55Connection)
  then begin
    OutQuery.SQL.Text :=
      'insert into log_log (' + FAV_SYS_NEWLINE +
      '    debug_level, ' + FAV_SYS_NEWLINE +
      '    severity, ' + FAV_SYS_NEWLINE +
      '    message_type, ' + FAV_SYS_NEWLINE +
      '    code, ' + FAV_SYS_NEWLINE +

      '    msg_in, ' + FAV_SYS_NEWLINE +
      '    msg_out, ' + FAV_SYS_NEWLINE +
      '    debug_info, ' + FAV_SYS_NEWLINE +

      '    client_timestamp, ' + FAV_SYS_NEWLINE +
      '    server_timestamp, ' + FAV_SYS_NEWLINE +

      '    duration, ' + FAV_SYS_NEWLINE +
      '    duration_prepare, ' + FAV_SYS_NEWLINE +
      '    msg_size, ' + FAV_SYS_NEWLINE +

      '    address, ' + FAV_SYS_NEWLINE +
      '    application, ' + FAV_SYS_NEWLINE +
      '    application_path, ' + FAV_SYS_NEWLINE +
      '    application_version, ' + FAV_SYS_NEWLINE +
      '    os, ' + FAV_SYS_NEWLINE +
      '    os_version, ' + FAV_SYS_NEWLINE +
      '    thread, ' + FAV_SYS_NEWLINE +
      '    main_thread, ' + FAV_SYS_NEWLINE +
      '    msg_id_client) ' + FAV_SYS_NEWLINE +
      'values (' + FAV_SYS_NEWLINE +
      '    :debug_level, ' + FAV_SYS_NEWLINE +
      '    :severity, ' + FAV_SYS_NEWLINE +
      '    :message_type, ' + FAV_SYS_NEWLINE +
      '    :code, ' + FAV_SYS_NEWLINE +

      '    :msg_in, ' + FAV_SYS_NEWLINE +
      '    :msg_out, ' + FAV_SYS_NEWLINE +
      '    :debug_info, ' + FAV_SYS_NEWLINE +

      '    :client_timestamp, ' + FAV_SYS_NEWLINE +
      '    :server_timestamp, ' + FAV_SYS_NEWLINE +

      '    :duration, ' + FAV_SYS_NEWLINE +
      '    :duration_prepare, ' + FAV_SYS_NEWLINE +
      '    :msg_size, ' + FAV_SYS_NEWLINE +

      '    :address, ' + FAV_SYS_NEWLINE +
      '    :application, ' + FAV_SYS_NEWLINE +
      '    :application_path, ' + FAV_SYS_NEWLINE +
      '    :application_version, ' + FAV_SYS_NEWLINE +
      '    :os, ' + FAV_SYS_NEWLINE +
      '    :os_version, ' + FAV_SYS_NEWLINE +
      '    :thread, ' + FAV_SYS_NEWLINE +
      '    :main_thread, ' + FAV_SYS_NEWLINE +
      '    :msg_id_client) ';
  end
  else if (InConnection is TSQLite3Connection) then begin
    OutQuery.SQL.Text :=
      'insert into log_log (' + FAV_SYS_NEWLINE +
      '    debug_level, ' + FAV_SYS_NEWLINE +
      '    severity, ' + FAV_SYS_NEWLINE +
      '    message_type, ' + FAV_SYS_NEWLINE +
      '    code, ' + FAV_SYS_NEWLINE +

      '    msg_in, ' + FAV_SYS_NEWLINE +
      '    msg_out, ' + FAV_SYS_NEWLINE +
      '    debug_info, ' + FAV_SYS_NEWLINE +

      '    client_timestamp, ' + FAV_SYS_NEWLINE +
      '    server_timestamp, ' + FAV_SYS_NEWLINE +

      '    duration, ' + FAV_SYS_NEWLINE +
      '    duration_prepare, ' + FAV_SYS_NEWLINE +
      '    msg_size, ' + FAV_SYS_NEWLINE +

      '    address, ' + FAV_SYS_NEWLINE +
      '    application, ' + FAV_SYS_NEWLINE +
      '    application_path, ' + FAV_SYS_NEWLINE +
      '    application_version, ' + FAV_SYS_NEWLINE +
      '    os, ' + FAV_SYS_NEWLINE +
      '    os_version, ' + FAV_SYS_NEWLINE +
      '    thread, ' + FAV_SYS_NEWLINE +
      '    main_thread, ' + FAV_SYS_NEWLINE +
      '    msg_id_client) ' + FAV_SYS_NEWLINE +
      'values (' + FAV_SYS_NEWLINE +
      '    :debug_level, ' + FAV_SYS_NEWLINE +
      '    :severity, ' + FAV_SYS_NEWLINE +
      '    :message_type, ' + FAV_SYS_NEWLINE +
      '    :code, ' + FAV_SYS_NEWLINE +

      '    :msg_in, ' + FAV_SYS_NEWLINE +
      '    :msg_out, ' + FAV_SYS_NEWLINE +
      '    :debug_info, ' + FAV_SYS_NEWLINE +

      '    :client_timestamp, ' + FAV_SYS_NEWLINE +
      '    :server_timestamp, ' + FAV_SYS_NEWLINE +

      '    :duration, ' + FAV_SYS_NEWLINE +
      '    :duration_prepare, ' + FAV_SYS_NEWLINE +
      '    :msg_size, ' + FAV_SYS_NEWLINE +

      '    :address, ' + FAV_SYS_NEWLINE +
      '    :application, ' + FAV_SYS_NEWLINE +
      '    :application_path, ' + FAV_SYS_NEWLINE +
      '    :application_version, ' + FAV_SYS_NEWLINE +
      '    :os, ' + FAV_SYS_NEWLINE +
      '    :os_version, ' + FAV_SYS_NEWLINE +
      '    :thread, ' + FAV_SYS_NEWLINE +
      '    :main_thread, ' + FAV_SYS_NEWLINE +
      '    :msg_id_client) ';
  end
  else begin
    raise Exception.Create('Not supported DB type. Only Postgres, MYSQL or SQLLite is supported');
  end;
end;

procedure LogCreateTable(InConnection: TFavConnection);
var MyFunctionName: TFavString;
    MyStartTime, MyFinishTime: TFavDateTime;
    MyQuery: TFavQuery;
    MyError: TFavString;
    MyIStartedTransaction: TFavBoolean;
    _ProtoLog, _ProtoErr: TFavProto;
begin
  _ProtoLog := nil;
  _ProtoErr := nil;
  MyQuery := nil;
  MyFunctionName := 'LogCreateTable';
  FavProtoStart(_ProtoLog, _ProtoErr, '', MyFunctionName);
  MyStartTime := FavUTCNow;
  MyIStartedTransaction := False;


  try
    MyQuery := TFavQuery.Create(nil);
    MyQuery.SQLConnection := InConnection;
    MyQuery.Name := 'LogDB';

    if (InConnection is TSQLite3Connection) then begin
      MyQuery.SQL.Text :=
      'CREATE TABLE log_log (' + FAV_SYS_NEWLINE +
      '	     id INTEGER PRIMARY KEY   AUTOINCREMENT,' + FAV_SYS_NEWLINE +
      '      msg_in TEXT, ' + FAV_SYS_NEWLINE +
      '      msg_out TEXT, ' + FAV_SYS_NEWLINE +
      '      debug_info TEXT, ' + FAV_SYS_NEWLINE +

      '      debug_level VARCHAR(16), ' + FAV_SYS_NEWLINE +
      '      severity BIGINT, ' + FAV_SYS_NEWLINE +
      '      message_type VARCHAR(32), ' + FAV_SYS_NEWLINE +
      '      code BIGINT, ' + FAV_SYS_NEWLINE +

      '      duration BIGINT, ' + FAV_SYS_NEWLINE +
      '      duration_prepare BIGINT, ' + FAV_SYS_NEWLINE +
      '      msg_size BIGINT, ' + FAV_SYS_NEWLINE +

      '      client_timestamp TIMESTAMP, ' + FAV_SYS_NEWLINE +
      '      server_timestamp TIMESTAMP, ' + FAV_SYS_NEWLINE +

      '      address VARCHAR(32), ' + FAV_SYS_NEWLINE +
      '      application VARCHAR(32), ' + FAV_SYS_NEWLINE +
      '      application_path VARCHAR(128), ' + FAV_SYS_NEWLINE +
      '      application_version VARCHAR(32), ' + FAV_SYS_NEWLINE +
      '      os VARCHAR(32), ' + FAV_SYS_NEWLINE +
      '      os_version VARCHAR(32), ' + FAV_SYS_NEWLINE +
      '      thread BIGINT, ' + FAV_SYS_NEWLINE +
      '      main_thread VARCHAR(1), ' + FAV_SYS_NEWLINE +
      '      msg_id_client BIGINT ' + FAV_SYS_NEWLINE +
      ');';
    end
    else begin
      raise Exception.Create('Not supported DB type. Only Postgres, MYSQL or SQLLite is supported');
    end;

    MyIStartedTransaction := FavDbUtils.FavDBStartTransaction(_ProtoLog, _ProtoErr, InConnection);

    FavDBExecQuery(_ProtoLog, _ProtoErr, MyQuery);
    FavDBCloseQuery(_ProtoLog, _ProtoErr, MyQuery);

    if MyIStartedTransaction then begin
      FavDbUtils.FavDBCommitTransaction(_ProtoLog, _ProtoErr, InConnection);
      MyIStartedTransaction := False;
    end;

    if MyQuery <> nil then begin
      FavFreeAndNil(MyQuery);
    end;

  except
    on E: Exception do begin
      MyFinishTime := FavUTCNow;
      MyError := E.Message;
      FavDBCloseQuery(_ProtoLog, _ProtoErr, MyQuery);
      FavProtoDuration(_ProtoLog, MyFunctionName, MyStartTime, MyFinishTime);
      FavProtoError(_ProtoLog , _ProtoErr, '', MyFunctionName, E, MyError);
      if MyQuery <> nil then begin
        FavFreeAndNil(MyQuery);
      end;

      if MyIStartedTransaction then begin
        FavDbUtils.FavDBRollbackTransaction(_ProtoLog, _ProtoErr, InConnection);
        MyIStartedTransaction := False;
      end;
      raise;
    end;
  end;

  MyFinishTime := FavUTCNow;
  FavProtoDuration(_ProtoLog, MyFunctionName, MyStartTime, MyFinishTime);
  FavProtoEnd(_ProtoLog, _ProtoErr, '', MyFunctionName);
end;

function LogCreateDBConnection(InConnectionParams: TFavRecConnection): TFavConnection;
var MyConnection: TFavConnection;
begin
  MyConnection := FavDBCreateConnection('MyDBConnection', InConnectionParams);
  if InConnectionParams.db_type = 'SQLITE' then begin
    if Pos(':memory:', InConnectionParams.db_name) > 0 then begin
      LogCreateTable(MyConnection);
    end;
  end;
  FavDBCheckConnection(MyConnection);
  Result := MyConnection;
end;

procedure LogCreateMessage(var OutLog: T0MQLogRecord;
                           InDebugLevel: TFavString;
                           InSeverity: TFavInteger;
                           InMessageType: TFavString;
                           InAddress: TFavString;
                           InApplicationVersion: TFavString;
                           InErrorCode: TFavInteger;
                           InMsgIn: TFavString;
                           InMsgOut: TFavString;
                           InDebugInfo: TFavString;
                           InDuration: TFavInteger;
                           InDurationPrepare: TFavInteger;
                           InMsgSize: TFavInteger
                          );
begin
  OutLog := InitT0MQLogRecord;
  OutLog.debug_level := InDebugLevel;
  OutLog.severity := InSeverity;
  OutLog.message_type := InMessageType;
  OutLog.code := InErrorCode;

  OutLog.msg_in := InMsgIn;
  OutLog.msg_out := InMsgOut;
  OutLog.debug_info := InDebugInfo;

  OutLog.duration := InDuration;
  OutLog.duration_prepare := InDurationPrepare;
  OutLog.msg_size := InMsgSize;


  OutLog.client_timestamp := FavUTCNow;
  OutLog.server_timestamp := 0;

  //  OutLog.address := FavGetIPAddresses;
  OutLog.address := InAddress;
  OutLog.application := ExtractFileName(ParamStr(0));
  OutLog.application_path := ParamStr(0);
  OutLog.application_version := InApplicationVersion;
  OutLog.os := FavGetOSVersion;
  OutLog.os_version := OutLog.os;
  OutLog.thread := ThreadID;
  OutLog.main_thread := (ThreadID = MainThreadID);
  OutLog.msg_id_client := 0;
end;

function LogCreateMessageString(var OutLog: T0MQLogRecord;
                           InDebugLevel: TFavString;
                           InSeverity: TFavInteger;
                           InMessageType: TFavString;
                           InAddress: TFavString;
                           InApplicationVersion: TFavString;
                           InErrorCode: TFavInteger;
                           InMsgIn: TFavString;
                           InMsgOut: TFavString;
                           InDebugInfo: TFavString;
                           InDuration: TFavInteger;
                           InDurationPrepare: TFavInteger;
                           InMsgSize: TFavInteger
                           ): TFavString;
begin
  LogCreateMessage(OutLog,
                   InDebugLevel,
                   InSeverity,
                   InMessageType,
                   InAddress,
                   InApplicationVersion,
                   InErrorCode,
                   InMsgIn,
                   InMsgOut,
                   InDebugInfo,
                   InDuration,
                   InDurationPrepare,
                   InMsgSize
                   );
  Result := LogEncode(OutLog);
end;

procedure LogToQueue(InProto: TFavProto; InQueue: TFavQueue; InLogMessage: TFavString);
begin
  try
    // 100 is ensurance number since we have multiple threads that are
    // using Logging queue
    if (InQueue._list.Count < (InQueue._maxMsgNo - 100)) then begin
      if (InQueue <> nil) and (InLogMessage <> '') then begin
 //       MyLogMessage := '<lasdlasdl' + FAV_SYS_NEWLINE + InLogMessage;
        InQueue.PutData(InLogMessage);
      end;
    end
    else begin
      FavLProtoLn(InProto, dlEmerg, 'Log Queue is Full. Size is : ' + FavToString(InQueue._maxMsgNo))
    end;
  except
    on E: Exception do begin
      FavLProtoLn(InProto, dlEmerg, 'Log Queue Error: ' + E.Message)
    end;
  end;
end;



end.

