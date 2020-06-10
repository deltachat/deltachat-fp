unit Unit1;

{
    Lazarus Delta Chat Client
    Copyright © 2020  Delta Chat developers

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Menus, Buttons, hDeltachat, CTypes;

type

  { TForm1 }

  TForm1 = class(TForm)
    ButtonSend: TButton;
    EditMessage: TEdit;
    ListViewChat: TListView;
    ListViewChatlist: TListView;
    MainMenu1: TMainMenu;
    MenuItemInfo: TMenuItem;
    MenuItemHelp: TMenuItem;
    MenuItemFile: TMenuItem;
    OpenDialog1: TOpenDialog;
    PanelChat: TPanel;
    Splitter1: TSplitter;
    procedure ButtonSendClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ListViewChatlistSelectItem(Sender: TObject; Item: TListItem;
      Selected: boolean);
    procedure MenuItemInfoClick(Sender: TObject);
  private
    procedure ReloadChat;
    procedure ReloadChatlist;
  public

  end;

  TMyThread = class(TThread)
  private
    FEventEmitter: PDcEventEmitter;
  public
    constructor Create(CreateSuspended: boolean; context: PDcContext);
    procedure ReloadChatList;
  protected
    procedure Execute; override;
  end;

  TDeltaChatContext = class
  public
    FDcContext: PDcContext;
    constructor Create(osname: PChar; dbfile: PChar; blobdir: PChar);
    destructor Destroy; override;
  end;

  TDeltaChatChat = class
  public
    ChatId: cuint32;
  end;

var
  Form1: TForm1;
  context: TDeltaChatContext;
  eventthread: TMyThread;

implementation

{$R *.lfm}

constructor TDeltaChatContext.Create(osname: PChar; dbfile: PChar; blobdir: PChar);
begin
  FDcContext := dc_context_new(osname, dbfile, blobdir);
end;

destructor TDeltaChatContext.Destroy;
begin
  dc_context_unref(FDcContext);
end;

{ TForm1 }

procedure TForm1.ReloadChatlist;
var
  Chatlist: PDcChatlist;
  ChatlistIndex: csize_t;
  ChatlistSummary: PDcLot;
  Text1: PChar;
  Text2: PChar;
  Chat: PDcChat;
  ChatName: PChar;
  DeltaChatChat: TDeltaChatChat;
  ChatId: cuint32;
  Item: TListItem;
  PreviousSelectedChatId: cuint32;
begin
  if ListViewChatlist.Selected <> nil then
    PreviousSelectedChatId := TDeltaChatChat(ListViewChatlist.Selected.Data).ChatId
  else
    PreviousSelectedChatId := 0;

  for item in ListViewChatlist.Items do
  begin
    TDeltaChatChat(item.Data).Free;
  end;
  ListViewChatlist.Clear();

  ChatList := dc_get_chatlist(context.FDcContext, 0, nil, 0);
  for ChatListIndex := 1 to dc_chatlist_get_cnt(chatlist) do
  begin
    chatlistSummary := dc_chatlist_get_summary(chatlist, chatlistIndex - 1, nil);
    Text1 := dc_lot_get_text1(chatlistSummary);
    Text2 := dc_lot_get_text2(chatlistSummary);
    Chat := dc_get_chat(context.FDcContext, dc_chatlist_get_chat_id(
      chatlist, chatlistIndex - 1));
    ChatName := dc_chat_get_name(chat);

    ChatId := dc_chatlist_get_chat_id(chatlist, chatlistIndex - 1);

    DeltaChatChat := TDeltaChatChat.Create;
    DeltaChatChat.chatId := chatId;

    Item := ListViewChatlist.Items.Add;
    Item.Caption := chatName + #13 + text1 + ' ' + text2;
    Item.Data := deltaChatChat;
    if PreviousSelectedChatId = ChatId then
      Item.Selected := true;


    dc_str_unref(chatName);
    dc_chat_unref(chat);
    dc_str_unref(text1);
    dc_str_unref(text2);
    dc_lot_unref(chatlistSummary);
  end;
  dc_chatlist_unref(chatlist);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  if OpenDialog1.Execute then
    if FileExists(OpenDialog1.FileName) then
    begin
      Context := TDeltaChatContext.Create(nil, PChar(OpenDialog1.FileName),
        PChar(OpenDialog1.FileName + '-blobs'));

      ReloadChatlist;
      EventThread := TMyThread.Create(False, context.FDcContext);
      dc_start_io(context.FDcContext);
    end;

  if Context = nil then
    Application.Terminate;
end;

procedure TForm1.ButtonSendClick(Sender: TObject);
var
  Chat: TDeltaChatChat;
  Msg: PDcMsg;
begin
  if ListViewChatlist.Selected <> nil then
  begin
    Chat := TDeltaChatChat(ListViewChatlist.Selected.Data);
    Msg := dc_msg_new(context.FDcContext, DC_MSG_TEXT);
    dc_msg_set_text(Msg, PChar(EditMessage.Text));
    dc_prepare_msg(context.FDcContext, Chat.ChatId, Msg);
    dc_send_msg(context.FDcContext, Chat.ChatId, Msg);
    dc_msg_unref(Msg);

    EditMessage.Clear;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
  Item: TListItem;
begin
  if Context = nil then
    Exit;
  dc_stop_io(context.FDcContext);

  { Tell event thread to stop processing events }
  EventThread.Terminate;

  Context.Free;
  EventThread.WaitFor;

  EventThread.Free;
  for Item in ListViewChatlist.Items do
  begin
    TDeltaChatChat(item.Data).Free;
  end;
end;

procedure TForm1.ReloadChat();
var
  Chat: TDeltaChatChat;
  Messages: PDcArray;
  MessageIndex: csize_t;
  Msg: PDcMsg;
  MsgId: cuint32;
  MsgText: PChar;
  FromId: cuint32;
  FromContact: PDcContact;
  FromDisplayName: PChar;
begin
  if ListViewChatList.Selected <> nil then
  begin
    ListViewChat.Clear();

    Chat := TDeltaChatChat(ListViewChatList.Selected.Data);
    Messages := dc_get_chat_msgs(context.FDcContext, chat.ChatId, 0, 0);
    for messageIndex := 1 to dc_array_get_cnt(Messages) do
    begin
      MsgId := dc_array_get_id(Messages, messageIndex - 1);
      Msg := dc_get_msg(context.FDcContext, msgid);
      MsgText := dc_msg_get_text(msg);
      FromId := dc_msg_get_from_id(msg);
      FromContact := dc_get_contact(context.FDcContext, FromId);
      FromDisplayName := dc_contact_get_display_name(FromContact);
      ListViewChat.AddItem(FromDisplayName + ': ' + msgText, nil);

      { Scroll to the newely added item }
      ListViewChat.Items.Item[ListViewChat.Items.Count - 1].MakeVisible(False);

      dc_str_unref(FromDisplayName);
      dc_contact_unref(FromContact);
      dc_str_unref(MsgText);
      dc_msg_unref(Msg);
    end;
    dc_array_unref(Messages);

  end;
end;

procedure TForm1.ListViewChatlistSelectItem(Sender: TObject; Item: TListItem;
  Selected: boolean);
begin
  ReloadChat;
end;

procedure TForm1.MenuItemInfoClick(Sender: TObject);
var
  Info: PChar;
begin
  Info := dc_get_info(context.FDcContext);
  ShowMessage(info);
  dc_str_unref(info);
end;

constructor TMyThread.Create(CreateSuspended: boolean; context: PDcContext);
begin
  inherited Create(createSuspended);
  FEventEmitter := dc_get_event_emitter(context);
end;

procedure TMyThread.ReloadChatList;
begin
  Form1.ReloadChatlist;
end;

procedure TMyThread.Execute;
var
  Event: PDcEvent;
  Text: PChar;
begin
  while True do
  begin
    Event := dc_get_next_event(FEventEmitter);
    if event = nil then
    begin
      WriteLn('Terminating thread');
      break;
    end;

    if Self.Terminated then
      continue;


    case dc_event_get_id(event) of
      DC_EVENT_INFO:
      begin
        Text := dc_event_get_data2_str(event);
        writeln('INFO ' + Text);
        dc_str_unref(Text);
      end;
      DC_EVENT_SMTP_CONNECTED:
      begin
        Text := dc_event_get_data2_str(event);
        writeln('SMTP connected: ' + Text);
        dc_str_unref(Text);
      end;
      DC_EVENT_IMAP_CONNECTED:
      begin
        Text := dc_event_get_data2_str(event);
        writeln('IMAP connected: ' + Text);
        dc_str_unref(Text);
      end;
      DC_EVENT_WARNING:
      begin
        Text := dc_event_get_data2_str(event);
        writeln('WARNING: ' + Text);
      end;
      DC_EVENT_ERROR:
      begin
        Text := dc_event_get_data2_str(event);
        writeln('ERROR: ' + Text);
        { TODO : Show a popup }
      end;
      DC_EVENT_MSGS_CHANGED: Synchronize(@ReloadChatlist);
    end;
    dc_event_unref(event);
  end;
  dc_event_emitter_unref(FEventEmitter);
end;

end.
