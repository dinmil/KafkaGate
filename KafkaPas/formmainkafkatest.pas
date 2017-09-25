unit FormMainKafkaTest;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Kafka, KafkaClass, IniFiles;

type

  { TfrmMainKafkaTest }

  TfrmMainKafkaTest = class(TForm)
    btnStart: TButton;
    btnStop: TButton;
    cbMaxMessageSize: TComboBox;
    cbSendPause: TComboBox;
    edConfSection: TEdit;
    edTopicSection: TEdit;
    edBroker: TEdit;
    edTopic: TEdit;
    lBrokerCaption: TLabel;
    lTopicCaption: TLabel;
    lConfCaption: TLabel;
    mResult: TMemo;
    mParams: TMemo;
    pLeftCaption: TPanel;
    pBottom: TPanel;
    pCenter: TPanel;
    pCenterCaption: TPanel;
    pTop: TPanel;
    pLeft: TPanel;
    rbConsumer: TRadioButton;
    rbProducer: TRadioButton;
    splLeftCenter: TSplitter;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure rbConsumerChange(Sender: TObject);
  private

  public
    _KafkaConsumer: TKafkaConsumer;
    _KafkaProducer: TKafkaProducer;

    _KafkaSetup   : TKafkaSetup;
    _MessageCount : Integer;

    procedure OnKafkaMessageReceived (InMessage: String; InKey: String; OutMsg: Prd_kafka_message_t);
    procedure OnKafkaMessageEOF(InMessage: String);
    procedure OnKafkaMessageErr(InError: String);
    procedure OnKafkaTick(InHow: String);

    procedure StartConsumer;
    procedure StartProducer;
  end;

var
  frmMainKafkaTest: TfrmMainKafkaTest;

implementation

{$R *.lfm}

{ TfrmMainKafkaTest }

procedure TfrmMainKafkaTest.btnStartClick(Sender: TObject);
begin
  if rbConsumer.Checked then begin
    StartConsumer;
  end
  else begin
    StartProducer;
  end;
end;

procedure TfrmMainKafkaTest.btnStopClick(Sender: TObject);
begin
  if _KafkaConsumer <> nil then begin
    _KafkaConsumer._BStop := True;
  end;
  if _KafkaProducer <> nil then begin
    _KafkaProducer._BStop := True;
  end;
end;

procedure TfrmMainKafkaTest.FormCreate(Sender: TObject);
begin
  mResult.Lines.Add('*************************************************************');
  mResult.Lines.Add('Testing library version...');
  mResult.Lines.add('Kafka.rd_kafka_version: ' + IntToStr(Kafka.rd_kafka_version));
  mResult.Lines.add('Kafka.rd_kafka_version_str: ' + String(Kafka.rd_kafka_version_str));
  mResult.Lines.add('Kafka.rd_kafka_get_debug_contexts: ' + String(Kafka.rd_kafka_get_debug_contexts));
  mResult.Lines.add('Kafka.rd_kafka_err2str(RD_KAFKA_RESP_ERR__QUEUE_FULL): ' + String(Kafka.rd_kafka_err2str(RD_KAFKA_RESP_ERR__QUEUE_FULL)));
  mResult.Lines.add('Kafka.rd_kafka_err2name(RD_KAFKA_RESP_ERR__QUEUE_FULL): ' + String(Kafka.rd_kafka_err2name(RD_KAFKA_RESP_ERR__QUEUE_FULL)));
  mResult.Lines.add('Kafka.rd_kafka_last_error: ' + IntToStr(Kafka.rd_kafka_last_error));
  mResult.Lines.add('Kafka.rd_kafka_errno2err: ' + IntToStr(Kafka.rd_kafka_errno2err(Kafka.rd_kafka_last_error)));
  mResult.Lines.Add('End of Testing library version...');
  mResult.Lines.Add('*************************************************************');

//   mResult.Lines.Add('Reading configuration');
  mParams.Lines.LoadFromFile('.\consumer.ini');
  rbConsumerChange(rbConsumer);
end;

procedure TfrmMainKafkaTest.rbConsumerChange(Sender: TObject);
begin
  if rbConsumer.Checked then begin
    pTop.Color := clMoneyGreen;
    mParams.Lines.LoadFromFile('.\consumer.ini');
    pLeftCaption.Caption := 'Params: .\consumer.ini';
  end
  else begin
    pTop.Color := clSkyBlue;
    mParams.Lines.LoadFromFile('.\producer.ini');
    pLeftCaption.Caption := 'Params: .\producer.ini';
  end;
end;

procedure TfrmMainKafkaTest.OnKafkaMessageReceived(InMessage: String;
  InKey: String; OutMsg: Prd_kafka_message_t);
begin
  Inc(_MessageCount);
  mResult.Clear;
  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + IntToStr(_MessageCount));
  mResult.Lines.Add(InMessage);
end;

procedure TfrmMainKafkaTest.OnKafkaMessageEOF(InMessage: String);
begin
  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' Received EOF');
end;

procedure TfrmMainKafkaTest.OnKafkaMessageErr(InError: String);
begin
  mResult.Clear;
  mResult.Lines.Add('ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR ERR');
  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + IntToStr(_MessageCount));
  mResult.Lines.Add(InError);
end;

procedure TfrmMainKafkaTest.OnKafkaTick(InHow: String);
begin
  if InHow <> 'WAITFORMESSAGES-POLL' then begin
    mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + InHow);
  end;
  Application.ProcessMessages;
end;

procedure TfrmMainKafkaTest.StartConsumer;
var MyFileName: String;
begin
  _MessageCount := 0;
  MyFileName := '.\consumer.ini';

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'ReadVariables from ' + MyFileName);
  Application.ProcessMessages;

  // Save variables from mParams
  if Trim(mParams.Text) <> '' then begin
    mParams.Lines.SaveToFile(MyFileName);
  end;

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Create consumer');
  Application.ProcessMessages;

  // Create consumer
  _KafkaConsumer := TKafkaConsumer.Create(False);

  // call function which will read configuration
  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Read Configuration');
  Application.ProcessMessages;
  KafkaReadConfiguration(MyFileName, 'config', _KafkaSetup);

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Show Variables');
  Application.ProcessMessages;
  edBroker.Text       := _KafkaSetup.broker;
  edTopic.Text        := _KafkaSetup.topic;
  edConfSection.Text  := _KafkaSetup.conf_section;
  edTopicSection.Text := _KafkaSetup.topic_section;

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Start Consumer');
  Application.ProcessMessages;
  _KafkaConsumer.StartConsumer(_KafkaSetup,
                               @OnKafkaMessageReceived,
                               @OnKafkaMessageEOF,
                               @OnKafkaMessageErr,
                               @OnKafkaTick,
                               cbMaxMessageSize.ItemIndex * 1 * 1024);

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Free Consumer');
  Application.ProcessMessages;
  if _KafkaConsumer <> nil then FreeAndNil(_KafkaConsumer);
end;

procedure TfrmMainKafkaTest.StartProducer;
var MyFileName: String;
  My_dr_msg_cb: TProc_dr_msg_cb;
  MyKey, MyMessage: String;
  F: Integer;
begin
  _MessageCount := 0;
  MyFileName := '.\producer.ini';

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'ReadVariables from ' + MyFileName);
  Application.ProcessMessages;

  // Save variables from mParams
  if Trim(mParams.Text) <> '' then begin
    mParams.Lines.SaveToFile(MyFileName);
  end;

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Create procucer');
  Application.ProcessMessages;

  // Create producer
  _KafkaProducer := TKafkaProducer.Create(False);

  // call function which will read configuration
  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Read Configuration');
  Application.ProcessMessages;
  KafkaReadConfiguration(MyFileName, 'config', _KafkaSetup);

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Show Variables');
  Application.ProcessMessages;
  edBroker.Text       := _KafkaSetup.broker;
  edTopic.Text        := _KafkaSetup.topic;
  edConfSection.Text  := _KafkaSetup.conf_section;
  edTopicSection.Text := _KafkaSetup.topic_section;

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Start Consumer');
  _KafkaProducer.StartProducer(_KafkaSetup,
                               My_dr_msg_cb);

  F := 0;
  while true do begin
    if _KafkaProducer._BStop then Break;
    Inc(F);
    MyKey := IntToStr(F mod 100);
    MyMessage := '<xml no="' + IntToStr(F) + '">' + FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + '</xml>';
    _KafkaProducer.ProduceMessage(MyKey, MyMessage);
    mResult.Lines.Add(MyMessage);
    if ((F mod 1000) = 0) then mResult.Clear;
    Application.ProcessMessages;
    if cbSendPause.ItemIndex = 0 then begin
      Sleep(10);
    end
    else begin
      Sleep(cbSendPause.ItemIndex * 100);
    end;
  end;

  mResult.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz: ', Now) + ' ' + 'Free Producer');
  Application.ProcessMessages;
  if _KafkaProducer <> nil then FreeAndNil(_KafkaProducer);
end;

end.

