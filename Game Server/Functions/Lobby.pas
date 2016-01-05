unit Lobby;

interface

uses Player, System.Generics.Collections, Windows, Log, System.SysUtils;

type
  TGameMode = (
    GM_TEAM = $0001,
    GM_SOLO = $0002
  );

  TItemMode = (
    GM_WITEMS = $0000,
    GM_NITEMS = $0001
  );

  TMatchMode = (
    MM_Match = $0000,
    MM_DEATHMATCH = $0008,
    MM_DOTA = $000B
  );

  TMaps = (
    ELVEN_FOREST          = $0000,
    MARSH_OF_OBLIVION     = $0001,
    AIRSHIP               = $0002,
    GORGE_OF_OATH         = $0003,
    FORGOTTEN_CITY        = $0004,
    CHRISTMAS_BABEL       = $0005,
    TEMPLE_OF_FIRE        = $0006,
    SHOOTING_RANGE        = $0007,
    HELL_BRIDGE           = $0008,
    ORC_TEMPLE            = $0009,
    OUTER_WALL_OF_SERDIN  = $000A,
    KERRIE_BEACH          = $000B,
    TRIAL_FOREST          = $002B,
    FORSAKEN_BARROWS      = $002F,
    KOUNATS_SECRET_ARENA  = $0063,
    UNDERWORLD            = $0064
  );

  TSlot = record
    Active: Boolean;
    Open: Boolean;
    Player: TPlayer;
    Count: Integer;
    LoadStatus: Integer;
  end;

type
  TRoom = record
    Active: Boolean;
    Name: AnsiString;
    Pass: AnsiString;
    GameMode: TGameMode;
    ItemMode: TItemMode;
    isRand: Boolean;
    Map: TMaps;
    MatchMode: TMatchMode;
    Players: array[0..5] of TSlot;
    NCount: Integer;
    TotalKicks: Integer;
    function GetLeader: TPlayer;
    function PlayersNumber: Integer;
    function PlayerSlot(Player: TPlayer): Integer;
    function FreeSlots: Integer;
    function Team(Player: TPlayer): Integer;
  end;

type
  TLobby = class
    Rooms: array of TRoom;
    procedure Chat(Player: TPlayer; Players: TList<TPlayer>);
    procedure CreateRoom(Player: TPlayer);
    procedure ExitRoom(Player: TPlayer);
    procedure SendRooms(Player: TPlayer);
    procedure EnterRoom(Player: TPlayer);
    procedure ChangeUserSettings(Player: TPlayer);
    procedure SendGameInformation(Player: TPlayer);
    procedure SendPlayersInGame(Player: TPlayer);
    procedure LoadSync(Player: TPlayer);
    procedure PlaySign(Player: TPlayer);
    procedure ChangeGameSettings(Player: TPlayer);
    procedure ChangeRoomSettings(Player: TPlayer);
    procedure KickUser(Player: TPlayer);
  end;

implementation

uses GlobalDefs;

function TRoom.GetLeader: TPlayer;
var
  i, i2: Integer;
begin
  Result:=TPlayer(-1);
  i2:=0;
  for i:=0 to High(Players) do
    if Players[i].Count > 0 then begin
      Result:=Players[i].Player;
      i2:=Players[i].Count;
      Break;
    end;
  for i:=Low(Players)+1 to High(Players) do
    if Players[i].Count > 0 then
      if Players[i].Count < i2 then begin
        Result:=Players[i].Player;
        i2:=Players[i].Count;
      end;
end;

function TRoom.PlayersNumber: Integer;
var
  i: Integer;
begin
  Result:=0;
  for i:=0 to Length(Players)-1 do
    if Players[i].Active then
      Inc(Result);
end;

function TRoom.PlayerSlot(Player: TPlayer): Integer;
var
  i: Integer;
begin
  Result:=0;
  for i:=0 to Length(Players)-1 do
    if (Players[i].Player = Player) and (Players[i].Active = True) then begin
      Result:=i;
      Break;
    end;
end;

function TRoom.FreeSlots: Integer;
var
  i: Integer;
begin
  Result:=0;
  for i:=0 to Length(Players)-1 do
    if Players[i].Open then
      Inc(Result);
end;

function TRoom.Team(Player: TPlayer): Integer;
var
  i: Integer;
begin
  Result:=0;
  for i:=0 to 2 do
    if (Players[i].Player = Player) and (Players[i].Active = True) then
      Exit;
  Result:=1;
  for i:=3 to 5 do
    if (Players[i].Player = Player) and (Players[i].Active = True) then
      Exit;
end;

procedure TLobby.Chat(Player: TPlayer; Players: TList<TPlayer>);
var
  Msg: AnsiString;
  Temp: TPlayer;
begin
  Msg:=Player.Buffer.RS(33+Player.Buffer.RB(16),Player.Buffer.RB(32+Player.Buffer.RB(16)));
  for Temp in Players do begin
    Temp.Buffer.BIn:='';
    with Temp.Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(SVPID_CHAT));
      Write(#$00#$00#$00#$3F#$00#$01);
      WriteCd(Dword(Player.AccInfo.ID));
      Write(#$00#$00#$00);
      Write(Byte(Length(Player.AccInfo.Nick)*2));
      WriteZd(Player.AccInfo.Nick);
      Write(#$00#$00#$00#$00#$00#$00#$00#$00#$FF#$FF+
            #$FF#$FF#$00#$00#$00);
      Write(Byte(Length(Msg)*2));
      WriteZd(Msg);
      Write(#$00#$00#$00#$00#$00#$00#$00#$00);
      FixSize;
      Encrypt(GenerateIV(0),Random($FF));
      ClearPacket();
    end;
    Temp.Send;
  end;
end;

procedure TLobby.CreateRoom(Player: TPlayer);
var
  i, i2, N: Integer;
  Nome, Senha: AnsiString;
  Active: Boolean;
begin
  if Player.AccInfo.Room = -1 then begin
    Player.Buffer.Decompress;

    //Aqui tbm recebe as info geral, char � bacana salvar

    Nome:=Player.Buffer.RS(18,Player.Buffer.RB(17));
    Senha:=Player.Buffer.RS(24+Player.Buffer.RB(17),Player.Buffer.RB(23+Player.Buffer.RB(17)));

    N:=0;
    Active:=False;
    for i:=0 to Length(Rooms)-1 do
      if Rooms[i].Active = False then begin
        Rooms[i].Name:=Nome;
        Rooms[i].Pass:=Senha;
        Rooms[i].Active:=True;
        Rooms[i].GameMode:=GM_TEAM;
        Rooms[i].ItemMode:=GM_NITEMS;
        Rooms[i].isRand:=False;
        Rooms[i].Map:=KOUNATS_SECRET_ARENA;
        Rooms[i].MatchMode:=MM_Match;
        Rooms[i].NCount:=0;
        Rooms[i].TotalKicks:=3;
        for i2:=0 to Length(Rooms[i].Players)-1 do begin
          Rooms[i].Players[i2].Active:=False;
          Rooms[i].Players[i2].Open:=True;
          Rooms[i].Players[i2].Count:=0;
          Rooms[i].Players[i2].LoadStatus:=0;
        end;
        Active:=True;
        N:=i;
        Break;
      end;
    if Active = False then begin
      SetLength(Rooms,Length(Rooms)+1);
      Rooms[Length(Rooms)-1].Name:=Nome;
      Rooms[Length(Rooms)-1].Pass:=Senha;
      Rooms[Length(Rooms)-1].Active:=True;
      Rooms[Length(Rooms)-1].GameMode:=GM_TEAM;
      Rooms[Length(Rooms)-1].ItemMode:=GM_NITEMS;
      Rooms[Length(Rooms)-1].isRand:=False;
      Rooms[Length(Rooms)-1].Map:=KOUNATS_SECRET_ARENA;
      Rooms[Length(Rooms)-1].MatchMode:=MM_Match;
      Rooms[Length(Rooms)-1].NCount:=0;
      Rooms[Length(Rooms)-1].TotalKicks:=3;
      for i2:=0 to Length(Rooms[Length(Rooms)-1].Players)-1 do begin
        Rooms[Length(Rooms)-1].Players[i2].Active:=False;
        Rooms[Length(Rooms)-1].Players[i2].Open:=True;
        Rooms[Length(Rooms)-1].Players[i2].Count:=0;
        Rooms[Length(Rooms)-1].Players[i2].LoadStatus:=0;
      end;
      N:=Length(Rooms)-1;
    end;

    //
    Rooms[N].Players[0].Active:=True;
    Rooms[N].Players[0].Player:=Player;
    Rooms[N].Players[0].Open:=False;
    Inc(Rooms[N].NCount);
    Rooms[N].Players[0].Count:=Rooms[N].NCount;
    //

    Player.AccInfo.Room:=N;

    Player.Buffer.BIn:='';
    with Player.Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(25));
      Write(#$00#$00#$00#$00#$00#$00#$00#$00);
      Write(Byte(Length(Player.AccInfo.Login)*2));
      WriteZd(Player.AccInfo.Login);
      WriteCd(Dword(Player.AccInfo.ID));
      Write(#$00#$00#$00);
      Write(Byte(Length(Player.AccInfo.Nick)*2));
      WriteZd(Player.AccInfo.Nick);
      WriteCd(Dword(Rooms[N].PlayerSlot(Player)));
      Write(Byte(Player.AccInfo.Char));
      Write(#$00#$FF#$00#$FF#$00#$FF#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$1F#$D1#$00#$00#$00#$00#$00#$4E#$00#$00+
            #$00#$07#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$08#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$09#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0A#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$0B#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0C#$00#$00#$00#$01#$01#$01#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$0D#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0E#$00#$00#$00#$01#$01#$01+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$0F#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$10#$00#$00#$00#$01+
            #$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$11#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$12#$00#$00+
            #$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$13#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$14+
            #$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$15#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00+
            #$00#$16#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$17#$00#$00#$00#$01#$07#$01#$00#$01#$00#$00#$00#$00+
            #$00#$00#$00#$18#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$19#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02+
            #$00#$00#$00#$00#$00#$1A#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$1B#$00#$00#$00#$01#$07#$01#$00#$01+
            #$00#$02#$00#$00#$00#$00#$00#$1D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1E#$00#$00#$00#$01#$07#$01#$00+
            #$01#$00#$02#$00#$00#$00#$00#$00#$24#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$27#$00#$00#$00#$01#$03+
            #$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$28#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$29#$00#$00#$00+
            #$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$2A#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$2B#$00+
            #$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$2C#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00+
            #$2D#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$2E#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00+
            #$00#$00#$2F#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$30#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00+
            #$00#$00#$00#$00#$31#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$32#$00#$00#$00#$01#$07#$01#$00#$01#$00+
            #$02#$00#$00#$00#$00#$00#$33#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$34#$00#$00#$00#$01#$07#$01#$00+
            #$01#$00#$02#$00#$00#$00#$00#$00#$35#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$36#$00#$00#$00#$01#$07+
            #$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$37#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$38#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$39#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3A#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3C#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3E#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$40#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$43#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$44#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$45#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$46#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$47#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$48#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$49#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4A#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4C#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4F#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$50#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$51#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$53#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$54#$00#$00#$00#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$55#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$56#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$57#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$58#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$59#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5B#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5D#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5F#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
      Write(Byte(Length(Player.Chars.Chars)));
      for i:=0 to Length(Player.Chars.Chars)-1 do begin
        Write(Byte(Player.Chars.Chars[i].CharID));
        Write(#$00#$00#$00#$00);
        Write(Byte(Player.Chars.Chars[i].Promotion));
        Write(#$00#$00#$00#$00#$00);
        WriteCd(Dword(Player.Chars.Chars[i].EXP));
        Write(#$00#$00#$00);
        Write(Byte(Player.Chars.Chars[i].Level));
        Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$FF#$FF#$00#$00#$00#$04#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$00#$02#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$8C#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$05#$01#$FF#$00#$00+
              #$00#$01#$00#$00#$04#$08#$01#$00#$00#$00#$00#$01#$00#$00#$04#$09#$01#$01#$00#$00#$00#$01#$00#$00#$04#$0B#$01#$02#$00#$00+
              #$00#$01#$00#$00#$04#$0D#$01#$03#$00#$00#$00#$01#$00#$00#$04#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$04#$E2#$00#$00#$04#$E2#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$07);
      end;
      Write(#$00#$00#$00#$04#$13#$00#$A8#$C0#$01#$EC#$A8#$C0#$9B#$BA#$FE#$A9);
      WriteCd(Dword(Player.Socket.RemoteAddr.sin_addr.S_addr));
      Write(#$00#$00#$00#$01#$7E#$F5#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$E5#$6A#$00#$00#$00#$01#$2C#$5B#$A7#$BD#$00#$00#$00#$00#$01#$00+
            #$00#$E5#$88#$00#$00#$00#$01#$2C#$5B#$A7#$BE#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$56#$86#$32#$00#$56#$87+
            #$6E#$37#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
            #$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$46#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00);
            WriteCd(Dword(N));
            WriteCd(Dword(Length(Nome)*2));
            WriteZd(Nome);
            Write(#$00#$00);
            WriteCd(Dword(Length(Senha)*2));
            WriteZd(Senha);
      WriteCw(Word(Rooms[N].PlayersNumber));
      WriteCw(Word(Rooms[N].FreeSlots+Rooms[N].PlayersNumber));
      Write(#$00#$0B);
      Write(Byte(Rooms[N].MatchMode));
      WriteCd(Dword(Rooms[N].GameMode));
      WriteCd(Dword(Rooms[N].ItemMode));
      Write(Rooms[N].isRand);
      WriteCd(Dword(Rooms[N].Map));
      Write(#$00#$00#$00#$0C);
      for i:=0 to Length(Rooms[N].Players)-1 do
        Write(Rooms[N].Players[i].Open);
      Write(#$FF#$FF#$FF#$FF#$00#$00#$00#$00#$00#$00#$00#$00#$01);
      WriteCd(Dword(UDP_RELAYIP));
      WriteCw(Word(UDP_RELAYPORT));
      WriteCd(Dword(TCP_RELAYIP));
      WriteCw(Word(TCP_RELAYPORT));
      Write(#$01#$00#$01#$00#$00+
            #$01#$2C#$00#$00#$00#$14#$00#$02#$4B#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$06#$01#$00#$00#$00+
            #$00);
      Compress;
      Encrypt(GenerateIV(0),Random($FF));
      ClearPacket();
    end;
    Player.Send;
  end
  else
    Logger.Write('Impossivel criar sala devido a ja estar em uma sala',Errors);
end;

procedure TLobby.ExitRoom(Player: TPlayer);
var
  i: Integer;
  Leader: Boolean;
begin
  if Player.AccInfo.Room > -1 then
    if Rooms[Player.AccInfo.Room].PlayersNumber = 1 then begin
      Rooms[Player.AccInfo.Room].Active:=False;
      Player.AccInfo.Room:=-1;
      Player.Buffer.BIn:='';
      with Player.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(SVPID_EXITROOM));
        Write(#$00#$00#$00#$04#$00#$00#$00#$00#$00);
        FixSize;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Player.Send;
    end
    else begin
      Leader:=False;
      if Rooms[Player.AccInfo.Room].GetLeader = Player then
        Leader:=True;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Player = Player then begin
          Rooms[Player.AccInfo.Room].Players[i].Active:=False;
          Rooms[Player.AccInfo.Room].Players[i].Count:=0;
          Rooms[Player.AccInfo.Room].Players[i].Open:=True;
          Rooms[Player.AccInfo.Room].Players[i].Player:=TPlayer(-1);
          Break;
        end;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_EXITSIGN));
            Write(#$00);
            WriteCd(Dword(Length(Player.AccInfo.Login)*2));
            WriteZd(Player.AccInfo.Login);
            Write(#$00#$00#$00#$00);
            WriteCd(Dword(Player.AccInfo.ID));
            WriteCd(Dword(3));
            Compress;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
          if Leader = True then begin
            Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
            with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
              Write(Prefix);
              Write(Dword(Count));
              WriteCw(Word(SVPID_CHANGELEADER));
              Write(#$00#$00#$00#$05#$00);
              WriteCd(Dword(Rooms[Player.AccInfo.Room].GetLeader.AccInfo.ID));
              Write(Byte(1));
              FixSize;
              Encrypt(GenerateIV(0),Random($FF));
              ClearPacket();
            end;
            Rooms[Player.AccInfo.Room].Players[i].Player.Send;
          end;
        end;
      if Leader = True then
        Rooms[Player.AccInfo.Room].TotalKicks:=3;
      Player.AccInfo.Room:=-1;
      Player.Buffer.BIn:='';
      with Player.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(SVPID_EXITROOM));
        Write(#$00#$00#$00#$04#$00#$00#$00#$00#$00);
        FixSize;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Player.Send;
    end;
end;

procedure TLobby.SendRooms(Player: TPlayer);
var
  i: Integer;
  Temp: AnsiString;
begin
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    Write(#$00);
    Write(Word(17));
    WriteCd(Dword(Length(Rooms)));
    for i:=0 to Length(Rooms)-1 do
      if Rooms[i].Active then begin
        WriteCw(Word(i));
        WriteCd(Dword(Length(Rooms[i].Name)*2));
        WriteZd(Rooms[i].Name);
        if Length(Rooms[i].Pass) > 0 then
          Write(#$00#$00)
        else
          Write(#$01#$00);
        WriteCd(Dword(Length(Rooms[i].Pass)*2));
        WriteZd(Rooms[i].Pass);
        WriteCw(Word(Rooms[i].FreeSlots+Rooms[i].PlayersNumber));
        WriteCw(Word(Rooms[i].PlayersNumber));
        Write(#$00#$2E#$02#$1B#$25#$01#$00#$00#$00#$00#$01#$6B#$F9#$38#$77#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$00#$00+
              #$01);
        WriteCd(Dword(Length(Rooms[i].GetLeader.AccInfo.Nick)*2));
        WriteZd(Rooms[i].GetLeader.AccInfo.Nick);
        Write(#$0B#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$01);
      end;
    Compress;
    Temp:=Copy(Player.Buffer.BIn,10,Length(Player.Buffer.BIn));
    Player.Buffer.BIn:=Copy(Player.Buffer.BIn,1,8);
    WriteCd(Dword(Length(Temp)+13));
    Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00);
    Write(Temp);
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TLobby.EnterRoom(Player: TPlayer);
var
  N, i, i2, NSerdin, NCanaban, NCount: Integer;
  Pass: AnsiString;
begin
  Player.Buffer.Decompress;
  N:=Player.Buffer.RCw(16);
  Pass:=Player.Buffer.RS(22,Player.Buffer.RB(21));
  //Se nao esta jogando e tals
  if (Rooms[N].Active = True) and (Rooms[N].FreeSlots > 0) then begin
    if Pass = Rooms[N].Pass then begin
      NSerdin:=0;
      for i:=0 to 2 do
        if (Rooms[N].Players[i].Active = False) and (Rooms[N].Players[i].Open = True) then
          Inc(NSerdin);
      NCanaban:=0;
      for i:=3 to 5 do
        if (Rooms[N].Players[i].Active = False) and (Rooms[N].Players[i].Open = True) then
          Inc(NCanaban);
      if NCanaban > NSerdin then begin
        for i:=3 to 5 do
          if (Rooms[N].Players[i].Active = False) and (Rooms[N].Players[i].Open = True) then begin
            Rooms[N].Players[i].Active:=True;
            Rooms[N].Players[i].Player:=Player;
            Rooms[N].Players[i].Open:=False;
            Inc(Rooms[N].NCount);
            Rooms[N].Players[i].Count:=Rooms[N].NCount;
            Break;
          end;
      end
      else begin
        for i:=0 to 2 do
          if (Rooms[N].Players[i].Active = False) and (Rooms[N].Players[i].Open = True) then begin
            Rooms[N].Players[i].Active:=True;
            Rooms[N].Players[i].Player:=Player;
            Rooms[N].Players[i].Open:=False;
            Inc(Rooms[N].NCount);
            Rooms[N].Players[i].Count:=Rooms[N].NCount;
            Break;
          end;
      end;
      Player.AccInfo.Room:=N;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if (Rooms[Player.AccInfo.Room].Players[i].Active) and (Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.ID <> Player.AccInfo.ID) then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(22));
            Write(#$00#$00#$00#$00);
            Write(Byte(Length(Player.AccInfo.Login)*2));
            WriteZd(Player.AccInfo.Login);
            WriteCd(Dword(Player.AccInfo.ID));
            Write(#$00#$00#$00);
            Write(Byte(Length(Player.AccInfo.Nick)*2));
            WriteZd(Player.AccInfo.Nick);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayerSlot(Player)));
            Write(Byte(Player.AccInfo.Char));
            Write(#$00#$FF#$00#$FF#$00#$FF#$00#$00#$00#$00#$01#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$10#$F4#$00#$00#$00#$00#$00#$4E#$00#$00+
                  #$00#$07#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$08#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$09#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$0D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$10#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$11#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$12#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$13#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$15#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$16#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$17#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$18#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$19#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$1B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$1E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$24#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$27#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$28#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$29#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$2B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$2D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$2F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$31#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$32#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$33#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$34#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$35#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$36#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$37#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$38#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$39#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$3B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$3D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$3F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$40#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$43#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$44#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$45#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$47#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$49#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$4B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$4E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$50#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$53#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$54#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$55#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$56#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$57#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$58#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$59#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$5A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$5C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$5E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
            Write(Byte(Length(Player.Chars.Chars)));
            for i2:=0 to Length(Player.Chars.Chars)-1 do begin
              Write(Byte(Player.Chars.Chars[i2].CharID));
              Write(#$00#$00#$00#$00);
              Write(Byte(Player.Chars.Chars[i2].Promotion));
              Write(#$00#$00#$00#$00#$00);
              WriteCd(Dword(Player.Chars.Chars[i2].EXP));
              Write(#$00#$00#$00);
              Write(Byte(Player.Chars.Chars[i2].Level));
              Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$FF#$FF#$00#$00#$00#$04#$00#$00#$00#$00#$00#$01#$00+
                    #$00#$00#$00#$02#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$8C#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$05#$01#$FF#$00#$00+
                    #$00#$01#$00#$00#$04#$08#$01#$00#$00#$00#$00#$01#$00#$00#$04#$09#$01#$01#$00#$00#$00#$01#$00#$00#$04#$0B#$01#$02#$00#$00+
                    #$00#$01#$00#$00#$04#$0D#$01#$03#$00#$00#$00#$01#$00#$00#$04#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$04#$E2#$00#$00#$04#$E2#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$07);
            end;
            Write(#$00#$00#$00#$04#$13#$00#$A8#$C0#$01#$EC#$A8#$C0#$9B#$BA#$FE#$A9);
            WriteCd(Dword(Player.Socket.RemoteAddr.sin_addr.S_addr));
            Write(#$00#$00#$00#$01#$7E#$F6#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$E5#$6A#$00#$00#$00#$01#$2C#$BD#$52#$5A#$00#$00#$00#$00#$01#$00+
                  #$00#$E5#$88#$00#$00#$00#$01#$2C#$BD#$52#$5B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$56#$86#$32#$00#$56#$87+
                  #$6E#$D4#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
                  #$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00);
            Compress;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
      Player.Buffer.BIn:='';
      with Player.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(1554));
        Write(#$00#$00#$00#$AB#$00);
        WriteCw(Word(N));
        WriteCd(Dword(Length(Rooms[N].Name)*2));
        WriteZd(Rooms[N].Name);
        if Length(Rooms[N].Pass) > 0 then
          Write(#$00#$01)
        else
          Write(#$00#$00);
        WriteCd(Dword(Length(Rooms[N].Pass)*2));
        WriteZd(Rooms[N].Pass);
        WriteCw(Word(Rooms[N].PlayersNumber));
        WriteCw(Word(Rooms[N].FreeSlots));
        Write(#$00#$0B);
        Write(Byte(Rooms[N].MatchMode));
        WriteCd(Dword(Rooms[N].GameMode));
        WriteCd(Dword(Rooms[N].ItemMode));
        Write(Rooms[N].isRand);
        WriteCd(Dword(Rooms[N].Map));
        Write(#$00#$00#$00#$0C);
        for i:=0 to Length(Rooms[N].Players)-1 do
          Write(Rooms[N].Players[i].Open);
        Write(#$FF#$FF#$FF#$FF#$00#$00#$00#$00#$00#$00#$00#$00#$01);
        WriteCd(Dword(UDP_RELAYIP));
        WriteCw(Word(UDP_RELAYPORT));
        WriteCd(Dword(TCP_RELAYIP));
        WriteCw(Word(TCP_RELAYPORT));
        Write(#$01#$00#$01#$00#$00+
              #$01#$2C#$00#$00#$00#$14#$00#$02#$4B#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$06#$01#$00#$00#$00+
              #$00);
        FixSize;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Player.Send;
      NCount:=0;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Player.Buffer.BIn:='';
          with Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(1468));
            Write(#$00#$00#$00#$00#$00);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
            WriteCd(Dword(NCount));
            Write(#$00#$00#$00);
            Write(Byte(Length(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Login)*2));
            WriteZd(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Login);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.ID));
            Write(#$00#$00#$00);
            Write(Byte(Length(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Nick)*2));
            WriteZd(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Nick);
            WriteCd(Dword(i));
            Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Char));
            Write(#$00#$FF#$00#$FF#$00#$FF#$00#$00#$00#$00#$01#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$10#$F4#$00#$00#$00#$00#$00#$4E#$00#$00+
                  #$00#$07#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$08#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$09#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$0D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$10#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$11#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$12#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$13#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$15#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$16#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$17#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$18#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$19#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$1B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$1E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$24#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$27#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$28#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$29#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$2B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$2D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$2F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$31#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$32#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$33#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$34#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$35#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$36#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$37#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$38#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$39#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$3B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$3D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$3F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$40#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$43#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$44#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$45#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$47#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$49#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$4B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$4E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$50#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$53#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$54#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$55#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$56#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$57#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$58#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$59#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$5A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$5C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$5E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
            Write(Byte(Length(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars)));
            for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars)-1 do begin
              Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].CharID));
              Write(#$00#$00#$00#$00);
              Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Promotion));
              Write(#$00#$00#$00#$00#$00);
              WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].EXP));
              Write(#$00#$00#$00);
              Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Level));
              Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$FF#$FF#$00#$00#$00#$04#$00#$00#$00#$00#$00#$01#$00+
                    #$00#$00#$00#$02#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$8C#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$05#$01#$FF#$00#$00+
                    #$00#$01#$00#$00#$04#$08#$01#$00#$00#$00#$00#$01#$00#$00#$04#$09#$01#$01#$00#$00#$00#$01#$00#$00#$04#$0B#$01#$02#$00#$00+
                    #$00#$01#$00#$00#$04#$0D#$01#$03#$00#$00#$00#$01#$00#$00#$04#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$04#$E2#$00#$00#$04#$E2#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$07);
            end;
            Write(#$00#$00#$00#$04#$13#$00#$A8#$C0#$01#$EC#$A8#$C0#$9B#$BA#$FE#$A9);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.Socket.RemoteAddr.sin_addr.S_addr));
            Write(#$00#$00#$00#$01#$7E#$F5#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$E5#$6A#$00#$00#$00#$01#$2C#$5B#$A7#$BD#$00#$00#$00#$00#$01#$00+
                  #$00#$E5#$88#$00#$00#$00#$01#$2C#$5B#$A7#$BE#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$56#$86#$32#$00#$56#$87+
                  #$6E#$37#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
                  #$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$46#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00);
            Compress;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Player.Send;
          Inc(NCount);
        end;
    end
    else begin
      Player.Buffer.BIn:='';
      with Player.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(1468));
        Write(#$00#$00#$00#$00#$06#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$01+
              #$30#$00#$00#$00#$F9#$00#$00#$09#$0D#$00#$00#$00#$00#$00#$00#$00#$00#$F2#$04#$00#$00#$00#$00#$00#$00#$13#$49#$F4#$FC#$09+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$09#$13#$F2#$04#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
        Compress;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Player.Send;
    end;
  end
  else
    Logger.Write('Sala nao existe',Errors);
end;

procedure TLobby.ChangeUserSettings(Player: TPlayer);
var
  i: Integer;
  Char, Test: Byte;
  Ready: Boolean;
begin
  logger.Write(player.Buffer.BOut,packets);
  if Player.AccInfo.Room > -1 then begin
    Char:=Player.Buffer.RB(29+Player.Buffer.RCd(17));
    Test:=Player.Buffer.RB(30+Player.Buffer.RCd(17));
    Ready:=Player.Buffer.RBo(39+Player.Buffer.RCd(17));
    if Player.Chars.isChar(Char) then begin
      if Test = 255 then
        Player.AccInfo.Char:=Char;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_USERUPDATE));
            Write(#$00#$00#$00#$2D#$00#$00#$00#$00#$00);
            WriteCd(Dword(Player.AccInfo.ID));
            Write(#$04#$00#$00#$00);
            Write(Byte(Length(Player.AccInfo.Login)*2));
            WriteZd(Player.AccInfo.Login);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].Team(Player)));
            Write(#$00#$00#$00);
            Write(Byte(Rooms[Player.AccInfo.Room].PlayerSlot(Player)));
            Write(Byte(Player.AccInfo.Char));
            Write(#$FF#$00#$FF#$00#$FF#$00#$00#$00#$00);
            Write(Word(Ready));
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
    end;
  end;
end;

procedure TLobby.SendGameInformation(Player: TPlayer);
var
  i, i2: Integer;
begin
  //Checa se está na sala e se está como "jogando"
  if (Player.AccInfo.Room > -1) then
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_GAMEINFORMATION));
          Write(#$00#$00#$00#$00#$00#$52#$3A#$E9#$A2#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00);
          WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
          for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
            if Rooms[Player.AccInfo.Room].Players[i2].Active then
              WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i2].Player.AccInfo.ID));
          Write(#$00#$02#$46#$FE);
          WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
          for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
            if Rooms[Player.AccInfo.Room].Players[i2].Active then begin
              WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i2].Player.AccInfo.ID));
              Write(#$00#$00#$01#$04#$00#$00#$00#$6A);
            end;
          Write(#$00#$00#$00#$00);
          WriteCd(Dword(Rooms[Player.AccInfo.Room].GetLeader.AccInfo.ID));
          Write(#$00#$00#$00#$00#$00#$00#$00);
          Write(Byte(Rooms[Player.AccInfo.Room].MatchMode));
          WriteCd(Dword(Rooms[Player.AccInfo.Room].GameMode));
          WriteCd(Dword(Rooms[Player.AccInfo.Room].ItemMode));
          Write(Rooms[Player.AccInfo.Room].isRand);
          WriteCd(Dword(Rooms[Player.AccInfo.Room].Map));
          Write(#$00#$00#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
                #$00#$01#$00#$00#$00);

          WriteCw(Word(Rooms[Player.AccInfo.Room].PlayersNumber));
          WriteCw(Word(Rooms[Player.AccInfo.Room].FreeSlots));
          for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
              Write(Rooms[Player.AccInfo.Room].Players[i2].Open);
          Write(#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$01#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00);
          WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
          for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
            if Rooms[Player.AccInfo.Room].Players[i2].Active then begin
              WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i2].Player.AccInfo.ID));
              Write(Byte(Rooms[Player.AccInfo.Room].Players[i2].Player.AccInfo.Char));
              Write(#$00#$00#$03#$E8);
            end;
          Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00);
          Compress;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i].Player.Send;
      end;
end;

procedure TLobby.SendPlayersInGame(Player: TPlayer);
var
  i: Integer;
begin
  if Player.AccInfo.Room > -1 then begin
    Player.Buffer.BIn:='';
    with Player.Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(SVPID_PLAYERSINGAME));
      Write(#$00#$00#$00#$14#$00);
      WriteCd(Dword(Rooms[PLayer.AccInfo.Room].PlayersNumber));
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active = True then begin
          WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.ID));
          Write(#$00#$00#$00#$00);
        end;
      FixSize;
      Encrypt(GenerateIV(0),Random($FF));
      ClearPacket();
    end;
    Player.Send;
  end;
end;

procedure TLobby.LoadSync(Player: TPlayer);
var
  ID, Percent, i: Integer;
begin
  //Checa se a sala está jogando
  if Player.AccInfo.Room > -1 then begin
    ID:=Player.Buffer.RCd(8);
    Percent:=Player.Buffer.RCd(12);
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        if Rooms[Player.AccInfo.Room].Players[i].Player = Player then
          Rooms[Player.AccInfo.Room].Players[i].LoadStatus:=Percent;
        Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_LOADSYNC));
          Write(#$00#$00#$00#$08#$00);
          WriteCd(Dword(ID));
          WriteCd(Dword(Percent));
          FixSize;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i].Player.Send;
      end;
  end;
end;

procedure TLobby.PlaySign(Player: TPlayer);
var
  i: Integer;
begin
  //Checa se a sala está jogando
  if Player.AccInfo.Room > -1 then begin
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then
        if Rooms[Player.AccInfo.Room].Players[i].LoadStatus < 17 then
          Exit;
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_PLAYSIGN));
          Write(#$00#$00#$00#$00#$00);
          Compress;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i].Player.Send;
      end;
  end;
end;

procedure TLobby.ChangeGameSettings(Player: TPlayer);
var
  GameMode: TGameMode;
  ItemMode: TItemMode;
  isRand, Active1, Active2: Boolean;
  Map: TMaps;
  MatchMode: TMatchMode;
  i, i2, Slot1, Slot2: Integer;
begin
  if (Player.Buffer.RB(6) = $51) then
    if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) then begin
      MatchMode:=TMatchMode(Player.Buffer.RB(15));
      GameMode:=TGameMode(Player.Buffer.RCd(16));
      ItemMode:=TItemMode(Player.Buffer.RCd(20));
      isRand:=Player.Buffer.RBo(24);
      Map:=TMaps(Player.Buffer.RCd(25));
      if MatchMode in [Low(TMatchMode)..High(TMatchMode)] = False then
        Exit;
      if GameMode in [Low(TGameMode)..High(TGameMode)] = False then
        Exit;
      if ItemMode in [Low(TItemMode)..High(TItemMode)] = False then
        Exit;
      if Map in [Low(TMaps)..High(TMaps)] = False then
        Exit;
      Rooms[Player.AccInfo.Room].MatchMode:=MatchMode;
      Rooms[Player.AccInfo.Room].GameMode:=GameMode;
      Rooms[Player.AccInfo.Room].ItemMode:=ItemMode;
      Rooms[Player.AccInfo.Room].Map:=Map;
      Rooms[Player.AccInfo.Room].isRand:=isRand;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_GAMEUPDATE));
            Write(#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00+
                  #$00#$00);
            Write(Byte(MatchMode));
            WriteCd(Dword(GameMode));
            WriteCd(Dword(ItemMode));
            Write(isRand);
            WriteCd(Dword(Map));
            Write(#$00#$00#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
                  #$00#$00#$00#$00#$00);
            WriteCw(Word(Rooms[Player.AccInfo.Room].PlayersNumber));
            WriteCw(Word(Rooms[Player.AccInfo.Room].FreeSlots));
            for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
              Write(Rooms[Player.AccInfo.Room].Players[i2].Open);
            Write(#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$01#$00#$00#$00#$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
    end;
  if Player.Buffer.RB(6) = $5B then
    if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) then begin
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_GAMEUPDATE));
            Write(#$00#$00#$00#$5B#$00#$00#$00#$00#$00#$00+
                  #$00#$00);
            Write(Byte(Rooms[Player.AccInfo.Room].MatchMode));
            WriteCd(Dword(Rooms[Player.AccInfo.Room].GameMode));
            WriteCd(Dword(Rooms[Player.AccInfo.Room].ItemMode));
            Write(Rooms[Player.AccInfo.Room].isRand);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].Map));
            Write(#$00#$00#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
                  #$00#$00#$00#$00#$00);
            WriteCw(Word(Rooms[Player.AccInfo.Room].PlayersNumber));
            WriteCw(Word(Rooms[Player.AccInfo.Room].FreeSlots));
            for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
              Write(Rooms[Player.AccInfo.Room].Players[i2].Open);
            Write(#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$01#$00#$00#$00#$00);
            {Write(#$00#$00#$00#$05#$01+
                  #$01#$02#$01#$03#$01#$04#$01#$05#$01#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$01#$00#$00#$00#$00); }
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
    end;
  if Player.Buffer.RB(6) = $55 then
    if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) then begin
      Slot1:=Player.Buffer.RB(58);
      Active1:=Player.Buffer.RBo(59);
      Slot2:=Player.Buffer.RB(60);
      Active2:=Player.Buffer.RBo(61);
      if (Rooms[Player.AccInfo.Room].Players[Slot1].Active = False) and (Rooms[Player.AccInfo.Room].Players[Slot2].Active = False) then begin
        Rooms[Player.AccInfo.Room].Players[Slot1].Open:=Active1;
        Rooms[Player.AccInfo.Room].Players[Slot2].Open:=Active2;
      end
      else
        Exit;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_GAMEUPDATE));
            Write(#$00#$00#$00#$55#$00#$00#$00#$00#$00#$00+
                  #$00#$00);
            Write(Byte(Rooms[Player.AccInfo.Room].MatchMode));
            WriteCd(Dword(Rooms[Player.AccInfo.Room].GameMode));
            WriteCd(Dword(Rooms[Player.AccInfo.Room].ItemMode));
            Write(Rooms[Player.AccInfo.Room].isRand);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].Map));
            Write(#$00#$00#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
                  #$00#$00#$00#$00#$00);
            WriteCw(Word(Rooms[Player.AccInfo.Room].PlayersNumber));
            WriteCw(Word(Rooms[Player.AccInfo.Room].FreeSlots));
            for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
              Write(Rooms[Player.AccInfo.Room].Players[i2].Open);
            Write(#$00#$00#$00#$02);
            Write(Byte(Slot1));
            Write(Active1);
            Write(Byte(Slot2));
            Write(Active2);
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
                  #$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
    end;
end;

procedure TLobby.ChangeRoomSettings(Player: TPlayer);
var
  NName, NPass: AnsiString;
  i: Integer;
begin
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) then begin
    NName:=Player.Buffer.RS(16,Player.Buffer.RB(15));
    NPass:=Player.Buffer.RS(20+Player.Buffer.RB(15),Player.Buffer.RB(19+Player.Buffer.RB(15)));
    Rooms[Player.AccInfo.Room].Name:=NName;
    Rooms[Player.AccInfo.Room].Pass:=NPass;
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_ROOMUPDATE));
          Write(#$00#$00#$00#$1E#$00#$00#$00#$00#$00);
          WriteCd(Dword(Length(NName)*2));
          WriteZd(NName);
          WriteCd(Dword(Length(NPass)*2));
          WriteZd(NPass);
          Write(#$00#$00#$02#$58#$00#$00#$00#$14#$01#$01);
          FixSize;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i].Player.Send;
      end;
  end;
end;

procedure TLobby.KickUser(Player: TPlayer);
var
  SlotID, i: Integer;
  Login: AnsiString;
begin
  //checa se está jogando
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) then
    if Rooms[Player.AccInfo.Room].TotalKicks > 0 then begin
      Login:=Player.Buffer.RS(16,Player.Buffer.RCd(12));
      SlotID:=-1;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then
          if Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Login = Login then begin
            SlotID:=i;
            Break;
          end;
      if SlotID = -1 then
        Exit;


      if Rooms[Player.AccInfo.Room].Players[SlotID].Active = True then begin

        Player.Buffer.BIn:='';
        with Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_EXITSIGN));
          Write(#$00);
          WriteCd(Dword(Length(Rooms[Player.AccInfo.Room].Players[SlotID].Player.AccInfo.Login)*2));
          WriteZd(Rooms[Player.AccInfo.Room].Players[SlotID].Player.AccInfo.Login);
          WriteCd(Dword(3));
          WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[SlotID].Player.AccInfo.ID));
          WriteCd(Dword(Rooms[Player.AccInfo.Room].TotalKicks-1));
          Compress;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Player.Send;
        //Envia o kick pro player
        Rooms[Player.AccInfo.Room].Players[SlotID].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[SlotID].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_EXITSIGN));
          Write(#$00#$00#$00#$1C#$00);
          WriteCd(Dword(Length(Rooms[Player.AccInfo.Room].Players[SlotID].Player.AccInfo.Login)*2));
          WriteZd(Rooms[Player.AccInfo.Room].Players[SlotID].Player.AccInfo.Login);
          WriteCd(Dword(3));
          WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[SlotID].Player.AccInfo.ID));
          Write(#$00#$2C#$30#$E8);
          FixSize;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[SlotID].Player.Send;

        Dec(Rooms[Player.AccInfo.Room].TotalKicks);
        Rooms[Player.AccInfo.Room].Players[SlotID].Active:=False;
        Rooms[Player.AccInfo.Room].Players[SlotID].Count:=0;
        Rooms[Player.AccInfo.Room].Players[SlotID].Player.AccInfo.Room:=-1;
      end;
    end;
end;

end.
