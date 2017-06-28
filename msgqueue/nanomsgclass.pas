unit NanoMsgClass;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  IniFiles,

  nano, ctypes;

type
  TNanoMsgSetup = record
    address: string;         // example is tcp://172.17.41.208:5558
    hwm: integer;            // high water mark
    send_timeout: integer;   // send timeout
    recv_timeout: integer;   // receiving timeout
    socket_type: string;     // PUB, SUB, PUSH, PULL ...
  end;


  { ENanoMsgError }
  // Error nadling
  // Methods that create objects return NULL if they fail.
  // Methods that process data may return the number of bytes processed, or -1 on an error or failure.
  // Other methods return 0 on success and -1 on an error or failure.
  // The error code is provided in errno or zmq_errno().
  // A descriptive error text for logging is provided by zmq_strerror().


  ENanoMsgError = class(Exception)
    public
      _ErrNo: Integer;
      _ErrMsg: String;
      constructor Create(InErrNo: Integer; InErrMsg: String);
      destructor Destroy; override;
  end;

  { TNanoMsgSocket }

  TNanoMsgSocket = class
    _Socket: Integer;
    _SocketType: cint;
    _BindString: String;
    _ConnectString: String;
    _RecvBuffer: array[0..(65536 * 100)-1] of char;
  public
    constructor Create(); overload;
    destructor Destroy; override;

    procedure CleanUp;
    function GetSocket(InSocketType: cint): Integer;
    function BindSocket(InBindString: String): cint;
    function ConnectSocket(InConnectString: String): cint;
    function CloseSocket: cint;

    function Send(InBuffer: Pointer; InLen: csize_t; InFlags: cint = 0): cint; overload;
    function Send(InString: String): cint;
    function Recv(InBuffer: Pointer; InBufferSize: cint; InFlags: cint = 0): cint; overload;
    function Recv(var OutString: String; InFlags: cint = 0; InHowMuchMilliseconds: cint = 0): cint; overload;

    function SetSockOptInteger(InOption: cint; InValue: Integer; InLevel: integer = NN_SOL_SOCKET): cint;
    function SetSockOptInt64(InOption: cint; InValue: Int64; InLevel: integer = NN_SOL_SOCKET): cint;
    function SetSockOptString(InOption: cint; InValue: string; InLevel: integer = NN_SOL_SOCKET): cint;

    function GetSockOptInteger(InOption: cint; InLevel: integer = NN_SOL_SOCKET): Integer;
    function GetSockOptInt64(InOption: cint; InLevel: integer = NN_SOL_SOCKET): Int64;
    function GetSockOptString(InOption: cint; InLevel: integer = NN_SOL_SOCKET): String;
  end;

var InitTNanoMsgSetup: TNanoMsgSetup = ({%H-});

function  GetNanoMsgError(InErrorCode: cint): String;
procedure RaiseNanoMsgError(InErrNo: Integer;
                        InErrMsg: String);
procedure NanoMsgReadConfiguration(InIniFile: TIniFile; InSection: String; var OutNanoMsgSetup: TNanoMsgSetup); overload;
procedure NanoMsgReadConfiguration(InIniFileName: String; InSection: String; var OutNanoMsgSetup: TNanoMsgSetup); overload;

implementation

function GetNanoMsgError(InErrorCode: cint): String;
var MyErrPChar: PChar;
    MyResult: String;
begin
  MyResult:= '';
  MyErrPChar := nn_strerror(InErrorCode);
  MyResult := String(MyErrPChar);
  Result := MyResult;
end;

procedure RaiseNanoMsgError(InErrNo: Integer; InErrMsg: String);
begin
  raise ENanoMsgError.Create(InErrNo, InErrMsg);
end;

{ ENanoMsgError }

constructor ENanoMsgError.Create(InErrNo: Integer; InErrMsg: String);
begin
  inherited Create(InErrMsg);
  _ErrNo := InErrNo;
  _ErrMsg := InErrMsg;
end;

destructor ENanoMsgError.Destroy;
begin
  inherited Destroy;
end;

{ TNanoMsgSocket }

constructor TNanoMsgSocket.Create();
begin
  CleanUp;
end;

destructor TNanoMsgSocket.Destroy;
begin
  try
    if _Socket >= 0 then begin
      CloseSocket;
    end;
  except
    // I dont care about error
  end;

  CleanUp;
  inherited Destroy;
end;

procedure TNanoMsgSocket.CleanUp;
begin
  _Socket := -1;
  _SocketType := 0;
  _BindString := '';
  _ConnectString := '';
end;

function TNanoMsgSocket.GetSocket(InSocketType: cint): Integer;
var MyResult: Integer;
    MyError: cint;
    MyErrorString: String;
begin
  MyResult := -1;
  _SocketType := InSocketType;
  MyResult := nn_socket (AF_SP, InSocketType);
  if MyResult < 0 then begin
    MyError := nn_errno;
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  _Socket := MyResult;
  Result := MyResult;
end;

function TNanoMsgSocket.BindSocket(InBindString: String): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  _BindString := InBindString;
  MyRC := nn_bind(_Socket, PChar(InBindString));
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function TNanoMsgSocket.ConnectSocket(InConnectString: String): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  _ConnectString := InConnectString;
  MyRC := nn_connect(_Socket, PChar(InConnectString));
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function TNanoMsgSocket.CloseSocket: cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := nn_close(_Socket);
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  CleanUp;
  Result := MyRC;
end;

function TNanoMsgSocket.Send(InBuffer: Pointer; InLen: csize_t; InFlags: cint): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := nn_send(_Socket, InBuffer, InLen, InFlags);
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function TNanoMsgSocket.Send(InString: String): cint;
begin
  Result := Send(Pchar(InString), Length(InString), 0);
end;

function TNanoMsgSocket.Recv(InBuffer: Pointer; InBufferSize: cint; InFlags: cint): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := nn_recv(_Socket, InBuffer, InBufferSize, InFlags);
  if ((MyRC = -1) and (InFlags = 0)) then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function TNanoMsgSocket.Recv(var OutString: String; InFlags: cint;
  InHowMuchMilliseconds: cint): cint;
var MyResult: cint;
begin
  FillChar(_RecvBuffer, SizeOf(_RecvBuffer), 0);
  if InFlags = NN_DONTWAIT then begin
    while InHowMuchMilliseconds > 0 do begin
      MyResult :=  Recv(@_RecvBuffer, SizeOf(_RecvBuffer), InFlags);
      if MyResult = -1 then begin
        if nn_errno = EAGAIN then begin
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

function TNanoMsgSocket.SetSockOptInteger(InOption: cint; InValue: Integer;
  InLevel: integer): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  // NN_SUB  - possible levels
  // NN_TCP
  // NN_SOL_SOCKET

  MyRC := nn_setsockopt(_Socket, InLevel, InOption, @InValue, sizeof(InValue));
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function TNanoMsgSocket.SetSockOptInt64(InOption: cint; InValue: Int64;
  InLevel: integer): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  MyRC := nn_setsockopt(_Socket, InLevel, InOption, @InValue, sizeof(InValue));
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function TNanoMsgSocket.SetSockOptString(InOption: cint; InValue: string; InLevel: integer): cint;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
begin
  // NN_SUB  - possible levels
  // NN_TCP

  if Length(InValue) > 0 then begin
    MyRC := nn_setsockopt(_Socket, InLevel, InOption, @InValue[1], Length(InValue));
  end
  else begin
    MyRC := nn_setsockopt(_Socket, InLevel, InOption, @InValue, 0);
  end;
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyRC;
end;

function TNanoMsgSocket.GetSockOptInteger(InOption: cint; InLevel: integer
  ): Integer;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
    MyValue: Integer;
    MySize: size_t;
begin
  MyValue := 0;
  MySize := SizeOf(MyValue);
  MyRC := nn_getsockopt(_Socket, InLevel, InOption, @MyValue, MySize);
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyValue;
end;

function TNanoMsgSocket.GetSockOptInt64(InOption: cint; InLevel: integer
  ): Int64;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
    MyValue: Int64;
    MySize: size_t;
begin
  MyValue := 0;
  MySize := SizeOf(MyValue);
  MyRC := nn_getsockopt(_Socket, InLevel, InOption, @MyValue, MySize);
  if MyRC = -1 then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := MyValue;
end;

function TNanoMsgSocket.GetSockOptString(InOption: cint; InLevel: integer
  ): String;
var MyRC: cint;
    MyError: cint;
    MyErrorString: String;
    MyValue: array[0..10*1024-1] of char;
    MySize: DWord;
begin
  MySize := SizeOf(MyValue);
  FillByte(MyValue, MySize, 0);
  MyRC := nn_getsockopt(_Socket, InLevel, InOption, @MyValue[0], MySize);
  if (MyRC = -1) then begin
    MyError := nn_errno();
    MyErrorString := GetNanoMsgError(MyError);
    RaiseNanoMsgError(MyError, MyErrorString);
  end;
  Result := String(MyValue);
end;

procedure NanoMsgReadConfiguration(InIniFile: TIniFile; InSection: String;
  var OutNanoMsgSetup: TNanoMsgSetup);
begin
  OutNanoMsgSetup := InitTNanoMsgSetup;
  OutNanoMsgSetup.address      := InIniFile.ReadString(InSection, 'address', '');
  OutNanoMsgSetup.hwm          := InIniFile.ReadInteger(InSection, 'hwm', 200);
  OutNanoMsgSetup.send_timeout := InIniFile.ReadInteger(InSection, 'send_timeout', 0);
  OutNanoMsgSetup.recv_timeout := InIniFile.ReadInteger(InSection, 'recv_timeout', 0);
  OutNanoMsgSetup.socket_type  := InIniFile.ReadString(InSection, 'socket_type', 'PULL');
end;

procedure NanoMsgReadConfiguration(InIniFileName: String; InSection: String;
  var OutNanoMsgSetup: TNanoMsgSetup);
var MyIniFile: TIniFile;
begin
  OutNanoMsgSetup := InitTNanoMsgSetup;
  MyIniFile := nil;
  try
    if FileExists(InIniFileName) then begin
      MyIniFile := TIniFile.Create(InIniFileName);
      NanoMsgReadConfiguration(MyIniFile, InSection, OutNanoMsgSetup);
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

