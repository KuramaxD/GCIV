unit SortUS;

interface

uses System.Generics.Collections, System.SysUtils, System.Classes, System.StrUtils;

type
  TItem = record
    ID: Integer;
    Name: AnsiString;
    Type1: Byte;
    Type2: Byte;
    CType: Byte;
    Price: Integer;
    GoodsType: Integer;
    Quantity: Integer;
    Food: Integer;
    Atk: Integer;
  end;

{
  Type1 =
    00 - Acessório
    01 - Pacote
    02 - Elmo
    04 - Cota
    08 - Calça
    16 - Luvas
    32 - Botas
    64 - Capa
    128 - Arma

  Type2 =
    01 - Diadema
    02 - Máscara
    04 - Colar
    08 - Asas
    16 - Facas
    32 - Escudos
    64 - Anéis
    128 - Tornozeleira

  CType =
    00 - GP
    01 - CASH
    02 - Cristal
    03 - Gema
}

type
  TSortUS = class
    Loaded: Boolean;
    Items: TDictionary<Integer, TItem>;
    constructor Create(Path: AnsiString);
  end;

implementation

constructor TSortUS.Create(Path: AnsiString);
var
  Stream: TMemoryStream;
  Temp, NTemp, TTemp: AnsiString;
  iStart, i, TID: Integer;
  TempItem: TItem;
begin
  Loaded:=False;
  if FileExists(String(Path)) then begin
    Items:=TDictionary<Integer, TItem>.Create;
    Stream:=TMemoryStream.Create;
    Stream.LoadFromFile(String(Path));
    SetString(Temp, PAnsiChar(Stream.Memory), Stream.Size);
    Stream.Free;
    iStart:=9;
    while iStart < Length(Temp)-8 do begin
      TTemp:=Copy(Temp,iStart+4,100);
      NTemp:='';
      for i:=0 to Length(TTemp) do
        if (TTemp[i] = #$00) and (TTemp[i+1] = #$00) then
          Break
        else
          if TTemp[i] <> #$00 then
            NTemp:=NTemp+TTemp[i];
      TTemp:=Copy(Temp,IStart,4);
      Move(TTemp[1],TID,4);
      TempItem.ID:=TID;
      TempItem.Name:=NTemp;
      TempItem.Type1:=Ord(Temp[iStart+528]);
      TempItem.Type2:=Ord(Temp[iStart+529]);
      TempItem.CType:=Ord(Temp[iStart+810]);
      TTemp:=Copy(Temp,IStart+814,4);
      Move(TTemp[1],TempItem.Price,4);
      TTemp:=Copy(Temp,IStart+524,4);
      Move(TTemp[1],TempItem.GoodsType,4);
      TTemp:=Copy(Temp,IStart+548,4);
      Move(TTemp[1],TempItem.Quantity,4);
      TTemp:=Copy(Temp,IStart+918,4);
      Move(TTemp[1],TempItem.Food,4);
      TTemp:=Copy(Temp,IStart+922,4);
      Move(TTemp[1],TempItem.Atk,4);
      if not items.ContainsKey(TID) then
        Items.Add(TID,TempItem);
      Inc(iStart,935);
    end;
    Loaded:=True;
  end;
end;

end.
