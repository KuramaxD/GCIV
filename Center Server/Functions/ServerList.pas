unit ServerList;

interface

uses Windows, DBCon;

type
  TServerInfo = record
    ID: Integer;
    Name: AnsiString;
    IP: AnsiString;
    Port: Integer;
    Mensagem: AnsiString;
    Online: Integer;
    MaxOnline: Integer;
  end;

type
  TServerList = class
    Servers: array of TServerInfo;
    MySQL: TQuery;
    procedure Update;
    procedure Compile(PPlayer: Pointer);
    constructor Create(MySQL: TQuery);
    destructor Destroy; override;
  end;

implementation

uses GlobalDefs, Player;

constructor TServerList.Create(MySQL: TQuery);
begin
  Self.MySQL:=MySQL;
  SetLength(Servers,0);
  Update;
end;

destructor TServerList.Destroy;
begin
  inherited;
end;

procedure TServerList.Update;
var
  Len, i: Integer;
  Find: Boolean;
begin
  MySQL.SetQuery('SELECT * FROM Servers');
  MySQL.Run(1);
  while MySQL.Query.Eof = False do begin
    Find:=False;
    for i:=0 to Length(Servers)-1 do
      if Servers[i].ID = MySQL.Query.Fields[0].AsInteger then
        with MySQL.Query do begin
          Servers[i].ID:=Fields[0].AsInteger;
          Servers[i].Name:=Fields[1].AsAnsiString;
          Servers[i].IP:=Fields[2].AsAnsiString;
          Servers[i].Port:=Fields[3].AsInteger;
          Servers[i].Online:=Fields[4].AsInteger;
          Servers[i].MaxOnline:=Fields[5].AsInteger;
          Servers[i].Mensagem:=Fields[6].AsAnsiString;
          Find:=True;
          Break;
        end;
    if Find = False then begin
      Len:=Length(Servers);
      SetLength(Servers,Len+1);
      with MySQL.Query do begin
        Servers[Len].ID:=Fields[0].AsInteger;
        Servers[Len].Name:=Fields[1].AsAnsiString;
        Servers[Len].IP:=Fields[2].AsAnsiString;
        Servers[Len].Port:=Fields[3].AsInteger;
        Servers[Len].Online:=Fields[4].AsInteger;
        Servers[Len].MaxOnline:=Fields[5].AsInteger;
        Servers[Len].Mensagem:=Fields[6].AsAnsiString;
      end;
    end;
    MySQL.Query.Next;
  end;
end;

procedure TServerList.Compile(PPlayer: Pointer);
var
  Player: TPlayer;
  i: Integer;
begin
  Player:=TPlayer(PPlayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_SERVERLIST));
    Write(#$00#$00#$01#$4A#$00);
    WriteCd(Dword(Length(Servers)));
    for i:=0 to Length(Servers)-1 do begin
      WriteCd(Dword(i+1));
      WriteCd(Dword(i+1));
      WriteCd(Dword(Length(Servers[i].Name)*2));
      WriteZd(Servers[i].Name);
      WriteCd(Dword(Length(Servers[i].IP)));
      Write(Servers[i].IP);
      WriteCw(Word(Servers[i].Port));
      WriteCd(Dword(Servers[i].Online));
      WriteCd(Dword(Servers[i].MaxOnline));
      Write(#$00#$00#$01#$43#$FF#$FF#$FF#$FF#$FF#$FF+
            #$FF#$FF);
      WriteCd(Dword(Length(Servers[i].IP)));
      Write(Servers[i].IP);
      WriteCd(Dword(Length(Servers[i].Mensagem)*2));
      WriteZd(Servers[i].Mensagem);
      Write(#$00#$00#$00#$00);
    end;
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

end.
