unit Loading;

interface

uses Windows, System.SysUtils, System.StrUtils;

type
  TCRCFILE = record
    nFile: AnsiString;
    CRC: AnsiString;
  end;

type
  TLoading = class
    Loading: array[1..4] of AnsiString;
    MatchLoading: array[1..3] of AnsiString;
    SquareLoading: array[1..3] of AnsiString;
    HackList: array of AnsiString;
    CheckList: array of TCRCFILE;
    GuildMark: AnsiString;
    procedure AddHack(DLLN: AnsiString);
    procedure AddCheck(nFile, CRC: AnsiString);
    procedure CompileList(PPlayer: Pointer);
    procedure CompileCheck(PPlayer: Pointer);
    destructor Destroy; override;
  end;

implementation

uses Misc, GlobalDefs, Player;

destructor TLoading.Destroy;
begin
  inherited;
end;

procedure TLoading.AddHack(DLLN: AnsiString);
begin
  SetLength(HackList,Length(HackList)+1);
  HackList[Length(HackList)-1]:=DLLN;
end;

procedure TLoading.AddCheck(nFile, CRC: AnsiString);
begin
  SetLength(CheckList,Length(CheckList)+1);
  CheckList[Length(CheckList)-1].nFile:=nFile;
  CheckList[Length(CheckList)-1].CRC:=CRC;
end;

procedure TLoading.CompileList(PPlayer: Pointer);
var
  Player: TPlayer;
  i: Integer;
begin
  Player:=TPlayer(PPlayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_LOADING));
    Write(#$00#$00#$00#$00#$00#$00#$00#$00#$05#$00+
          #$00#$00#$00#$00#$00#$00#$01#$00#$00#$00+
          #$02#$00#$00#$00#$03#$00#$00#$00#$04#$00+
          #$00#$00#$01#$00#$00#$00#$00);
    WriteCd(Dword(Length(Loading)));
    WriteCd(Dword(Length(Loading[1])*2));
    WriteZd(Loading[1]);
    WriteCd(Dword(Length(Loading[2])*2));
    WriteZd(Loading[2]);
    WriteCd(Dword(Length(Loading[3])*2));
    WriteZd(Loading[3]);
    WriteCd(Dword(Length(Loading[4])*2));
    WriteZd(Loading[4]);
    Write(#$00#$00#$00#$02#$00#$00#$00#$00#$00#$00+
          #$00#$01#$00#$00#$00#$01#$00#$00#$00#$00);
    WriteCd(Dword(Length(MatchLoading)));
    WriteCd(Dword(Length(MatchLoading[1])*2));
    WriteZd(MatchLoading[1]);
    WriteCd(Dword(Length(MatchLoading[2])*2));
    WriteZd(MatchLoading[2]);
    WriteCd(Dword(Length(MatchLoading[3])*2));
    WriteZd(MatchLoading[3]);
    Write(#$00#$00#$00#$00);
    WriteCd(Dword(Length(SquareLoading)));
    WriteCd(Dword(0));
    WriteCd(Dword(Length(SquareLoading[1])*2));
    WriteZd(SquareLoading[1]);
    WriteCd(Dword(1));
    WriteCd(Dword(Length(SquareLoading[2])*2));
    WriteZd(SquareLoading[2]);
    WriteCd(Dword(2));
    WriteCd(Dword(Length(SquareLoading[3])*2));
    WriteZd(SquareLoading[3]);
    Write(#$00#$00#$00#$03#$00#$00#$00#$00#$00#$00+
          #$00#$01#$00#$00#$00#$02#$00#$00#$00#$00);
    WriteCd(Dword(Length(HackList)));
    for i:=0 to Length(HackList)-1 do begin
      WriteCd(Dword(Length(HackList[i])*2));
      WriteZd(HackList[i]);
    end;
    Write(Byte(0));
    Compress;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TLoading.CompileCheck(PPlayer: Pointer);
var
  Player: TPlayer;
  i: Integer;
begin
  Player:=TPlayer(PPlayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_REQUEST_CHECK));
    Write(#$00#$00#$00#$00#$00);
    WriteCd(Dword(Length(CheckList)));
    for i:=0 to Length(CheckList)-1 do begin
      WriteCd(Dword(Length(CheckList[i].nFile)*2));
      WriteZd(CheckList[i].nFile);
    end;
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

end.
