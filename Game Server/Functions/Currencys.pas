unit Currencys;

interface

uses DBCon, AccountInfo, System.SysUtils, Data.DB, Windows;

type
  TCurrency = class
    private
      MySQL: TQuery;
      AccInfo: TAccountInfo;
    public
      GP: Integer;
      VP: Integer;
      DPoints: Integer;
      constructor Create(MySQL: TQuery; AccInfo: TAccountInfo);
      procedure SendVP(PPlayer: Pointer);
      procedure Update;
  end;

implementation

uses Player, GlobalDefs;

constructor TCurrency.Create(MySQL: TQuery; AccInfo: TAccountInfo);
begin
  Self.AccInfo:=AccInfo;
  Self.MySQL:=MySQL;
  MySQL.SetQuery('SELECT GP, VP, DPOINTS FROM Users WHERE ID = :ID');
  MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then begin
    GP:=MySQL.Query.Fields[0].AsInteger;
    VP:=MySQL.Query.Fields[1].AsInteger;
    DPoints:=MySQL.Query.Fields[2].AsInteger;
  end;
end;

procedure TCurrency.SendVP(PPlayer: Pointer);
var
  Player: TPlayer;
begin
  Player:=TPlayer(PPLayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_SENDVP));
    Write(#$00#$00#$00#$04#$00);
    WriteCd(VP);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
    end;
  Player.Send;
end;

procedure TCurrency.Update;
begin
  MySQL.SetQuery('UPDATE Users SET GP = :GP, VP = :VP, DPOINTS = :DPOINTS WHERE ID = :ID');
  MySQL.AddParameter('GP',AnsiString(IntToStr(GP)));
  MySQL.AddParameter('VP',AnsiString(IntToStr(VP)));
  MySQL.AddParameter('DPoints',AnsiString(IntToStr(DPoints)));
  MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
  MySQL.Run(2);
end;

end.
