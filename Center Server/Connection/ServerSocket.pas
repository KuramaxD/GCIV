unit ServerSocket;

interface

uses System.Win.ScktComp, System.Generics.Collections, Player, Misc, System.SysUtils,
     Loading, ServerList, Windows, Unknown, DBCon, Shop;

type
  TServer = class
  private
    Players: TList<TPlayer>;
    Shop: TShop;
    Unknown: TUnknown;
    Servers: TServerList;
    Loading: TLoading;
    MySQL: TQuery;
    procedure OnConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
  public
    Socket: TServerSocket;
    constructor Create(Port: Integer);
    destructor Destroy; override;
end;

implementation

uses GlobalDefs, Log;

procedure TServer.OnConnect(Sender: TObject; Socket: TCustomWinSocket);
var
  Player: TPlayer;
begin
  MainCS.Acquire;
  try
    Player:=TPlayer.Create(Socket,Shop,Unknown,Servers,MySQL,Loading);
    Logger.Write(Format('Player Conectou [Handle: %d, IV1: %s, IV2: %s]',[Socket.Handle,Space(StringToHex(Player.Buffer.IV)),Space(StringToHex(Player.Buffer.IV2))]),ServerStatus);
    Players.Add(Player);
  finally
    MainCS.Release;
  end;
end;

procedure TServer.OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
var
  Player: TPlayer;
begin
  MainCS.Acquire;
  try
    for Player in Players do
      if Player.Socket = Socket then begin
        if Player.ID > 0 then begin
          MySQL.SetQuery('UPDATE Users SET ONLINECS = 0 WHERE ID = :ID');
          MySQL.AddParameter('ID',AnsiString(IntToStr(Player.ID)));
          MySQL.Run(2);
        end;
        Logger.Write(Format('Player saiu [Handle: %d]',[Socket.Handle]),ServerStatus);
        Players.Remove(Player);
        Player.Free;
      end;
  finally
    MainCS.Release;
  end;
end;

procedure TServer.OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
var
  Player: TPlayer;
begin
  MainCS.Acquire;
  try
    ErrorCode:=0;
    for Player in Players do
      if Player.Socket = Socket then begin
        if Player.ID > 0 then begin
          MySQL.SetQuery('UPDATE Users SET ONLINECS = 0 WHERE ID = :ID');
          MySQL.AddParameter('ID',AnsiString(IntToStr(Player.ID)));
          MySQL.Run(2);
        end;
        Logger.Write(Format('Player saiu [Handle: %d]',[Socket.Handle]),ServerStatus);
        Players.Remove(Player);
        Player.Free;
      end;
  finally
    MainCS.Release;
  end;
end;

procedure TServer.OnRead(Sender: TObject; Socket: TCustomWinSocket);
var
  Player: TPlayer;
  Size, PacketID: Integer;
begin
  MainCS.Acquire;
  try
    for Player in Players do
      if Player.Socket = Socket then begin
        Player.Buffer.BTotal:=Player.Buffer.BTotal+Socket.ReceiveText;
        while True do begin
          try
            Size:=0;
            if Length(Player.Buffer.BTotal) >= 2 then
              Move(Player.Buffer.BTotal[1],Size,2);
            if Size = 0 then
              Break;
            if Size <= Length(Player.Buffer.BTotal) then begin
              Player.Buffer.BOut:=Copy(Player.Buffer.BTotal,1,Size);
              Delete(Player.Buffer.BTotal,1,Size);
              Player.Buffer.Decrypt(Player.Buffer.GenerateIV(1));
              PacketID:=Player.Buffer.RCw(1);
              case TCLPID(PacketID) of
                CLPID_KEEPALIVE: ;
                CLPID_HACKLIST_REQUEST: Loading.CompileList(Player);
                CLPID_PLAYER_LOGIN: Player.LoadLogin;
                CLPID_CHECKLIST_REQUEST: Loading.CompileCheck(Player);
                CLPID_SELECTEDCHAR_REQUEST: Player.SendSelectedChar;
                CLPID_UNKNOWN_19: Unknown.SendUnknown1A(Player);
              else
                Logger.Write(String(Player.Buffer.BOut),Log.Packets);
              end;
            end
            else
              Break;
          except
            Break;
          end;
        end;
      end;
  finally
    MainCS.Release;
  end;
end;

constructor TServer.Create(Port: Integer);
begin
  Loading:=TLoading.Create;
  Loading.Loading[1]:='Load1_1.dds';
  Loading.Loading[2]:='Load1_2.dds';
  Loading.Loading[3]:='Load1_3.dds';
  Loading.Loading[4]:='LoadGauge.dds';
  Loading.MatchLoading[1]:='ui_match_load1.dds';
  Loading.MatchLoading[2]:='ui_match_load2.dds';
  Loading.MatchLoading[3]:='ui_match_load3.dds';
  Loading.SquareLoading[1]:='Square.lua';
  Loading.SquareLoading[2]:='SquareObject.lua';
  Loading.SquareLoading[3]:='Square3DObject.lua';
  Loading.AddHack('Teste.dll');
  Loading.AddCheck('mainxx.exe','A42B77BEEECE321B19257C7EE803548B9DFD7A42');
  Loading.AddCheck('script.kom','A2BB33C398C1B4EE6F9C07FF73D4E0B3B87809BC');
  Loading.GuildMark:='http://gcreborn.com/GuildMark/';
  Unknown:=TUnknown.Create;
  Players:=TList<TPlayer>.Create;
  Logger.Write('Conectando na dabatase',ServerStatus);
  MySQL:=TQuery.Create('127.0.0.1',3306,'root','root','gc');
  if MySQL.MySQL.Connected = True then begin
    Logger.Write('Conectado',Warnings);
    Shop:=TShop.Create(MySQL);
    Servers:=TServerList.Create(MySQL);
    Self.Socket:=TServerSocket.Create(nil);
    Self.Socket.OnClientConnect:=Self.OnConnect;
    Self.Socket.OnClientRead:=Self.OnRead;
    Self.Socket.OnClientDisconnect:=Self.OnDisconnect;
    Self.Socket.OnClientError:=Self.OnError;
    Self.Socket.Port:=Port;
    Self.Socket.ServerType:=stNonBlocking;
    Self.Socket.Open;
  end;
end;

destructor TServer.Destroy;
begin
  inherited;
end;

end.
