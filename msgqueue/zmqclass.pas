unit ZMQClass;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  IniFiles,

  zmq, ctypes;

type
  T0MQSetup = record
    address: string;         // example is tcp://172.17.41.208:5558
    hwm: integer;            // high water mark
    send_timeout: integer;   // send timeout
    recv_timeout: integer;   // receiving timeout
    socket_type: string;     // PUB, SUB, PUSH, PULL ...
  end;


  { E0MQError }
  // Error nadling
  // Methods that create objects return NULL if they fail.
  // Methods that process data may return the number of bytes processed, or -1 on an error or failure.
  // Other methods return 0 on success and -1 on an error or failure.
  // The error code is provided in errno or zmq_errno().
  // A descriptive error text for logging is provided by zmq_strerror().


  E0MQError = class(Exception)
    public
      _ErrNo: Integer;
      _ErrMsg: String;
      constructor Create(InErrNo: Integer; InErrMsg: String);
      destructor Destroy; override;
  end;

  { T0MQContext }

  T0MQContext = class
    _Context: Pointer;
  public
    constructor Create;
    destructor Destroy; override;
    function GetContext: Pointer;
  end;

  { T0MQSocket }

  T0MQSocket = class
    _Context: Pointer;
    _Socket: Pointer;
    _SocketType: cint;
    _BindString: String;
    _ConnectString: String;
    _RecvBuffer: array[0..(65536 * 100)-1] of char;
  public
    constructor Create(InContext: Pointer); overload;
    constructor Create(InContext: T0MQContext); overload;
    destructor Destroy; override;

    procedure CleanUp;
    function GetSocket(InSocketType: cint): Pointer;
    function BindSocket(InBindString: String): cint;
    function ConnectSocket(InConnectString: String): cint;
    function CloseSocket: cint;

    function Send(InBuffer: Pointer; InLen: csize_t; InFlags: cint = 0): cint; overload;
    function Send(var InString: String): cint;
    function Recv(InBuffer: Pointer; InBufferSize: cint; InFlags: cint = 0): cint; overload;
    function Recv(var OutString: String; InFlags: cint = 0; InHowMuchMilliseconds: cint = 0): cint; overload;

    function SetSockOptInteger(InOption: cint; InValue: Integer): cint;
    function SetSockOptInt64(InOption: cint; InValue: Int64): cint;

    function GetSockOptInteger(InOption: cint): Integer;
    function GetSockOptInt64(InOption: cint): Int64;
  end;

var InitT0MQSetup: T0MQSetup = ({%H-});

function  Get0MQError(InErrorCode: cint): String;
procedure Raise0MQError(InErrNo: Integer;
                        InErrMsg: String);
procedure ZeroMQReadConfiguration(InIniFile: TIniFile; InSection: String; var Out0MQSetup: T0MQSetup); overload;
procedure ZeroMQReadConfiguration(InIniFileName: String; InSection: String; var Out0MQSetup: T0MQSetup); overload;
function  ZeroMQDumpSetup(var In0MQSetup: T0MQSetup): String;

implementation

function Get0MQError(InErrorCode: cint): String;
var MyErrPChar: PChar;
    MyResult: String;
begin
  MyResult:= '';
  MyErrPChar := zmq_strerror(InErrorCode);
  MyResult := String(MyErrPChar);
  Result := MyResult;
end;

procedure Raise0MQError(InErrNo: Integer; InErrMsg: String);
begin
  raise E0MQError.Create(InErrNo, InErrMsg);
end;

{ T0MQContext }

constructor T0MQContext.Create;
var MyError: cint;
    MyErrorString: String;
begin
  _Context := nil;
  _Context := zmq.zmq_ctx_new();
  if _Context = nil then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
end;

destructor T0MQContext.Destroy;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := zmq_ctx_destroy (_Context);
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;

  inherited Destroy;
end;

function T0MQContext.GetContext: Pointer;
begin
  Result := _Context;
end;

{ E0MQError }

constructor E0MQError.Create(InErrNo: Integer; InErrMsg: String);
begin
  inherited Create(InErrMsg);
  _ErrNo := InErrNo;
  _ErrMsg := InErrMsg;
end;

destructor E0MQError.Destroy;
begin
  inherited Destroy;
end;

{ T0MQSocket }

constructor T0MQSocket.Create(InContext: Pointer);
begin
  CleanUp;
  _Context := InContext;
end;

constructor T0MQSocket.Create(InContext: T0MQContext);
begin
  _Context := InContext.GetContext;
end;

destructor T0MQSocket.Destroy;
begin
  try
    if _Socket <> nil then begin
      CloseSocket;
    end;
  except
    // I dont care about error
  end;

  CleanUp;
  inherited Destroy;
end;

procedure T0MQSocket.CleanUp;
begin
  _Context := nil;
  _Socket := nil;
  _SocketType := 0;
  _BindString := '';
  _ConnectString := '';
end;

function T0MQSocket.GetSocket(InSocketType: cint): Pointer;
var MyResult: Pointer;
    MyError: cint;
    MyErrorString: String;
begin
  MyResult := nil;
  _SocketType := InSocketType;
  MyResult := zmq_socket (_Context, InSocketType);
  if MyResult = nil then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  _Socket := MyResult;
  Result := MyResult;
end;

function T0MQSocket.BindSocket(InBindString: String): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  _BindString := InBindString;
  MyRC := zmq_bind(_Socket, PChar(InBindString));
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function T0MQSocket.ConnectSocket(InConnectString: String): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  _ConnectString := InConnectString;
  MyRC := zmq_connect(_Socket, PChar(InConnectString));
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function T0MQSocket.CloseSocket: cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := zmq_close(_Socket);
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  CleanUp;
  Result := MyRC;
end;

function T0MQSocket.Send(InBuffer: Pointer; InLen: csize_t; InFlags: cint): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := zmq_send(_Socket, InBuffer, InLen, InFlags);
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function T0MQSocket.Send(var InString: String): cint;
begin
  Result := Send(Pchar(InString), Length(InString), 0);
end;

function T0MQSocket.Recv(InBuffer: Pointer; InBufferSize: cint; InFlags: cint): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := zmq_recv(_Socket, InBuffer, InBufferSize, InFlags);
  if ((MyRC = -1) and (InFlags = 0)) then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function T0MQSocket.Recv(var OutString: String; InFlags: cint;
  InHowMuchMilliseconds: cint): cint;
var MyResult: cint;
begin
  FillChar(_RecvBuffer, SizeOf(_RecvBuffer), 0);
  if InFlags = ZMQ_DONTWAIT then begin
    while InHowMuchMilliseconds > 0 do begin
      MyResult :=  Recv(@_RecvBuffer, SizeOf(_RecvBuffer), InFlags);
      if MyResult = -1 then begin
        if zmq_errno = ZMQ_EAGAIN then begin
          InHowMuchMilliseconds := InHowMuchMilliseconds - 100;
          Sleep(100);
        end
        else begin
          break;
        end;
      end
      else begin
        Break;
      end;
    end;
  end
  else begin
    MyResult := Recv(@_RecvBuffer, SizeOf(_RecvBuffer), InFlags);
  end;
  OutString := _RecvBuffer;
  Result := MyResult;
end;

function T0MQSocket.SetSockOptInteger(InOption: cint; InValue: Integer): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := zmq_setsockopt(_Socket, InOption, @InValue, sizeof(InValue));
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function T0MQSocket.SetSockOptInt64(InOption: cint; InValue: Int64): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := zmq_setsockopt(_Socket, InOption, @InValue, sizeof(InValue));
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function T0MQSocket.GetSockOptInteger(InOption: cint): Integer;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
    MyValue: Integer;
    MySize: size_t;
begin
  MyValue := 0;
  MySize := SizeOf(MyValue);
  MyRC := zmq_getsockopt(_Socket, InOption, @MyValue, @MySize);
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyValue;
end;

function T0MQSocket.GetSockOptInt64(InOption: cint): Int64;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
    MyValue: Int64;
    MySize: size_t;
begin
  MyValue := 0;
  MySize := SizeOf(MyValue);
  MyRC := zmq_getsockopt(_Socket, InOption, @MyValue, @MySize);
  if MyRC = -1 then begin
    MyError := zmq_errno();
    MyErrorString := Get0MQError(MyError);
    Raise0MQError(MyError, MyErrorString);
  end;
  Result := MyValue;
end;

procedure ZeroMQReadConfiguration(InIniFile: TIniFile; InSection: String;
  var Out0MQSetup: T0MQSetup);
begin
  Out0MQSetup := InitT0MQSetup;
  Out0MQSetup.address      := InIniFile.ReadString(InSection, 'address', '');
  Out0MQSetup.hwm          := InIniFile.ReadInteger(InSection, 'hwm', 200);
  Out0MQSetup.send_timeout := InIniFile.ReadInteger(InSection, 'send_timeout', 0);
  Out0MQSetup.recv_timeout := InIniFile.ReadInteger(InSection, 'recv_timeout', 0);
  Out0MQSetup.socket_type  := InIniFile.ReadString(InSection, 'socket_type', 'PULL');
end;

procedure ZeroMQReadConfiguration(InIniFileName: String; InSection: String;
  var Out0MQSetup: T0MQSetup);
var MyIniFile: TIniFile;
begin
  Out0MQSetup := InitT0MQSetup;
  MyIniFile := nil;
  try
    if FileExists(InIniFileName) then begin
      MyIniFile := TIniFile.Create(InIniFileName);
      ZeroMQReadConfiguration(MyIniFile, InSection, Out0MQSetup);
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

function ZeroMQDumpSetup(var In0MQSetup: T0MQSetup): String;
begin
  Result := Format('address=%s' + #13#10 +
                   'hwm=%d' + #13#10 +
                   'recv_timeout=%d' + #13#10 +
                   'end_timeout=%d' + #13#10 +
                   'socket_type=%s',
                   [
                   In0MQSetup.address,
                   In0MQSetup.hwm,
                   In0MQSetup.recv_timeout,
                   In0MQSetup.send_timeout,
                   In0MQSetup.socket_type
                   ]);
end;


end.

