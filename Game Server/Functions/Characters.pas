unit Characters;

interface

uses DBCon, AccountInfo, System.SysUtils, Data.DB, Windows;

type
  TEquips = record
    ID: Integer;
    ItemID: Integer;
  end;

type
  TCharacter = record
    CharID: Integer;
    Promotion: Integer;
    EXP: Integer;
    Level: Integer;
    SWeapon: Boolean;
    SWeaponID: Integer;
    Pet: Integer;
    Equips: array of TEquips;
  end;

type
  TCharacters = class
    private
      MySQL: TQuery;
      AccInfo: TAccountInfo;
    public
      Chars: array of TCharacter;
      constructor Create(MySQL: TQuery; AccInfo: TAccountInfo);
      function isChar(ID: Integer): Boolean;
      procedure SendSWeaponStatus(PPlayer: Pointer);
      procedure EnableSWeapon(PPlayer: Pointer);
  end;

implementation

uses Player, GlobalDefs, Inventory;

constructor TCharacters.Create(MySQL: TQuery; AccInfo: TAccountInfo);
begin
  Self.MySQL:=MySQL;
  Self.AccInfo:=AccInfo;
  MySQL.SetQuery('SELECT CHARID, PROMOTION, EXP, LEVEL, SWEAPON, SWEAPONID, PET FROM Characters WHERE ID = :ID ORDER BY CHARID ASC');
  MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then
    while MySQL.Query.Eof = False do begin
      SetLength(Chars,Length(Chars)+1);
      Chars[Length(Chars)-1].CharID:=MySQL.Query.Fields[0].AsInteger;
      Chars[Length(Chars)-1].Promotion:=MySQL.Query.Fields[1].AsInteger;
      Chars[Length(Chars)-1].EXP:=MySQL.Query.Fields[2].AsInteger;
      Chars[Length(Chars)-1].Level:=MySQL.Query.Fields[3].AsInteger;
      Chars[Length(Chars)-1].SWeapon:=Boolean(MySQL.Query.Fields[4].AsInteger);
      Chars[Length(Chars)-1].SWeaponID:=MySQL.Query.Fields[5].AsInteger;
      Chars[Length(Chars)-1].Pet:=MySQL.Query.Fields[6].AsInteger;

      if MySQL.Query.Fields[0].AsInteger = 1 then begin
        SetLength(Chars[Length(Chars)-1].Equips,15);
        Chars[Length(Chars)-1].Equips[0].ID:=609;
        Chars[Length(Chars)-1].Equips[0].ItemID:=391330;

        Chars[Length(Chars)-1].Equips[1].ID:=610;
        Chars[Length(Chars)-1].Equips[1].ItemID:=391310;

        Chars[Length(Chars)-1].Equips[2].ID:=611;
        Chars[Length(Chars)-1].Equips[2].ItemID:=391300;

        Chars[Length(Chars)-1].Equips[3].ID:=612;
        Chars[Length(Chars)-1].Equips[3].ItemID:=391290;

        Chars[Length(Chars)-1].Equips[4].ID:=613;
        Chars[Length(Chars)-1].Equips[4].ItemID:=391340;

        Chars[Length(Chars)-1].Equips[5].ID:=614;
        Chars[Length(Chars)-1].Equips[5].ItemID:=418900;

        Chars[Length(Chars)-1].Equips[6].ID:=619;
        Chars[Length(Chars)-1].Equips[6].ItemID:=391320;

        Chars[Length(Chars)-1].Equips[7].ID:=620;
        Chars[Length(Chars)-1].Equips[7].ItemID:=501310;

        Chars[Length(Chars)-1].Equips[8].ID:=621;
        Chars[Length(Chars)-1].Equips[8].ItemID:=501350;

        Chars[Length(Chars)-1].Equips[9].ID:=622;
        Chars[Length(Chars)-1].Equips[9].ItemID:=501340;

        Chars[Length(Chars)-1].Equips[10].ID:=623;
        Chars[Length(Chars)-1].Equips[10].ItemID:=501330;

        Chars[Length(Chars)-1].Equips[11].ID:=624;
        Chars[Length(Chars)-1].Equips[11].ItemID:=501320;

        Chars[Length(Chars)-1].Equips[12].ID:=626;
        Chars[Length(Chars)-1].Equips[12].ItemID:=9860;

        Chars[Length(Chars)-1].Equips[13].ID:=627;
        Chars[Length(Chars)-1].Equips[13].ItemID:=9080;

        Chars[Length(Chars)-1].Equips[13].ID:=629;
        Chars[Length(Chars)-1].Equips[13].ItemID:=150490;
      end;


      MySQL.Query.Next;
    end;
end;

function TCharacters.isChar(ID: Integer): Boolean;
var
  i: Integer;
begin
  Result:=False;
  for i:=0 to Length(Chars)-1 do
    if Chars[i].CharID = ID then begin
      Result:=True;
      Break;
    end;
end;

procedure TCharacters.SendSWeaponStatus(PPlayer: Pointer);
var
  Player: TPlayer;
  i: Integer;
begin
  Player:=TPlayer(PPlayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_SWEAPONSTATUS));
    Write(#$00#$00#$00#$00#$00);
    WriteCd(Dword(Length(Chars)));
    for i:=0 to Length(Chars)-1 do begin
      Write(Byte(Chars[i].CharID));
      Write(Chars[i].SWeapon);
      if Chars[i].SWeaponID > 0 then
        WriteCd(Dword(1))
      else
        WriteCd(Dword(0));
      WriteCd(Dword(Chars[i].SWeaponID));
    end;
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TCharacters.EnableSWeapon(PPlayer: Pointer);
var
  Player: TPlayer;
  Char, i: Integer;
  Temp: TRInventory;
begin
  Player:=TPlayer(PPlayer);
  Char:=Player.Buffer.RB(8);
  for i:=0 to Length(Chars)-1 do
    if Chars[i].CharID = Char then begin
      if (Chars[i].SWeapon = False) and (Chars[i].Level >= 45) then
        if Player.Inventory.ContainiID(525490).ID > 0 then begin
          Chars[i].SWeapon:=True;
          MySQL.SetQuery('UPDATE CHARACTERS SET SWEAPON = 1 WHERE ID = :ID AND CHARID = :CHARID');
          MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
          MySQL.AddParameter('CHARID',AnsiString(IntToStr(Chars[i].CharID)));
          MySQL.Run(2);
          Temp:=Player.Inventory.RemoveiID(525490,1);
          Player.Buffer.BIn:='';
          with Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_ENABLESWEAPON));
            Write(#$00#$00#$00#$00#$00#$00#$00#$00);
            WriteCw(Word(Chars[i].CharID));
            Write(#$00#$00#$00#$01);
            WriteCd(Dword(Temp.ItemID));
            Write(#$00#$00#$00#$01);
            WriteCd(Dword(Temp.ID));
            WriteCd(Dword(Temp.Quantity));
            WriteCd(Dword(Temp.Quantity+1));
            Write(#$00#$02#$00#$00#$00#$00#$FF#$FF#$FF#$FF+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$FF#$00#$00#$00#$00#$00#$00#$00+
                  #$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Player.Send;
        end;
      Break;
    end;
end;

end.
