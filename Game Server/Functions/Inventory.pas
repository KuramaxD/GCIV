unit Inventory;

interface

uses DBCon, AccountInfo, System.SysUtils, Data.DB, Windows, Log;

type
  TRInventory = record
    ID: Integer;
    ItemID: Integer;
    Quantity: Integer;
  end;

type
  TInventory = class
    private
      MySQL: TQuery;
      AccInfo: TAccountInfo;
    public
      Inventory: array of TRInventory;
      constructor Create(MySQL: TQuery; AccInfo: TAccountInfo);
      procedure Compile(PPlayer: Pointer);
      function ContainiID(ID: Integer): TRInventory;
      function ContainID(ID: Integer): TRInventory;
      function Add(Item: Integer; Quantity, Pack: Dword): TRInventory;
      procedure SendPreUpgrade(PPlayer: Pointer);
      procedure Upgrade(PPlayer: Pointer);
      function RemoveiID(ID: Integer; Quantity: Integer): TRInventory;
      function RemoveID(ID: Integer; Quantity: Integer): TRInventory;
  end;

implementation

uses Player, GlobalDefs;

constructor TInventory.Create(MySQL: TQuery; AccInfo: TAccountInfo);
begin
  Self.AccInfo:=AccInfo;
  Self.MySQL:=MySQL;
  MySQL.SetQuery('SELECT ID, ITEMID, QUANTITY FROM Inventory WHERE UID = :ID');
  MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then
    while MySQL.Query.Eof = False do begin
      SetLength(Inventory,Length(Inventory)+1);
      Inventory[Length(Inventory)-1].ID:=MySQL.Query.Fields[0].AsInteger;
      Inventory[Length(Inventory)-1].ItemID:=MySQL.Query.Fields[1].AsInteger;
      Inventory[Length(Inventory)-1].Quantity:=MySQL.Query.Fields[2].AsInteger;
      MySQL.Query.Next;
    end;
end;

procedure TInventory.Compile(PPlayer: Pointer);
var
  Player: TPlayer;
  i: Integer;
begin
  Player:=TPlayer(PPlayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_INVENTORY));
    Write(#$00#$00#$00#$00#$01#$00#$00#$00#$01);
    WriteCd(Dword(Length(Inventory)));
    for i:=0 to Length(Inventory)-1 do begin
      WriteCd(Dword(Inventory[i].ItemID));
      Write(#$00#$00#$00#$01);
      WriteCd(Dword(Inventory[i].ID));
      WriteCd(Dword(Inventory[i].Quantity));
      WriteCd(Dword(Inventory[i].Quantity));
      Write(#$00#$00#$00#$00#$00#$00#$FF#$FF#$FF#$FF+
            #$00#$00#$00#$00#$56#$76#$0D#$AA#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00);
    end;
    Compress;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

function TInventory.ContainiID(ID: Integer): TRInventory;
var
  i: Integer;
begin
  result.ID:=-1;
  for i:=0 to Length(Inventory)-1 do
    if Inventory[i].ItemID = ID then begin
      result:=Inventory[i];
      Exit;
    end;
end;

function TInventory.ContainID(ID: Integer): TRInventory;
var
  i: Integer;
begin
  result.ID:=-1;
  for i:=0 to Length(Inventory)-1 do
    if Inventory[i].ID = ID then begin
      result:=Inventory[i];
      Exit;
    end;
end;

function TInventory.Add(Item: Integer; Quantity, Pack: Dword): TRInventory;
var
  TTemp: TRInventory;
  i: Integer;
begin
  if Pack = 0 then begin
    MySQL.SetQuery('INSERT INTO Inventory (UID, ITEMID, QUANTITY) VALUES (:ID, :ItemID, :Quantity)');
    MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
    MySQL.AddParameter('ItemID',AnsiString(IntToStr(Item)));
    MySQL.AddParameter('Quantity',AnsiString(IntToStr(Quantity)));
    MySQL.Run(2);
    MySQL.SetQuery('SELECT LAST_INSERT_ID()');
    MySQL.Run(1);
    if MySQL.Query.IsEmpty = False then begin
      SetLength(Inventory,Length(Inventory)+1);
      Inventory[Length(Inventory)-1].ID:=MySQL.Query.Fields[0].AsInteger;
      Inventory[Length(Inventory)-1].ItemID:=Item;
      Inventory[Length(Inventory)-1].Quantity:=Quantity;
      result:=Inventory[Length(Inventory)-1];
    end;
  end
  else begin
    TTemp:=ContainiID(Item);
    if TTemp.ID > -1 then begin
      if Dword(TTemp.Quantity) = $FFFFFFFF then
        Quantity:=Quantity+1
      else
        Quantity:=Quantity+Dword(TTemp.Quantity);
      MySQL.SetQuery('UPDATE Inventory SET QUANTITY = :QUANTITY WHERE ID = :ID AND UID = :UID');
      MySQL.AddParameter('QUANTITY',AnsiString(IntToStr(Quantity)));
      MySQL.AddParameter('ID',AnsiString(IntToStr(TTemp.ID)));
      MySQL.AddParameter('UID',AnsiString(IntToStr(AccInfo.ID)));
      MySQL.Run(2);
      for i:=0 to Length(Inventory)-1 do
        if Inventory[i].ID = TTemp.ID then begin
          Inventory[i].Quantity:=Quantity;
          result:=Inventory[i];
          Break;
        end;
    end
    else begin
      MySQL.SetQuery('INSERT INTO Inventory (UID, ITEMID, QUANTITY) VALUES (:ID, :ItemID, :Quantity)');
      MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
      MySQL.AddParameter('ItemID',AnsiString(IntToStr(Item)));
      MySQL.AddParameter('Quantity',AnsiString(IntToStr(Quantity)));
      MySQL.Run(2);
      MySQL.SetQuery('SELECT LAST_INSERT_ID()');
      MySQL.Run(1);
      if MySQL.Query.IsEmpty = False then begin
        SetLength(Inventory,Length(Inventory)+1);
        Inventory[Length(Inventory)-1].ID:=MySQL.Query.Fields[0].AsInteger;
        Inventory[Length(Inventory)-1].ItemID:=Item;
        Inventory[Length(Inventory)-1].Quantity:=Quantity;
        result:=Inventory[Length(Inventory)-1];
      end;
    end;
  end;
end;

procedure TInventory.SendPreUpgrade(PPlayer: Pointer);
var
  Player: TPlayer;
begin
  Player:=TPlayer(PPlayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(186));
    Write(#$00#$00#$00#$4C#$00#$00#$00#$00#$09#$00+
          #$00#$00#$01#$00#$00#$00#$01#$00#$00#$00+
          #$02#$00#$00#$00#$02#$00#$00#$00#$03#$00+
          #$00#$00#$02#$00#$00#$00#$04#$00#$00#$00+
          #$02#$00#$00#$00#$05#$00#$00#$00#$02#$00+
          #$00#$00#$06#$00#$00#$00#$03#$00#$00#$00+
          #$07#$00#$00#$00#$03#$00#$00#$00#$08#$00+
          #$00#$00#$03#$00#$00#$00#$09#$00#$00#$00+
          #$03);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TInventory.Upgrade(PPlayer: Pointer);
var
  Player: TPlayer;
begin
  Player:=TPlayer(PPlayer);
  Logger.Write(player.Buffer.BOut,packets);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(49));
    Write(#$00#$00#$00#$E1#$00#$00#$00#$00#$00#$00+
          #$00#$00#$02);
    WriteCd(Dword(8990));
    Write(#$00#$00#$00#$01);
    WriteCd(Dword(571));
    Write(#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$00#$00+
          #$FF#$FF#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00);
    WriteCd(Dword(8880));
    Write(#$00#$00#$00#$01);
    WriteCd(Dword(583));
    Write(#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$00#$00+
          #$FF#$FF#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$01);
    WriteCd(Dword(8980));
    Write(#$00#$00#$00#$01);
    WriteCd(Dword(583));
    Write(#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$00#$00+
          #$FF#$FF#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
          #$00#$00#$00#$00#$00#$00#$00#$00#$00);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

function TInventory.RemoveiID(ID: Integer; Quantity: Integer): TRInventory;
var
  i, Index: Integer;
  ALength: Cardinal;
begin
  Index:=-1;
  for i:=0 to Length(Inventory)-1 do
    if Inventory[i].ItemID = ID then begin
      if ((Inventory[i].Quantity-Quantity) > 1) and (DWORD(Inventory[i].Quantity) <> $FFFFFFFF) then begin
        Dec(Inventory[i].Quantity);
        MySQL.SetQuery('UPDATE INVENTORY SET QUANTITY = :QUANTITY WHERE ID = :ID');
        MySQL.AddParameter('QUANTITY',AnsiString(IntToStr(Inventory[i].Quantity)));
        MySQL.AddParameter('ID',AnsiString(IntToStr(Inventory[i].ID)));
        MySQL.Run(2);
        Result:=Inventory[i];
      end
      else begin
        MySQL.SetQuery('DELETE FROM INVENTORY WHERE ID = :ID');
        MySQL.AddParameter('ID',AnsiString(IntToStr(Inventory[i].ID)));
        MySQL.Run(2);
        Index:=i;
        Inventory[i].Quantity:=0;
        Result:=Inventory[i];
      end;
      Break;
    end;
  if Index > -1 then begin
    ALength:=Length(Inventory);
    Assert(ALength > 0);
    Assert(DWORD(Index) < ALength);
    for i:=Index+1 to ALength-1 do
      Inventory[i-1]:=Inventory[i];
    SetLength(Inventory,ALength-1);
  end;
end;

function TInventory.RemoveID(ID: Integer; Quantity: Integer): TRInventory;
var
  i, Index: Integer;
  ALength: Cardinal;
begin
  Index:=-1;
  for i:=0 to Length(Inventory)-1 do
    if Inventory[i].ID = ID then begin
      if ((Inventory[i].Quantity-Quantity) > 1) and (DWORD(Inventory[i].Quantity) <> $FFFFFFFF) then begin
        Dec(Inventory[i].Quantity);
        MySQL.SetQuery('UPDATE INVENTORY SET QUANTITY = :QUANTITY WHERE ID = :ID');
        MySQL.AddParameter('QUANTITY',AnsiString(IntToStr(Inventory[i].Quantity)));
        MySQL.AddParameter('ID',AnsiString(IntToStr(Inventory[i].ID)));
        MySQL.Run(2);
        Result:=Inventory[i];
      end
      else begin
        MySQL.SetQuery('DELETE FROM INVENTORY WHERE ID = :ID');
        MySQL.AddParameter('ID',AnsiString(IntToStr(Inventory[i].ID)));
        MySQL.Run(2);
        Index:=i;
        Inventory[i].Quantity:=0;
        Result:=Inventory[i];
      end;
      Break;
    end;
  if Index > -1 then begin
    ALength:=Length(Inventory);
    Assert(ALength > 0);
    Assert(DWORD(Index) < ALength);
    for i:=Index+1 to ALength-1 do
      Inventory[i-1]:=Inventory[i];
    SetLength(Inventory,ALength-1);
  end;
end;

end.
