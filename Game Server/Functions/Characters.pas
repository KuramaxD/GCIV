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
  var i: Integer;
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
      MySQL.Query.Next;
    end;
  // Define itens equipados
  begin
    MySQL.SetQuery('SELECT ITEMUID, ITEMID, CHARTYPE FROM EQUIPITEM WHERE UID = :ID ORDER BY CHARTYPE ASC');
    MySQL.AddParameter('ID', AnsiString(IntToStr(AccInfo.ID)));
    MySQL.Run(1);
    if MySQL.Query.IsEmpty = False then
      while MySQL.Query.Eof = False do begin
        i:=MySQL.Query.Fields[2].AsInteger;
        SetLength(Chars[i].Equips, Length(Chars[i].Equips)+1);
        Chars[i].Equips[Length(Chars[i].Equips)-1].ID:=MySQL.Query.Fields[0].AsInteger;
        Chars[i].Equips[Length(Chars[i].Equips)-1].ItemID:=MySQL.Query.Fields[1].AsInteger;
        MySQL.Query.Next;
      end;
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
