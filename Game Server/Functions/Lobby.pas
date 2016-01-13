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
    MM_DOTA = $000C
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
    Ready: Boolean;
    AFK: Boolean;
    Spree: Integer;
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
    Playing: Boolean;
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
    procedure Whisper(Player: TPlayer; Players: TList<TPlayer>);
    procedure CreateRoom(Player: TPlayer);
    procedure ExitRoom(Player: TPlayer);
    procedure SendRooms(Player: TPlayer);
    procedure EnterRoom(Player: TPlayer);
    procedure ChangeUserSettings(Player: TPlayer);
    procedure SendGameInformation(Player: TPlayer);
    procedure SendPlayersInGame(Player: TPlayer);
    procedure LoadSync(Player: TPlayer);
    procedure PlaySign(Player: TPlayer);
    procedure PlaySign2(Player: TPlayer);
    procedure ChangeGameSettings(Player: TPlayer);
    procedure ChangeRoomSettings(Player: TPlayer);
    procedure KickUser(Player: TPlayer);
    procedure AFK(Player: TPlayer);
    procedure SendAFKStatus(Player: TPlayer);
    procedure ParseGMCommand(Player: TPlayer; Text: AnsiString);
    procedure EndGame(Player: TPlayer);
    procedure KnS(Player: TPlayer);
  end;

implementation

uses GlobalDefs;

function isMatchMode(ID: Integer): Boolean;
begin
  if
    not (TMatchMode(ID) = TMatchMode.MM_Match) and
    not (TMatchMode(ID) = TMatchMode.MM_DEATHMATCH) and
    not (TMatchMode(ID) = TMatchMode.MM_DOTA)
  then
    Result:=False
  else
    Result:=True;
end;

function isMap(ID: Integer): Boolean;
begin
  if
    not (TMaps(ID) = TMaps.ELVEN_FOREST) and
    not (TMaps(ID) = TMaps.MARSH_OF_OBLIVION) and
    not (TMaps(ID) = TMaps.AIRSHIP) and
    not (TMaps(ID) = TMaps.GORGE_OF_OATH) and
    not (TMaps(ID) = TMaps.FORGOTTEN_CITY) and
    not (TMaps(ID) = TMaps.CHRISTMAS_BABEL) and
    not (TMaps(ID) = TMaps.TEMPLE_OF_FIRE) and
    not (TMaps(ID) = TMaps.SHOOTING_RANGE) and
    not (TMaps(ID) = TMaps.HELL_BRIDGE) and
    not (TMaps(ID) = TMaps.ORC_TEMPLE) and
    not (TMaps(ID) = TMaps.OUTER_WALL_OF_SERDIN) and
    not (TMaps(ID) = TMaps.KERRIE_BEACH) and
    not (TMaps(ID) = TMaps.TRIAL_FOREST) and
    not (TMaps(ID) = TMaps.FORSAKEN_BARROWS) and
    not (TMaps(ID) = TMaps.KOUNATS_SECRET_ARENA) and
    not (TMaps(ID) = TMaps.UNDERWORLD)
  then
    Result:=False
  else
    Result:=True;
end;

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

procedure TLobby.ParseGMCommand(Player: TPlayer; Text: AnsiString);
var
  i: TMatchMode;
  i2, i3, NSerdin, NCanaban: Integer;
begin
  if (Text = '/changemode') and (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
    if High(TMatchMode) = Rooms[Player.AccInfo.Room].MatchMode then begin
      for i:=Low(TMatchMode) to High(TMatchMode) do
        if isMatchMode(Integer(i)) then begin
          Rooms[Player.AccInfo.Room].MatchMode:=i;
          Break;
        end;
    end
    else begin
      for i:=Rooms[Player.AccInfo.Room].MatchMode to High(TMatchMode) do
        if i <> Rooms[Player.AccInfo.Room].MatchMode then
          if isMatchMode(Integer(i)) then begin
            Rooms[Player.AccInfo.Room].MatchMode:=i;
            Break;
          end;
    end;
    for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i2].Active then begin
        Rooms[Player.AccInfo.Room].Players[i2].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i2].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_GAMEUPDATE));
          Write(#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00+
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
          for i3:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
            Write(Rooms[Player.AccInfo.Room].Players[i3].Open);
          Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$01#$00#$00#$00#$00);
          FixSize;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i2].Player.Send;
      end;
  end
  else
    if (Text = '/forcestart') and (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
      NSerdin:=0;
      for i2:=0 to 2 do
        if (Rooms[Player.AccInfo.Room].Players[i2].Active = False) and (Rooms[Player.AccInfo.Room].Players[i2].Open = True) then
          Inc(NSerdin);
      NCanaban:=0;
      for i2:=3 to 5 do
        if (Rooms[Player.AccInfo.Room].Players[i2].Active = False) and (Rooms[Player.AccInfo.Room].Players[i2].Open = True) then
          Inc(NCanaban);
      if NSerdin = NCanaban then begin
        Rooms[Player.AccInfo.Room].Playing:=True;
        for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
          if Rooms[Player.AccInfo.Room].Players[i2].Active then begin
            Rooms[Player.AccInfo.Room].Players[i2].Player.Buffer.BIn:='';
            with Rooms[Player.AccInfo.Room].Players[i2].Player.Buffer do begin
              Write(Prefix);
              Write(Dword(Count));
              WriteCw(Word(SVPID_GAMEINFORMATION));
              Write(#$00#$00#$00#$00#$00#$52#$3A#$E9#$A2#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00);
              WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
              for i3:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
                if Rooms[Player.AccInfo.Room].Players[i3].Active then
                  WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i3].Player.AccInfo.ID));
              Write(#$00#$02#$46#$FE);
              WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
              for i3:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
                if Rooms[Player.AccInfo.Room].Players[i3].Active then begin
                  WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i3].Player.AccInfo.ID));
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
              for i3:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
                  Write(Rooms[Player.AccInfo.Room].Players[i3].Open);
              Write(#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$01#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00);
              WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
              for i3:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
                if Rooms[Player.AccInfo.Room].Players[i3].Active then begin
                  WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i3].Player.AccInfo.ID));
                  Write(Byte(Rooms[Player.AccInfo.Room].Players[i3].Player.AccInfo.Char));
                  Write(#$00#$00#$03#$E8);
                end;
              Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00);
              Compress;
              Encrypt(GenerateIV(0),Random($FF));
              ClearPacket();
            end;
            Rooms[Player.AccInfo.Room].Players[i2].Player.Send;
          end;
      end;
    end
    else
      Exit;
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_CHAT));
    Write(#$00#$00#$00#$3F#$00#$01);
    WriteCd(Dword(0));
    Write(#$00#$00#$00);
    Write(Byte(Length('Servidor')*2));
    WriteZd('Servidor');
    Write(#$00#$00#$00#$00#$00#$00#$00#$00#$FF#$FF+
          #$FF#$FF#$00#$00#$00);
    Write(Byte(Length('Comando aplicado com sucesso!')*2));
    WriteZd('Comando aplicado com sucesso!');
    Write(#$00#$00#$00#$00#$00#$00#$00#$00);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TLobby.Chat(Player: TPlayer; Players: TList<TPlayer>);
var
  Msg: AnsiString;
  Temp: TPlayer;
begin
  Msg:=Player.Buffer.RS(33+Player.Buffer.RB(16),Player.Buffer.RB(32+Player.Buffer.RB(16)));
  if (Msg[1] = '/') and (Player.AccInfo.GM) then
    ParseGMCommand(Player,Msg)
  else
    for Temp in Players do
      if Temp.AccInfo.Room = Temp.AccInfo.Room then begin
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

procedure TLobby.Whisper(Player: TPlayer; Players: TList<TPlayer>);
var
  Nick, Msg: AnsiString;
  Send: Boolean;
  Temp: TPlayer;
begin
  Nick:=Player.Buffer.RS(12,Player.Buffer.RCd(8));
  Msg:=Player.Buffer.RS(16+Player.Buffer.RCd(8),Player.Buffer.RCd(12+Player.Buffer.RCd(8)));
  Send:=False;
  for Temp in Players do
    if Temp.AccInfo.Nick = Nick then begin
      Player.Buffer.BIn:='';
      with Player.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(SVPID_WHISPER));
        Write(#$00#$00#$00#$5B#$00#$00#$00#$00#$00#$03);
        WriteCd(Dword(Player.AccInfo.ID));
        WriteCd(Dword(Length(Player.AccInfo.Nick)*2));
        WriteZd(Player.AccInfo.Nick);
        WriteCd(Dword(Temp.AccInfo.ID));
        WriteCd(Dword(Length(Temp.AccInfo.Nick)*2));
        WriteZd(Temp.AccInfo.Nick);
        Write(#$00#$00#$00#$00);
        WriteCd(Dword(Length(Msg)*2));
        WriteZd(Msg);
        Write(#$00#$00#$00#$00#$00#$00#$00#$00);
        FixSize;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Player.Send;
      Temp.Buffer.BIn:='';
      with Temp.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(SVPID_CHAT));
        Write(#$00#$00#$00#$45#$00#$03);
        WriteCd(Dword(Player.AccInfo.ID));
        WriteCd(Dword(Length(Player.AccInfo.Nick)*2));
        WriteZd(Player.AccInfo.Nick);
        WriteCd(Dword(Temp.AccInfo.ID));
        WriteCd(Dword(Length(Temp.AccInfo.Nick)*2));
        WriteZd(Temp.AccInfo.Nick);
        Write(#$00#$00#$00#$00);
        WriteCd(Dword(Length(Msg)*2));
        WriteZd(Msg);
        Write(#$00#$00#$00#$00#$00#$00#$00#$00);
        FixSize;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Temp.Send;
      Send:=True;
      Break;
    end;
  if Send = False then begin
    Player.Buffer.BIn:='';
    with Player.Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(SVPID_WHISPER));
      Write(#$00#$00#$00#$4B#$00#$00#$00#$00#$04#$03);
      WriteCd(Dword(Player.AccInfo.ID));
      WriteCd(Dword(Length(Player.AccInfo.Nick)*2));
      WriteZd(Player.AccInfo.Nick);
      Write(#$00#$00#$00#$00);
      WriteCd(Dword(Length(Nick)*2));
      WriteZd(Nick);
      Write(#$00#$00#$00#$00);
      WriteCd(Dword(Length(Msg)*2));
      WriteZd(Msg);
      Write(#$00#$00#$00#$00#$00#$00#$00#$00);
      FixSize;
      Encrypt(GenerateIV(0),Random($FF));
      ClearPacket();
    end;
    Player.Send;
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
        Rooms[i].Playing:=False;
        for i2:=0 to Length(Rooms[i].Players)-1 do begin
          Rooms[i].Players[i2].Active:=False;
          Rooms[i].Players[i2].Open:=True;
          Rooms[i].Players[i2].Count:=0;
          Rooms[i].Players[i2].LoadStatus:=0;
          Rooms[i].Players[i2].Spree:=0;
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
      Rooms[Length(Rooms)-1].Playing:=False;
      for i2:=0 to Length(Rooms[Length(Rooms)-1].Players)-1 do begin
        Rooms[Length(Rooms)-1].Players[i2].Active:=False;
        Rooms[Length(Rooms)-1].Players[i2].Open:=True;
        Rooms[Length(Rooms)-1].Players[i2].Count:=0;
        Rooms[Length(Rooms)-1].Players[i2].LoadStatus:=0;
        Rooms[Length(Rooms)-1].Players[i2].Spree:=0;
      end;
      N:=Length(Rooms)-1;
    end;
    Rooms[N].Players[0].Active:=True;
    Rooms[N].Players[0].Player:=Player;
    Rooms[N].Players[0].Open:=False;
    Inc(Rooms[N].NCount);
    Rooms[N].Players[0].Count:=Rooms[N].NCount;
    Player.AccInfo.Room:=N;
    Player.Buffer.BIn:='';
    with Player.Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(25));
      Write(#$00#$00#$00#$00#$00);
      WriteCd(Dword(Length(Player.AccInfo.Login)*2));
      WriteZd(Player.AccInfo.Login);
      WriteCd(Dword(Player.AccInfo.ID));
      WriteCd(Dword(Length(Player.AccInfo.Nick)*2));
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
        Write(#$00#$00#$00#$00#$00#$00#$00#$00);
        WriteCd(Dword(Length(Player.Chars.Chars[i].Equips)));
        for i2:=0 to Length(Player.Chars.Chars[i].Equips)-1 do begin
          WriteCd(Dword(Player.Chars.Chars[i].Equips[i2].ItemID));
          Write(#$00#$00#$00#$01);
          WriteCd(Dword(Player.Chars.Chars[i].Equips[i2].ID));
          Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00);
        end;
        Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$FF#$FF#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$01+
              #$FF#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$01#$2C#$00#$00#$01#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$07);
      end;
      Write(#$00#$00#$00#$04#$13#$00#$A8#$C0#$01#$EC#$A8#$C0#$9B#$BA#$FE#$A9);
      WriteCd(Dword(Player.Socket.RemoteAddr.sin_addr.S_addr));
      Write(#$00#$00#$00#$01#$7E#$F5#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$E5#$6A#$00#$00#$00#$01+
            #$2C#$5B#$A7#$BD#$00#$00#$00#$00#$01#$00#$00#$E5#$88#$00#$00#$00#$01#$2C#$5B#$A7#$BE#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$01#$56#$86#$32#$00#$56#$87#$6E#$37#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$46#$00+
            #$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
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
      Write(#$01#$00#$01#$00#$00#$01#$2C#$00#$00#$00#$14#$00#$02#$4B#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$06#$01#$00#$00#$00#$00);
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
            if Rooms[Player.AccInfo.Room].Players[i].Player = Rooms[Player.AccInfo.Room].GetLeader then
              Rooms[Player.AccInfo.Room].Players[i].Ready:=False;
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
        Write(Rooms[i].Playing);
        Write(#$2E#$02#$1B#$25#$01#$00#$00#$00#$00#$01+
              #$6B#$F9#$38#$77#$00#$00#$00#$0C#$00#$00+
              #$00#$00#$00#$00#$00#$01);
        WriteCd(Dword(Length(Rooms[i].GetLeader.AccInfo.Nick)*2));
        WriteZd(Rooms[i].GetLeader.AccInfo.Nick);
        Write(#$0B#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$01);
      end;
    Compress;
    Temp:=Copy(Player.Buffer.BIn,10,Length(Player.Buffer.BIn));
    Player.Buffer.BIn:=Copy(Player.Buffer.BIn,1,8);
    WriteCd(Dword(Length(Temp)+13));
    Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$01#$00);
    Write(Temp);
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TLobby.EnterRoom(Player: TPlayer);
var
  N, i, i2, i3, NSerdin, NCanaban, NCount: Integer;
  Pass: AnsiString;
begin
  Player.Buffer.Decompress;
  N:=Player.Buffer.RCw(16);
  Pass:=Player.Buffer.RS(22,Player.Buffer.RB(21));
  if (Rooms[N].Active = True) and (Rooms[N].FreeSlots > 0) and (Rooms[N].Playing = False) and (Player.AccInfo.Room = -1) then begin
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
            Rooms[N].Players[i].Spree:=0;
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
            Rooms[N].Players[i].Spree:=0;
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
            Write(#$00);
            WriteCd(Dword(Length(Player.AccInfo.Login)*2));
            WriteZd(Player.AccInfo.Login);
            WriteCd(Dword(Player.AccInfo.ID));
            WriteCd(Dword(Length(Player.AccInfo.Nick)*2));
            WriteZd(Player.AccInfo.Nick);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayerSlot(Player)));
            Write(Byte(Player.AccInfo.Char));
            Write(#$00#$FF#$00#$FF#$00#$FF#$00#$00#$00#$00);
            Write(Byte(Rooms[Player.AccInfo.Room].Team(Player)));
            Write(#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$10#$F4#$00#$00#$00#$00#$00#$4E#$00#$00#$00#$07#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$08#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$09#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0D#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$0E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$10#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$11#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$12#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$13#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$15#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$16#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$17#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$18#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$19#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$1A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$1D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1E#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$24#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$27#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$28#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$29#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$2A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2D#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$2E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2F#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$31#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$32#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$33#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$34#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$35#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$36#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$37#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$38#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$39#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$3A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$3C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3D#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$3E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3F#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$40#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$43#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$44#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$45#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$47#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$49#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4E#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$4F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$50#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$53#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$54#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$55#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$56#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$57#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$58#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$59#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5A#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$5B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5C#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$5D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5E#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
            if Rooms[Player.AccInfo.Room].GetLeader = Player then
              Write(#$01)
            else
              Write(#$00);
            Write(#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
            Write(Byte(Length(Player.Chars.Chars)));
            for i2:=0 to Length(Player.Chars.Chars)-1 do begin
              Write(Byte(Player.Chars.Chars[i2].CharID));
              Write(#$00#$00#$00#$00);
              Write(Byte(Player.Chars.Chars[i2].Promotion));
              Write(#$00#$00#$00#$00#$00);
              WriteCd(Dword(Player.Chars.Chars[i2].EXP));
              Write(#$00#$00#$00);
              Write(Byte(Player.Chars.Chars[i2].Level));
              Write(#$00#$00#$00#$00#$00#$00#$00#$00);
              WriteCd(Dword(Length(Player.Chars.Chars[i2].Equips)));
              for i3:=0 to Length(Player.Chars.Chars[i2].Equips)-1 do begin
                WriteCd(Dword(Player.Chars.Chars[i2].Equips[i3].ItemID));
                Write(#$00#$00#$00#$01);
                WriteCd(Dword(Player.Chars.Chars[i2].Equips[i3].ID));
                Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                      #$00#$00#$00#$00#$00#$00#$00#$00#$00);
              end;
              Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$FF#$FF#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$01+
                    #$FF#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$01#$2C#$00#$00#$01#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$07);
            end;
            Write(#$00#$00#$00#$04#$13#$00#$A8#$C0#$01#$EC#$A8#$C0#$9B#$BA#$FE#$A9);
            WriteCd(Dword(Player.Socket.RemoteAddr.sin_addr.S_addr));
            Write(#$00#$00#$00#$01#$7E#$F6#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$E5#$6A#$00#$00#$00#$01+
                  #$2C#$BD#$52#$5A#$00#$00#$00#$00#$01#$00#$00#$E5#$88#$00#$00#$00#$01#$2C#$BD#$52#$5B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$01#$56#$86#$32#$00#$56#$87#$6E#$D4#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00+
                  #$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
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
        Write(#$01#$00#$01#$00#$00#$01#$2C#$00#$00#$00#$14#$00#$02#$4B#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$06#$01#$00#$00#$00#$00);
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
            WriteCd(Dword(Length(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Login)*2));
            WriteZd(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Login);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.ID));
            WriteCd(Dword(Length(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Nick)*2));
            WriteZd(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Nick);
            WriteCd(Dword(i));
            Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Char));
            Write(#$00#$FF#$00#$FF#$00#$FF#$00#$00#$00#$00);
            Write(Byte(Rooms[Player.AccInfo.Room].Team(Rooms[Player.AccInfo.Room].Players[i].Player)));
            Write(#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$10#$F4#$00#$00#$00#$00#$00#$4E#$00#$00#$00#$07#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$08#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$09#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0D#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$0E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$10#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$11#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$12#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$13#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$15#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$16#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$17#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$18#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$19#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$1A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$1D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1E#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$24#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$27#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$28#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$29#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$2A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2D#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$2E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2F#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$31#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$32#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$33#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$34#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$35#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$36#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$37#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$38#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$39#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$3A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$3C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3D#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$3E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3F#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$40#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$43#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$44#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$45#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$47#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$49#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4B#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4E#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$4F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$50#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$52#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$53#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$54#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$55#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$56#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$57#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$58#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$59#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5A#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$5B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5C#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$5D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5E#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
            if Rooms[Player.AccInfo.Room].GetLeader = Rooms[Player.AccInfo.Room].Players[i].Player then
              Write(#$01)
            else
              Write(#$00);
            Write(#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
            Write(Byte(Length(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars)));
            for i2:=0 to Length(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars)-1 do begin
              Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].CharID));
              Write(#$00#$00#$00#$00);
              Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Promotion));
              Write(#$00#$00#$00#$00#$00);
              WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].EXP));
              Write(#$00#$00#$00);
              Write(Byte(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Level));
              Write(#$00#$00#$00#$00#$00#$00#$00#$00);
              WriteCd(Dword(Length(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Equips)));
              for i3:=0 to Length(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Equips)-1 do begin
                WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Equips[i3].ItemID));
                Write(#$00#$00#$00#$01);
                WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.Chars.Chars[i2].Equips[i3].ID));
                Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                      #$00#$00#$00#$00#$00#$00#$00#$00#$00);
              end;
              Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$FF#$FF#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$01+
                    #$FF#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$01#$2C#$00#$00#$01#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$07);
            end;
            Write(#$00#$00#$00#$04#$13#$00#$A8#$C0#$01#$EC#$A8#$C0#$9B#$BA#$FE#$A9);
            WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.Socket.RemoteAddr.sin_addr.S_addr));
            Write(#$00#$00#$00#$01#$7E#$F5#$00#$00#$00);
            Write(Rooms[Player.AccInfo.Room].Players[i].Ready);
            Write(#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$E5#$6A#$00#$00#$00#$01#$2C#$BD#$52#$5A#$00#$00#$00#$00#$01#$00+
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
  i, Space: Integer;
  Char, Test, Team: Byte;
  Ready: Boolean;
begin
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
    Team:=Player.Buffer.RB(24+Player.Buffer.RCd(17));
    Char:=Player.Buffer.RB(29+Player.Buffer.RCd(17));
    Test:=Player.Buffer.RB(30+Player.Buffer.RCd(17));
    Ready:=Player.Buffer.RBo(39+Player.Buffer.RCd(17));
    if Player.Chars.isChar(Char) then begin
      if Test = 255 then begin
        Player.AccInfo.Char:=Char;
        if Rooms[Player.AccInfo.Room].Team(Player) <> Team then begin
          Space:=-1;
          if Team = 0 then
            for i:=0 to 2 do
              if (Rooms[Player.AccInfo.Room].Players[i].Active = False) and (Rooms[Player.AccInfo.Room].Players[i].Open = True) then begin
                Space:=i;
                Break;
              end;
          if Team = 1 then
            for i:=3 to 5 do
              if (Rooms[Player.AccInfo.Room].Players[i].Active = False) and (Rooms[Player.AccInfo.Room].Players[i].Open = True) then begin
                Space:=i;
                Break;
              end;
          if Space = -1 then
            Exit;
          for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
            if Rooms[Player.AccInfo.Room].Players[i].Player = Player then begin
              Rooms[Player.AccInfo.Room].Players[Space].Active:=Rooms[Player.AccInfo.Room].Players[i].Active;
              Rooms[Player.AccInfo.Room].Players[Space].Open:=Rooms[Player.AccInfo.Room].Players[i].Open;
              Rooms[Player.AccInfo.Room].Players[Space].Player:=Rooms[Player.AccInfo.Room].Players[i].Player;
              Rooms[Player.AccInfo.Room].Players[Space].Count:=Rooms[Player.AccInfo.Room].Players[i].Count;
              Rooms[Player.AccInfo.Room].Players[Space].LoadStatus:=Rooms[Player.AccInfo.Room].Players[i].LoadStatus;
              Rooms[Player.AccInfo.Room].Players[Space].Ready:=Rooms[Player.AccInfo.Room].Players[i].Ready;
              Rooms[Player.AccInfo.Room].Players[i].Active:=False;
              Rooms[Player.AccInfo.Room].Players[i].Open:=True;
              Rooms[Player.AccInfo.Room].Players[i].Player:=TPlayer(-1);
              Rooms[Player.AccInfo.Room].Players[i].Count:=0;
              Rooms[Player.AccInfo.Room].Players[i].LoadStatus:=0;
              Rooms[Player.AccInfo.Room].Players[i].Ready:=False;
              Break;
            end;
        end;
      end;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          if Rooms[Player.AccInfo.Room].Players[i].Player = Player then
            Rooms[Player.AccInfo.Room].Players[i].Ready:=Ready;
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
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active = True then
        if Rooms[Player.AccInfo.Room].Players[i].Player <> Player then
          if Rooms[Player.AccInfo.Room].Players[i].Ready = False then
            Exit;
    Rooms[Player.AccInfo.Room].Playing:=True;
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
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].Playing = True) then begin
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
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].Playing = True) then begin
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

procedure TLobby.PlaySign2(Player: TPlayer);
var
  i: Integer;
begin
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].Playing = True) then begin
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
          WriteCw(Word(SVPID_PLAYSIGN2));
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
    if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
      MatchMode:=TMatchMode(Player.Buffer.RB(15));
      GameMode:=TGameMode(Player.Buffer.RCd(16));
      ItemMode:=TItemMode(Player.Buffer.RCd(20));
      isRand:=Player.Buffer.RBo(24);
      Map:=TMaps(Player.Buffer.RCd(25));
      if isMatchMode(Integer(MatchMode)) = False then
        Exit;
      if GameMode in [Low(TGameMode)..High(TGameMode)] = False then
        Exit;
      if ItemMode in [Low(TItemMode)..High(TItemMode)] = False then
        Exit;
      if isMap(Integer(Map)) = False then
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
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$01#$00#$00#$00#$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
    end;
  if (Player.Buffer.RB(6) = $53) and (Rooms[Player.AccInfo.Room].GameMode = GM_SOLO) then
    if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
      Slot1:=Player.Buffer.RB(58);
      Active1:=Player.Buffer.RBo(59);
      if (Rooms[Player.AccInfo.Room].Players[Slot1].Active = False) then
        Rooms[Player.AccInfo.Room].Players[Slot1].Open:=Active1
      else
        Exit;
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_GAMEUPDATE));
            Write(#$00#$00#$00#$53#$00#$00#$00#$00#$00#$00+
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
            Write(#$00#$00#$00#$01);
            Write(Byte(Slot1));
            Write(Active1);
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$01#$00+
                  #$00#$00#$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
    end;
  if (Player.Buffer.RB(6) = $55) and (Rooms[Player.AccInfo.Room].GameMode = GM_TEAM) then
    if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
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
  if Player.Buffer.RB(6) = $5B then
    if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
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
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$01#$00#$00#$00#$00);
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
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) and (Rooms[Player.AccInfo.Room].Playing = False) then begin
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
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].GetLeader = Player) and (Rooms[Player.AccInfo.Room].Playing = False) then
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

procedure TLobby.AFK(Player: TPlayer);
var
  AFK: Boolean;
  i: Integer;
begin
  AFK:=Player.Buffer.RBo(11);
  if Player.AccInfo.Room > -1 then begin
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Player = Player then begin
        Rooms[Player.AccInfo.Room].Players[i].AFK:=AFK;
        Break;
      end;
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_AFK));
          Write(#$00#$00#$00#$08#$00);
          WriteCd(Dword(Player.AccInfo.ID));
          WriteCd(Dword(AFK));
          FixSize;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i].Player.Send;
      end;
  end
  else begin
    Player.Buffer.BIn:='';
    with Player.Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(SVPID_AFK));
      Write(#$00#$00#$00#$08#$00);
      WriteCd(Dword(Player.AccInfo.ID));
      WriteCd(Dword(AFK));
      FixSize;
      Encrypt(GenerateIV(0),Random($FF));
      ClearPacket();
    end;
    Player.Send;
  end;
end;

procedure TLobby.SendAFKStatus(Player: TPlayer);
var
  i: Integer;
begin
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_AFKSTATUS));
    Write(#$00#$00#$00#$14#$00);
    WriteCd(Dword(Rooms[Player.AccInfo.Room].PlayersNumber));
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.ID));
        WriteCd(Dword(Rooms[Player.AccInfo.Room].Players[i].AFK));
      end;
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TLobby.KnS(Player: TPlayer);
var
  ID1, ID2, i: Integer;
  Nick1, Nick2, Spree: AnsiString;
  Parado: Boolean;
begin
  if (Player.AccInfo.Room > -1) and (Rooms[Player.AccInfo.Room].Playing = True) then begin
    ID1:=Player.Buffer.RCd(8);
    ID2:=Player.Buffer.RCd(13);
    Parado:=False;

    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word($39B));
          Write(#$00#$00#$00#$00#$02#$00#$00#$00#$01#$0E#$00#$00#$00#$00#$00#$00#$02#$2B#$00#$00#$00#$00#$00#$01#$01#$AB#$00#$00#$00#$02+
                #$00#$00#$00#$1E#$41#$84#$00#$00#$00#$00#$00#$06#$00#$00#$00#$A0#$00#$00#$00#$02#$01#$00#$00#$00#$00#$00#$00#$01#$58#$00+
                #$00#$00#$00#$00#$00#$01#$58#$00#$00#$00#$02#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
          Compress;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i].Player.Send;
      end;


    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do begin
      if (Rooms[Player.AccInfo.Room].Players[i].Active) and (Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.ID = ID1) then begin
        Nick1:=Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Nick;
        Inc(Rooms[Player.AccInfo.Room].Players[i].Spree);
        Spree:='';
        if Rooms[Player.AccInfo.Room].Players[i].Spree = 3 then
          Spree:=' e está em uma Killing Spree';
        if Rooms[Player.AccInfo.Room].Players[i].Spree = 4 then
          Spree:=' e está Enfurecido';
        if Rooms[Player.AccInfo.Room].Players[i].Spree = 5 then
          Spree:=' e está Implacável';
        if Rooms[Player.AccInfo.Room].Players[i].Spree = 6 then
          Spree:=' e está Dominando';
        if Rooms[Player.AccInfo.Room].Players[i].Spree = 7 then
          Spree:=' e está Invencível';
        if Rooms[Player.AccInfo.Room].Players[i].Spree >= 8 then
          Spree:=' e está Lendário';
      end;
      if (Rooms[Player.AccInfo.Room].Players[i].Active) and (Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.ID = ID2) then begin
        Nick2:=Rooms[Player.AccInfo.Room].Players[i].Player.AccInfo.Nick;
        if Rooms[Player.AccInfo.Room].Players[i].Spree >= 3 then
          Parado:=True;
        Rooms[Player.AccInfo.Room].Players[i].Spree:=0;
      end;
    end;
    for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
      if Rooms[Player.AccInfo.Room].Players[i].Active then begin
        Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
        with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_CHAT));
          Write(#$00#$00#$00#$3F#$00#$01);
          WriteCd(Dword(0));
          Write(#$00#$00#$00);
          Write(Byte(Length('Servidor')*2));
          WriteZd('Servidor');
          Write(#$00#$00#$00#$00#$00#$00#$00#$00#$FF#$FF+
                #$FF#$FF#$00#$00#$00);
          Write(Byte(Length('O Player '+Nick1+' matou '+Nick2+Spree)*2));
          WriteZd('O Player '+Nick1+' matou '+Nick2+Spree);
          Write(#$00#$00#$00#$00#$00#$00#$00#$00);
          FixSize;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Rooms[Player.AccInfo.Room].Players[i].Player.Send;
      end;
    if Parado = True then
      for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
        if Rooms[Player.AccInfo.Room].Players[i].Active then begin
          Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
          with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_CHAT));
            Write(#$00#$00#$00#$3F#$00#$01);
            WriteCd(Dword(0));
            Write(#$00#$00#$00);
            Write(Byte(Length('Servidor')*2));
            WriteZd('Servidor');
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$FF#$FF+
                  #$FF#$FF#$00#$00#$00);
            Write(Byte(Length('O Player '+Nick2+' foi parado')*2));
            WriteZd('O Player '+Nick1+' matou '+Nick2+Spree);
            Write(#$00#$00#$00#$00#$00#$00#$00#$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Rooms[Player.AccInfo.Room].Players[i].Player.Send;
        end;
  end;
end;

procedure TLobby.EndGame(Player: TPlayer);
var
  i: Integer;
begin
  Logger.Write(Player.Buffer.BOut,packets);
  for i:=0 to Length(Rooms[Player.AccInfo.Room].Players)-1 do
    if Rooms[Player.AccInfo.Room].Players[i].Active then begin
      Rooms[Player.AccInfo.Room].Players[i].Player.Buffer.BIn:='';
      with Rooms[Player.AccInfo.Room].Players[i].Player.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        Write(#$03);
        Write(Word($7F));
        Write(#$00#$00#$00#$01#$00#$00#$00#$02#$00#$00#$00#$0C#$73#$00#$6F#$00#$6E#$00#$65#$00#$78#$00#$61#$00#$00#$00#$00#$01#$00#$00+
              #$20#$67#$00#$00#$00#$96#$00#$00#$00#$00#$00#$00#$00#$04#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00+
              #$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$04#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$0E#$00+
              #$00#$00#$01#$00#$00#$00#$01#$0E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$01+
              #$18#$8C#$00#$00#$00#$01#$2C#$DD#$78#$9F#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$FF#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4E#$00#$00#$00#$07#$00#$00#$00#$01#$01#$01#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$08#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$09#$00#$00#$00#$01#$01#$01#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$0A#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0B#$00#$00#$00#$01#$01+
              #$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0C#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0D#$00#$00#$00+
              #$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0E#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0F#$00+
              #$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$10#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$11#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$12#$00#$00#$00#$01#$01#$01#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$13#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$14#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00+
              #$00#$00#$00#$00#$15#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$16#$00#$00#$00#$01#$07#$01#$00#$01#$00+
              #$02#$00#$00#$00#$00#$00#$17#$00#$00#$00#$01#$07#$01#$00#$01#$00#$00#$00#$00#$00#$00#$00#$18#$00#$00#$00#$01#$07#$01#$00+
              #$01#$00#$02#$00#$00#$00#$00#$00#$19#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$1A#$00#$00#$00#$01#$07+
              #$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$1B#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$1D#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1E#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$24#$00#$00+
              #$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$27#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$28+
              #$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$29#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00+
              #$00#$2A#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$2B#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00+
              #$00#$00#$00#$2C#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$2D#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01+
              #$00#$00#$00#$00#$00#$2E#$00#$00#$00#$01#$03#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$2F#$00#$00#$00#$01#$07#$01#$00#$01+
              #$00#$02#$00#$00#$00#$00#$00#$30#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$31#$00#$00#$00#$01#$07#$01+
              #$00#$01#$00#$02#$00#$00#$00#$00#$00#$32#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$33#$00#$00#$00#$01+
              #$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$34#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$35#$00#$00+
              #$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$36#$00#$00#$00#$01#$07#$01#$00#$01#$00#$02#$00#$00#$00#$00#$00#$37+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$38#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$39+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3B+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3D+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$3F+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$40#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$43+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$44#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$45+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$47+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$49+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4B+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4E+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$50+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$52+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$53#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$54+
              #$00#$00#$00#$01#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$55#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$56#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$57#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$58#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$59#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$5A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$5C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$5E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$01#$0E#$0E#$00#$00#$00#$00#$00#$00#$01#$CB#$00#$00#$00#$00#$00#$1B#$0A#$F1#$00#$00#$00#$18#$00#$00+
              #$00#$04#$00#$00#$00#$A0#$00#$00#$00#$04#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00#$00#$04#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$04#$00#$00#$00#$00#$00#$00#$00#$04#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$04#$00#$00#$00#$00+
              #$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$2C#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$14#$00#$07#$0D#$BE#$00#$00#$00#$01#$00#$98#$96#$81#$00#$00#$00#$00#$56#$76#$25#$68#$56#$74#$D3+
              #$E8#$00#$00#$00#$00#$00#$07#$0D#$C8#$00#$00#$00#$01#$00#$98#$96#$82#$00#$00#$00#$00#$56#$76#$25#$68#$56#$74#$D3#$E8#$00+
              #$00#$00#$00#$00#$07#$0D#$D2#$00#$00#$00#$01#$00#$98#$96#$83#$00#$00#$00#$00#$56#$7B#$21#$D0#$56#$79#$D0#$50#$00#$00#$00+
              #$00#$00#$07#$0D#$DC#$00#$00#$00#$01#$00#$98#$96#$84#$00#$00#$00#$00#$56#$7B#$21#$D0#$56#$79#$D0#$50#$00#$00#$00#$00#$00+
              #$07#$19#$08#$00#$00#$00#$01#$00#$98#$96#$81#$00#$00#$00#$00#$56#$76#$25#$68#$56#$74#$D3#$E8#$00#$00#$00#$00#$00#$07#$19+
              #$12#$00#$00#$00#$01#$00#$98#$96#$82#$00#$00#$00#$00#$56#$76#$25#$68#$56#$74#$D3#$E8#$00#$00#$00#$00#$00#$07#$22#$18#$00+
              #$00#$00#$01#$00#$98#$97#$69#$00#$00#$00#$00#$56#$76#$25#$E0#$56#$74#$D4#$60#$00#$00#$00#$00#$00#$07#$22#$2C#$00#$00#$00+
              #$01#$00#$98#$97#$6B#$00#$00#$00#$00#$56#$76#$25#$E0#$56#$74#$D4#$60#$00#$00#$00#$00#$00#$07#$22#$90#$00#$00#$00#$01#$00+
              #$98#$97#$75#$00#$00#$00#$00#$56#$76#$25#$E0#$56#$74#$D4#$60#$00#$00#$00#$00#$00#$07#$24#$52#$00#$00#$00#$01#$00#$98#$96+
              #$81#$00#$00#$00#$01#$56#$76#$25#$68#$56#$74#$D3#$E8#$00#$00#$00#$01#$00#$07#$24#$5C#$00#$00#$00#$01#$00#$98#$96#$82#$00+
              #$00#$00#$01#$56#$76#$25#$68#$56#$74#$D3#$E8#$00#$00#$00#$01#$00#$07#$24#$8E#$00#$00#$00#$01#$00#$98#$96#$87#$00#$00#$00+
              #$00#$56#$7E#$0A#$30#$56#$7C#$B8#$B0#$00#$00#$00#$00#$00#$07#$24#$98#$00#$00#$00#$01#$00#$98#$96#$88#$00#$00#$00#$00#$56+
              #$7E#$0A#$30#$56#$7C#$B8#$B0#$00#$00#$00#$00#$00#$07#$24#$A2#$00#$00#$00#$01#$00#$98#$96#$89#$00#$00#$00#$00#$56#$7E#$0B+
              #$D4#$56#$7C#$BA#$54#$00#$00#$00#$00#$00#$07#$24#$AC#$00#$00#$00#$01#$00#$98#$96#$8A#$00#$00#$00#$00#$56#$7E#$0B#$D4#$56+
              #$7C#$BA#$54#$00#$00#$00#$00#$00#$0A#$E8#$58#$00#$00#$00#$01#$00#$98#$96#$81#$00#$00#$00#$00#$56#$7D#$9E#$60#$56#$7C#$4C+
              #$E0#$00#$00#$00#$00#$00#$0A#$E8#$62#$00#$00#$00#$01#$00#$98#$96#$82#$00#$00#$00#$00#$56#$7D#$9E#$60#$56#$7C#$4C#$E0#$00+
              #$00#$00#$00#$00#$0A#$E8#$6C#$00#$00#$00#$01#$00#$98#$96#$83#$00#$00#$00#$00#$56#$7E#$07#$9C#$56#$7C#$B6#$1C#$00#$00#$00+
              #$00#$00#$0A#$E8#$76#$00#$00#$00#$01#$00#$98#$96#$84#$00#$00#$00#$00#$56#$7E#$07#$9C#$56#$7C#$B6#$1C#$00#$00#$00#$00#$00+
              #$12#$9D#$FA#$00#$00#$00#$01#$00#$98#$98#$0F#$00#$00#$00#$01#$56#$85#$69#$24#$56#$84#$17#$A4#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$01#$18#$8C#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$4B#$00#$00#$00#$84#$00#$00#$78#$6E#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$78+
              #$78#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$15#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$15#$00#$00#$00#$00#$00+
              #$00#$78#$82#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$16#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$16#$00#$00#$00+
              #$00#$00#$00#$78#$8C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$17#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$17#$00+
              #$00#$00#$00#$00#$00#$78#$96#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$18#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$18#$00#$00#$00#$00#$00#$00#$78#$A0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$19#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$19#$00#$00#$00#$00#$00#$00#$78#$AA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1A#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$1A#$00#$00#$00#$00#$00#$00#$78#$B4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1B#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$1B#$00#$00#$00#$00#$00#$00#$78#$BE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1C#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$1C#$00#$00#$00#$00#$00#$00#$78#$C8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1D#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$1D#$00#$00#$00#$00#$00#$00#$78#$D2#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$1E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$1E#$00#$00#$00#$00#$00#$00#$78#$DC#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$1F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$1F#$00#$00#$00#$00#$00#$00#$78#$E6#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$20#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$20#$00#$00#$00#$00#$00#$00#$78#$F0#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$21#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$21#$00#$00#$00#$00#$00#$00#$78#$FA#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$22#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$22#$00#$00#$00#$00#$00#$00#$79#$04#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$23#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$23#$00#$00#$00#$00#$00#$00#$79+
              #$0E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$24#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$24#$00#$00#$00#$00#$00+
              #$00#$79#$18#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$25#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$25#$00#$00#$00+
              #$00#$00#$00#$79#$22#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$26#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$26#$00+
              #$00#$00#$00#$00#$00#$79#$2C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$28#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$28#$00#$00#$00#$00#$00#$00#$79#$36#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$2A#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$2A#$00#$00#$00#$00#$00#$00#$79#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$2C#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$2C#$00#$00#$00#$00#$00#$00#$79#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$2E#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$2E#$00#$00#$00#$00#$00#$00#$85#$C0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$30#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$85#$CA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$32#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$32#$00#$00#$00#$00#$00#$00#$85#$D4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$42#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$42#$00#$00#$00#$00#$00#$00#$85#$DE#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$44#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$44#$00#$00#$00#$00#$00#$00#$85#$E8#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$85#$F2#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$85#$FC#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$86#$06#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$86+
              #$10#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$50#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$50#$00#$00#$00#$00#$00+
              #$00#$86#$1A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$52#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$52#$00#$00#$00+
              #$00#$00#$00#$86#$24#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$56#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$56#$00+
              #$00#$00#$00#$00#$01#$45#$8C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$01#$45#$96#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$00#$00#$01#$45#$A0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$02#$00#$00#$00#$00#$00#$01#$45#$AA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$03#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$03#$00#$00#$00#$00#$00#$01#$45#$B4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$04#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$04#$00#$00#$00#$00#$00#$01#$45#$BE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$05#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$05#$00#$00#$00#$00#$00#$01#$45#$C8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$06#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$06#$00#$00#$00#$00#$00#$01#$45#$D2#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$07#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$07#$00#$00#$00#$00#$00#$01#$45#$DC#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$08#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$08#$00#$00#$00#$00#$00#$01#$45#$E6#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$09#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$09#$00#$00#$00#$00#$00#$01#$45#$F0#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$01#$45#$FA#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$01#$46+
              #$04#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0C#$00#$00#$00#$00#$00+
              #$01#$46#$0E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0D#$00#$00#$00+
              #$00#$00#$01#$46#$18#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0E#$00+
              #$00#$00#$00#$00#$01#$46#$22#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$0F#$00#$00#$00#$00#$00#$01#$46#$2C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$10#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$10#$00#$00#$00#$00#$00#$01#$46#$36#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$11#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$11#$00#$00#$00#$00#$00#$01#$46#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$12#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$12#$00#$00#$00#$00#$00#$01#$46#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$13#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$13#$00#$00#$00#$00#$00#$01#$9B#$18#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$27#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$27#$00#$00#$00#$00#$00#$01#$FF#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$29#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$29#$00#$00#$00#$00#$00#$01#$FF#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$2B#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$2B#$00#$00#$00#$00#$00#$02#$1E#$9E#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$2D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$2D#$00#$00#$00#$00#$00#$02#$29#$A2#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$2F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$2F#$00#$00#$00#$00#$00#$02#$41#$08#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$31#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$31#$00#$00#$00#$00#$00#$02#$CA#$56#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$33#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$33#$00#$00#$00#$00#$00#$02#$CA+
              #$60#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$34#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$34#$00#$00#$00#$00#$00+
              #$02#$CA#$6A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$35#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$35#$00#$00#$00+
              #$00#$00#$02#$CA#$74#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$36#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$36#$00+
              #$00#$00#$00#$00#$02#$D1#$2C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$37#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$37#$00#$00#$00#$00#$00#$02#$D1#$36#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$38#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$38#$00#$00#$00#$00#$00#$02#$D1#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$39#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$39#$00#$00#$00#$00#$00#$02#$D1#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3A#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$3A#$00#$00#$00#$00#$00#$02#$E0#$54#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3B#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$3B#$00#$00#$00#$00#$00#$02#$E0#$5E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3C#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$3C#$00#$00#$00#$00#$00#$02#$E0#$68#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$3D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$3D#$00#$00#$00#$00#$00#$02#$E0#$72#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$3E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$3E#$00#$00#$00#$00#$00#$02#$E0#$7C#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$3F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$3F#$00#$00#$00#$00#$00#$02#$E0#$86#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$40#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$40#$00#$00#$00#$00#$00#$03#$4A#$76#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$41#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$41#$00#$00#$00#$00#$00#$03#$4A#$80#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$43#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$43#$00#$00#$00#$00#$00#$03#$4A+
              #$8A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$45#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$45#$00#$00#$00#$00#$00+
              #$03#$4A#$94#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$47#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$47#$00#$00#$00+
              #$00#$00#$04#$89#$86#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$49#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$49#$00+
              #$00#$00#$00#$00#$04#$89#$90#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4B#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$4B#$00#$00#$00#$00#$00#$05#$0F#$6E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4D#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$4D#$00#$00#$00#$00#$00#$05#$0F#$78#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4E#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$4E#$00#$00#$00#$00#$00#$05#$9A#$42#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4F#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$4F#$00#$00#$00#$00#$00#$06#$E2#$3A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$51#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$51#$00#$00#$00#$00#$00#$08#$33#$1A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$53#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$53#$00#$00#$00#$00#$00#$08#$33#$24#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$54#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$54#$00#$00#$00#$00#$00#$09#$54#$66#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$55#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$55#$00#$00#$00#$00#$00#$0A#$1E#$28#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$0A#$1E#$32#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$60#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$60#$00#$00#$00#$00#$00#$0C#$55#$08#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$61#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$61#$00#$00#$00#$00#$00#$0C#$55#$12#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$62#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$62#$00#$00#$00#$00#$00#$0D#$72+
              #$94#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$63#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$63#$00#$00#$00#$00#$00+
              #$0D#$72#$9E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$64#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$64#$00#$00#$00+
              #$00#$00#$0E#$E9#$E4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$65#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$65#$00+
              #$00#$00#$00#$00#$0E#$E9#$EE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$66#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$66#$00#$00#$00#$00#$00#$0E#$E9#$F8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$67#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$67#$00#$00#$00#$00#$00#$0E#$EA#$02#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$68#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$68#$00#$00#$00#$00#$00#$0E#$EA#$0C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$6B#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$6B#$00#$00#$00#$00#$00#$0E#$EA#$16#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$6B#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$6B#$00#$00#$00#$00#$00#$0F#$85#$98#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$69#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$69#$00#$00#$00#$00#$00#$0F#$85#$A2#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$6A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6A#$00#$00#$00#$00#$00#$10#$49#$60#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$6C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6C#$00#$00#$00#$00#$00#$10#$49#$6A#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$6D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6D#$00#$00#$00#$00#$00#$10#$6A#$3A#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$6E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6E#$00#$00#$00#$00#$00#$10#$6A#$44#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$6F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6F#$00#$00#$00#$00#$00#$10#$A5#$18#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$70#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$70#$00#$00#$00#$00#$00#$10#$A5+
              #$22#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$71#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$71#$00#$00#$00#$00#$00+
              #$10#$E6#$E0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$72#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$72#$00#$00#$00+
              #$00#$00#$10#$E6#$EA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$73#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$73#$00+
              #$00#$00#$00#$00#$12#$6A#$A6#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$74#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$74#$00#$00#$00#$00#$00#$12#$6A#$B0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$75#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$75#$00#$00#$00#$00#$00#$12#$6A#$BA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$76#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$76#$00#$00#$00#$00#$00#$12#$6A#$C4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$77#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$77#$00#$00#$00#$00#$00#$12#$6A#$CE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$78#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$78#$00#$00#$00#$00#$00#$12#$6A#$D8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$79#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$79#$00#$00#$00#$00#$00#$12#$9F#$26#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$7A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7A#$00#$00#$00#$00#$00#$12#$9F#$30#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$7B#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7B#$00#$00#$00#$00#$00#$12#$9F#$3A#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$7C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7C#$00#$00#$00#$00#$00#$12#$9F#$44#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$7D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7D#$00#$00#$00#$00#$00#$12#$9F#$4E#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$7E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7E#$00#$00#$00#$00#$00#$13#$8C#$24#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$7F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7F#$00#$00#$00#$00#$00#$13#$8C+
              #$2E#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$13#$8C#$38#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$80#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$80#$00#$00#$00#$00#$00#$13#$8C#$42#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$85#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$85#$00#$00#$00#$00#$00#$13#$8C#$4C#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$81#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$81#$00#$00#$00#$00#$00#$13#$8C#$56#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$86#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$86#$00#$00#$00#$00#$00#$13#$8C#$60#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$82#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$82#$00#$00#$00#$00#$00#$13#$8C#$6A#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$87#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$87#$00#$00#$00#$00#$00#$13#$8C#$74#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$83#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$83#$00#$00#$00#$00#$00#$13#$8C+
              #$7E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$88#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$88#$00#$00#$00#$00#$00+
              #$13#$8C#$88#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$84#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$84#$00#$00#$00+
              #$00#$00#$13#$8C#$92#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$89#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$89#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0F+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$00#$0C#$74#$00#$74#$00#$65#$00#$73#$00#$74+
              #$00#$65#$00#$00#$00#$00#$02#$00#$00#$10#$F4#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$0D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$4E#$00#$00#$00#$07#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$08#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$09#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0A#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0C#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0E#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$10#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$11#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$12#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$13#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$14#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$15#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$16#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$17#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$18#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$19#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1A#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1D#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$1E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$24#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$27#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$28#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$29#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2A#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2B#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2C#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2D#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2E#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$2F#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$30#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$31#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$32#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$33#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$34#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$35#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$36#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$37#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$38#$00#$00#$00#$00+
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
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$54#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$55#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$56#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$57#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$58#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$59#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5A#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5B#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5D#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5E#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$5F#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$82#$00#$00#$00#$00+
              #$00#$00#$00#$82#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$A0#$00#$00#$00#$02#$00#$00#$00#$A0#$00#$00#$00#$00#$00#$00+
              #$00#$03#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$03+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$2C#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$84#$00#$00#$78#$6E#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$14#$00#$00#$00#$00#$00#$00#$78#$78#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$15#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$15#$00#$00#$00#$00#$00#$00#$78#$82#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$16#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$16#$00#$00#$00#$00#$00#$00#$78+
              #$8C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$17#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$17#$00#$00#$00#$00#$00+
              #$00#$78#$96#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$18#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$18#$00#$00#$00+
              #$00#$00#$00#$78#$A0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$19#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$19#$00+
              #$00#$00#$00#$00#$00#$78#$AA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$1A#$00#$00#$00#$00#$00#$00#$78#$B4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1B#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$1B#$00#$00#$00#$00#$00#$00#$78#$BE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1C#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$1C#$00#$00#$00#$00#$00#$00#$78#$C8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1D#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$1D#$00#$00#$00#$00#$00#$00#$78#$D2#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1E#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$1E#$00#$00#$00#$00#$00#$00#$78#$DC#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$1F#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$1F#$00#$00#$00#$00#$00#$00#$78#$E6#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$20#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$20#$00#$00#$00#$00#$00#$00#$78#$F0#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$21#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$21#$00#$00#$00#$00#$00#$00#$78#$FA#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$22#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$22#$00#$00#$00#$00#$00#$00#$79#$04#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$23#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$23#$00#$00#$00#$00#$00#$00#$79#$0E#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$24#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$24#$00#$00#$00#$00#$00#$00#$79#$18#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$25#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$25#$00#$00#$00#$00#$00#$00#$79+
              #$22#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$26#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$26#$00#$00#$00#$00#$00+
              #$00#$79#$2C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$28#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$28#$00#$00#$00+
              #$00#$00#$00#$79#$36#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$2A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$2A#$00+
              #$00#$00#$00#$00#$00#$79#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$2C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$2C#$00#$00#$00#$00#$00#$00#$79#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$2E#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$2E#$00#$00#$00#$00#$00#$00#$85#$C0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$30#$00#$00#$00#$00#$00#$00#$85#$CA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$32#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$32#$00#$00#$00#$00#$00#$00#$85#$D4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$42#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$42#$00#$00#$00#$00#$00#$00#$85#$DE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$44#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$44#$00#$00#$00#$00#$00#$00#$85#$E8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$46#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$46#$00#$00#$00#$00#$00#$00#$85#$F2#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$48#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$48#$00#$00#$00#$00#$00#$00#$85#$FC#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$4A#$00#$00#$00#$00#$00#$00#$86#$06#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$4C#$00#$00#$00#$00#$00#$00#$86#$10#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$50#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$50#$00#$00#$00#$00#$00#$00#$86#$1A#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$52#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$52#$00#$00#$00#$00#$00#$00#$86+
              #$24#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$56#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$56#$00#$00#$00#$00#$00+
              #$01#$45#$8C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$01#$45#$96#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$00#$00#$01#$45#$A0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$02#$00#$00#$00#$00#$00#$01#$45#$AA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$03#$00#$00#$00#$00#$00#$01#$45#$B4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$04#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$04#$00#$00#$00#$00#$00#$01#$45#$BE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$05#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$05#$00#$00#$00#$00#$00#$01#$45#$C8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$06#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$06#$00#$00#$00#$00#$00#$01#$45#$D2#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$07#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$07#$00#$00#$00#$00#$00#$01#$45#$DC#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$08#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$08#$00#$00#$00#$00#$00#$01#$45#$E6#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$09#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$09#$00#$00#$00#$00#$00#$01#$45#$F0#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0A#$00#$00#$00#$00#$00#$01#$45#$FA#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0B#$00#$00#$00#$00#$00#$01#$46#$04#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$01#$46#$0E#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0D#$00#$00#$00#$00#$00#$01#$46+
              #$18#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0E#$00#$00#$00#$00#$00+
              #$01#$46#$22#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$0F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$0F#$00#$00#$00+
              #$00#$00#$01#$46#$2C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$10#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$10#$00+
              #$00#$00#$00#$00#$01#$46#$36#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$11#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$11#$00#$00#$00#$00#$00#$01#$46#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$12#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$12#$00#$00#$00#$00#$00#$01#$46#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$13#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$13#$00#$00#$00#$00#$00#$01#$9B#$18#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$27#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$27#$00#$00#$00#$00#$00#$01#$FF#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$29#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$29#$00#$00#$00#$00#$00#$01#$FF#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$2B#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$2B#$00#$00#$00#$00#$00#$02#$1E#$9E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$2D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$2D#$00#$00#$00#$00#$00#$02#$29#$A2#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$2F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$2F#$00#$00#$00#$00#$00#$02#$41#$08#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$31#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$31#$00#$00#$00#$00#$00#$02#$CA#$56#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$33#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$33#$00#$00#$00#$00#$00#$02#$CA#$60#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$34#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$34#$00#$00#$00#$00#$00#$02#$CA#$6A#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$35#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$35#$00#$00#$00#$00#$00#$02#$CA+
              #$74#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$36#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$36#$00#$00#$00#$00#$00+
              #$02#$D1#$2C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$37#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$37#$00#$00#$00+
              #$00#$00#$02#$D1#$36#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$38#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$38#$00+
              #$00#$00#$00#$00#$02#$D1#$40#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$39#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$39#$00#$00#$00#$00#$00#$02#$D1#$4A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3A#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$3A#$00#$00#$00#$00#$00#$02#$E0#$54#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3B#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$3B#$00#$00#$00#$00#$00#$02#$E0#$5E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3C#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$3C#$00#$00#$00#$00#$00#$02#$E0#$68#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3D#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$3D#$00#$00#$00#$00#$00#$02#$E0#$72#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$3E#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$3E#$00#$00#$00#$00#$00#$02#$E0#$7C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$3F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$3F#$00#$00#$00#$00#$00#$02#$E0#$86#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$40#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$40#$00#$00#$00#$00#$00#$03#$4A#$76#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$41#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$41#$00#$00#$00#$00#$00#$03#$4A#$80#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$43#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$43#$00#$00#$00#$00#$00#$03#$4A#$8A#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$45#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$45#$00#$00#$00#$00#$00#$03#$4A#$94#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$47#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$47#$00#$00#$00#$00#$00#$04#$89+
              #$86#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$49#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$49#$00#$00#$00#$00#$00+
              #$04#$89#$90#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4B#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$4B#$00#$00#$00+
              #$00#$00#$05#$0F#$6E#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$4D#$00+
              #$00#$00#$00#$00#$05#$0F#$78#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$4E#$00#$00#$00#$00#$00#$05#$9A#$42#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$4F#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$4F#$00#$00#$00#$00#$00#$06#$E2#$3A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$51#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$51#$00#$00#$00#$00#$00#$08#$33#$1A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$53#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$53#$00#$00#$00#$00#$00#$08#$33#$24#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$54#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$54#$00#$00#$00#$00#$00#$09#$54#$66#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$55#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$55#$00#$00#$00#$00#$00#$0A#$1E#$28#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$5F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$5F#$00#$00#$00#$00#$00#$0A#$1E#$32#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$60#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$60#$00#$00#$00#$00#$00#$0C#$55#$08#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$61#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$61#$00#$00#$00#$00#$00#$0C#$55#$12#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$62#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$62#$00#$00#$00#$00#$00#$0D#$72#$94#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$63#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$63#$00#$00#$00#$00#$00#$0D#$72#$9E#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$64#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$64#$00#$00#$00#$00#$00#$0E#$E9+
              #$E4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$65#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$65#$00#$00#$00#$00#$00+
              #$0E#$E9#$EE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$66#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$66#$00#$00#$00+
              #$00#$00#$0E#$E9#$F8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$67#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$67#$00+
              #$00#$00#$00#$00#$0E#$EA#$02#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$68#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$68#$00#$00#$00#$00#$00#$0E#$EA#$0C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$6B#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$6B#$00#$00#$00#$00#$00#$0E#$EA#$16#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$6B#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$6B#$00#$00#$00#$00#$00#$0F#$85#$98#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$69#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$69#$00#$00#$00#$00#$00#$0F#$85#$A2#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$6A#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$6A#$00#$00#$00#$00#$00#$10#$49#$60#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$6C#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6C#$00#$00#$00#$00#$00#$10#$49#$6A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$6D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6D#$00#$00#$00#$00#$00#$10#$6A#$3A#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$6E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6E#$00#$00#$00#$00#$00#$10#$6A#$44#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$6F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$6F#$00#$00#$00#$00#$00#$10#$A5#$18#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$70#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$70#$00#$00#$00#$00#$00#$10#$A5#$22#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$71#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$71#$00#$00#$00#$00#$00#$10#$E6#$E0#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$72#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$72#$00#$00#$00#$00#$00#$10#$E6+
              #$EA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$73#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$73#$00#$00#$00#$00#$00+
              #$12#$6A#$A6#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$74#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$74#$00#$00#$00+
              #$00#$00#$12#$6A#$B0#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$75#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$75#$00+
              #$00#$00#$00#$00#$12#$6A#$BA#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$76#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
              #$76#$00#$00#$00#$00#$00#$12#$6A#$C4#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$77#$00#$00#$00#$00#$00#$00#$00#$01#$00+
              #$00#$00#$77#$00#$00#$00#$00#$00#$12#$6A#$CE#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$78#$00#$00#$00#$00#$00#$00#$00+
              #$01#$00#$00#$00#$78#$00#$00#$00#$00#$00#$12#$6A#$D8#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$79#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$79#$00#$00#$00#$00#$00#$12#$9F#$26#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$7A#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$7A#$00#$00#$00#$00#$00#$12#$9F#$30#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$7B#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7B#$00#$00#$00#$00#$00#$12#$9F#$3A#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$7C#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7C#$00#$00#$00#$00#$00#$12#$9F#$44#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$7D#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7D#$00#$00#$00#$00#$00#$12#$9F#$4E#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$7E#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7E#$00#$00#$00#$00#$00#$13#$8C#$24#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$7F#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$7F#$00#$00#$00#$00#$00#$13#$8C#$2E#$00#$00#$00+
              #$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$13#$8C#$38#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$80#$00#$00#$00#$00#$00+
              #$00#$00#$01#$00#$00#$00#$80#$00#$00#$00#$00#$00#$13#$8C#$42#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$85#$00#$00#$00+
              #$00#$00#$00#$00#$01#$00#$00#$00#$85#$00#$00#$00#$00#$00#$13#$8C#$4C#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$81#$00+
              #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$81#$00#$00#$00#$00#$00#$13#$8C#$56#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
              #$86#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$86#$00#$00#$00#$00#$00#$13#$8C#$60#$00#$00#$00#$01#$00#$00#$00#$01#$00+
              #$00#$00#$82#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$82#$00#$00#$00#$00#$00#$13#$8C#$6A#$00#$00#$00#$01#$00#$00#$00+
              #$01#$00#$00#$00#$87#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$87#$00#$00#$00#$00#$00#$13#$8C#$74#$00#$00#$00#$01#$00+
              #$00#$00#$01#$00#$00#$00#$83#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$83#$00#$00#$00#$00#$00#$13#$8C#$7E#$00#$00#$00+
              #$01#$00#$00#$00#$01#$00#$00#$00#$88#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$88#$00#$00#$00#$00#$00#$13#$8C#$88#$00+
              #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$84#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$84#$00#$00#$00#$00#$00#$13#$8C+
              #$92#$00#$00#$00#$01#$00#$00#$00#$01#$00#$00#$00#$89#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$89#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$0F#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$14#$00#$00#$00#$00#$00#$13#$F2#$00#$00#$00#$00#$30#$00#$06#$02#$F4#$40#$18#$09#$00#$00+
              #$00#$00#$00#$00#$00#$00#$06#$01#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$01#$00#$00#$00#$00#$01#$00#$00#$00#$00);
        Compress;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Rooms[Player.AccInfo.Room].Players[i].Player.Send;
    end;
end;

end.
