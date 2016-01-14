unit Shop;

interface

uses Player, Windows, Inventory, Log, System.Generics.Collections, DBCon,
     System.StrUtils, System.SysUtils, SortUS;

type
  TShopGroup = record
    iStart: Integer;
    iEnd: Integer;
  end;

type
  TShop = class
    private
      ShopItems: array of TShopGroup;
      MySQL: TQuery;
    public
      constructor Create(MySQL: TQuery);
      procedure SendUnknown1(Player: TPlayer);
      procedure SendUnknown2(Player: TPlayer);
      procedure CheckItem(Player: TPlayer);
      procedure BuyItem(Player: TPlayer);
      function Contain(ID: Integer): Boolean;
  end;

implementation

uses GlobalDefs;

constructor TShop.Create(MySQL: TQuery);
var
  Temp: TShopGroup;
begin
  Self.MySQL:=MySQL;
  MySQL.SetQuery('SELECT START, END FROM Shop');
  MySQL.Run(1);
  while MySQL.Query.Eof = False do begin
    Temp.iStart:=MySQL.Query.Fields[0].AsInteger;
    Temp.iEnd:=MySQL.Query.Fields[1].AsInteger;
    SetLength(ShopItems,Length(ShopItems)+1);
    ShopItems[Length(ShopItems)-1]:=Temp;
    MySQL.Query.Next;
  end;
end;

procedure TShop.SendUnknown1(Player: TPlayer);
begin
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_UNKNOWN_0611));
    Write(#$00#$00#$00#$0C#$00#$00#$00#$00#$00#$FF+
          #$FF#$FF#$FF#$00#$00#$00#$00);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TShop.SendUnknown2(Player: TPlayer);
begin
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_UNKNOWN_0414));
    Write(#$00#$00#$00#$08#$00#$00#$00#$00#$00#$00+
          #$00#$00#$01);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

procedure TShop.CheckItem(Player: TPlayer);
var
  ItemID: Integer;
begin
  ItemID:=Player.Buffer.RCd(8);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(667));
    Write(#$00#$00#$00#$08#$00#$00#$00#$00#$01);
    WriteCd(Dword(ItemID));
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

function TShop.Contain(ID: Integer): Boolean;
var
  i: Integer;
begin
  result:=False;
  for i:=0 to Length(ShopItems)-1 do begin
    if (ShopItems[i].iStart = ID) or (ShopItems[i].iEnd = ID) then begin
      result:=True;
      Exit;
    end
    else
      if (ID > ShopItems[i].iStart) and (ID < ShopItems[i].iEnd) then begin
        result:=True;
        Exit;
      end;
  end;
end;

procedure TShop.BuyItem(Player: TPlayer);
var
  ItemID, Quantity, i, OQuantity: DWORD;
  Item: array of TRInventory;
  TTItem, TTItem2: TItem;
begin
  logger.Write(player.Buffer.BOut,packets);
  ItemID:=Player.Buffer.RCd(8);
  Quantity:=Player.Buffer.RCd(12);
  OQuantity:=Quantity;
  if Quantity = $FFFFFFFF then
    Quantity:=1;
  if Contain(ItemID) then begin
    if Player.SortUS.Items.ContainsKey(ItemID) then begin
      Player.SortUS.Items.TryGetValue(ItemID,TTItem);
      if TTItem.CType = 0 then
        if (Player.Currency.GP - TTItem.Price * Integer(Quantity)) >= 0 then begin
          Dec(Player.Currency.GP,TTItem.Price * Integer(Quantity));
          Player.Currency.Update;
        end
        else begin
          Player.Buffer.BIn:='';
          with Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(53));
            Write(#$00#$00#$00#$0C#$00#$00#$00#$00#$02);
            WriteCd(Dword(ItemID));
            Write(#$00#$00#$00#$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Player.Send;
          Exit;
        end;
      Logger.Write(TTItem.Name+' '+inttostr(TTitem.Type1)+' '+inttostr(TTItem.Type2)+' '+inttostr(TTItem.Quantity),serverstatus);
      Quantity:=OQuantity;
      case TTItem.Type1 of
        0: begin
          if TTItem.Type2 = 0 then begin
            if Dword(TTItem.Quantity) < $FFFFFFFF then begin
              SetLength(Item,Length(Item)+1);
              Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,TTItem.Quantity,1);
            end
            else begin
              if Quantity = $FFFFFFFF then
                Quantity:=1;
              SetLength(Item,Length(Item)+1);
              Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,1);
            end;
          end
          else begin
            SetLength(Item,Length(Item)+1);
            Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
          end;
        end;
        1: begin
          for TTItem2 in Player.SortUS.Items.Values do
            if TTItem2.ID <> Integer(ItemID) then begin
              if Length(Item) = 4 then
                Break;
              if TTItem2.GoodsType = TTItem.GoodsType then begin
                SetLength(Item,Length(Item)+1);
                Item[Length(Item)-1]:=Player.Inventory.Add(TTItem2.ID,Quantity,0);
              end;
            end;
        end;
        2: begin
          SetLength(Item,Length(Item)+1);
          Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
        end;
        4: begin
          SetLength(Item,Length(Item)+1);
          Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
        end;
        8: begin
          SetLength(Item,Length(Item)+1);
          Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
        end;
        16: begin
          SetLength(Item,Length(Item)+1);
          Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
        end;
        32: begin
          SetLength(Item,Length(Item)+1);
          Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
        end;
        64: begin
          SetLength(Item,Length(Item)+1);
          Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
        end;
        128: begin
          SetLength(Item,Length(Item)+1);
          Item[Length(Item)-1]:=Player.Inventory.Add(ItemID,Quantity,0);
        end;
      end;
      Player.Buffer.BIn:='';
      with Player.Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(53));
        Write(#$00#$00#$00#$53#$00#$00#$00#$00#$00);
        WriteCd(Dword(Player.Currency.GP));
        WriteCd(Dword(Length(Item)));
        for i:=0 to Length(Item)-1 do begin
          WriteCd(Dword(Item[i].ItemID));
          Write(#$00#$00#$00#$01);
          WriteCd(Dword(Item[i].ID));
          WriteCd(Dword(Item[i].Quantity));
          Write(#$FF#$FF#$FF#$FF#$00#$00#$FF#$FF#$00#$00+
                #$FF#$FF#$FF#$FF#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                #$00#$00#$00#$00#$00);
        end;
        FixSize;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Player.Send;
    end
    else
      Logger.Write('Tentaram comprar algo fora do sort',Errors);
  end
  else
    Logger.Write('Tentaram comprar algo fora do shop',Errors);
end;

end.
