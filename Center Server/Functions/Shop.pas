unit Shop;

interface

uses DBCon, Windows;

type
  TShopGroup = record
    iStart: Integer;
    iEnd: Integer;
  end;

type
  TShop = class
    private
      MySQL: TQuery;
      Items: array of TShopGroup;
    public
      constructor Create(MySQL: TQuery);
      procedure Compile(PPlayer: Pointer);
  end;

implementation

uses GlobalDefs, Player;

constructor TShop.Create(MySQL: TQuery);
begin
  Self.MySQL:=MySQL;
  SetLength(Items,0);
  MySQL.SetQuery('SELECT START, END FROM Shop');
  MySQL.Run(1);
  while MySQL.Query.Eof = False do begin
    SetLength(Items,Length(Items)+1);
    Items[Length(Items)-1].iStart:=MySQL.Query.Fields[0].AsInteger;
    Items[Length(Items)-1].iEnd:=MySQL.Query.Fields[1].AsInteger;
    MySQL.Query.Next;
  end;
end;

procedure TShop.Compile(PPlayer: Pointer);
var
  Player: TPlayer;
  i: Integer;
begin
  Player:=TPlayer(PPlayer);
  Player.Buffer.BIn:='';
  with Player.Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_SHOPLIST));
    Write(#$00#$01); //01 mostrar apenas os itens da lista 00 mostra todos
    WriteCd(Dword(Length(Items)));
    for i:=0 to Length(Items)-1 do begin
      WriteCd(Dword(Items[i].iStart));
      WriteCd(Dword(Items[i].iEnd));
    end;
    Write(#$00#$00#$00#$00);
    Compress;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Player.Send;
end;

end.
