unit CryptLib;

interface

uses Windows, System.ZLib, System.Classes, System.Variants, System.DateUtils,
     System.StrUtils;

type

  TEncrypt = function(Data, IV: AnsiString; Rnd: Byte): AnsiString; stdcall;
  TDecrypt = function(Data, IV: AnsiString): AnsiString; stdcall;
  TGenerateIV = function(IVHash: AnsiString; IVType: DWORD): AnsiString; stdcall;
  TClearPacket = function(Data, IV2: AnsiString): AnsiString; stdcall;

  TCryptLib = class
    private
      hInst: THandle;
      _Encrypt: TEncrypt;
      _Decrypt: TDecrypt;
      _GenerateIV: TGenerateIV;
      _ClearPacket: TClearPacket;
    public
      BIn: AnsiString;
      BOut: AnsiString;
      BTotal: AnsiString;
      IV: AnsiString;
      IV2: AnsiString;
      Prefix: AnsiString;
      Count: Integer;
      procedure Encrypt(IV: AnsiString; Rnd: Byte);
      procedure Decrypt(IV: AnsiString);
      function GenerateIV(IVType: DWORD): AnsiString;
      procedure ClearPacket;
      procedure Compress;
      procedure Decompress;
      procedure FixSize;
      procedure Write(value: Variant);
      procedure WriteZd(value: AnsiString);
      procedure WriteCw(value: Word);
      procedure WriteCd(value: Dword);
      function RD(Index: Integer): Dword;
      function RW(Index: Integer): Word;
      function RCw(Index: Integer): Word;
      function RCd(Index: Integer): Dword;
      function RB(Index: Integer): Byte;
      function RBo(Index: Integer): Boolean;
      function RS(Index, Size: Integer): Ansistring; overload;
      function RS(Index, Size: Integer; Fill: AnsiChar): Ansistring; reintroduce; overload;
      constructor Create;
      destructor Destroy; override;
  end;

implementation

procedure TCryptLib.Encrypt(IV: AnsiString; Rnd: Byte);
var
  Temp: AnsiString;
begin
  Temp:=Copy(BIn,1,6);
  Delete(BIn,1,6);
  BIn:=Temp+_Encrypt(BIn,IV,Rnd);
end;

procedure TCryptLib.Decrypt(IV: AnsiString);
begin
  BOut:=_Decrypt(BOut,IV);
end;

function TCryptLib.GenerateIV(IVType: DWORD): AnsiString;
begin
  Result:=_GenerateIV(IV,IVType);
end;

procedure TCryptLib.ClearPacket;
begin
  BIn:=_ClearPacket(BIn,IV2);
end;

procedure TCryptLib.Compress;
var
  strInput, strOutput: TStringStream;
  Zipper: TZCompressionStream;
  Part: AnsiString;
  BSize: Integer;
begin
  Part:=Copy(BIn,10,Length(BIn));
  BSize:=Length(Part);
  strInput:=TStringStream.Create(Part);
  strOutput:=TStringStream.Create;
  try
    Zipper:=TZCompressionStream.Create(clFastest, strOutput);
    try
      Zipper.CopyFrom(strInput, strInput.Size);
    finally
      Zipper.Free;
    end;
    Part:=AnsiString(strOutput.DataString);
    BIn:=Copy(BIn,1,9);
    Write(#$00);
    WriteCw(Length(Part)+4);
    Write(#$01);
    Write(Dword(BSize));
    Write(Part);
  finally
    strInput.Free;
    strOutput.Free;
  end;
end;

procedure TCryptLib.Decompress;
var
  strInput, strOutput: TStringStream;
  Unzipper: TZDecompressionStream;
  Part1: AnsiString;
begin
  Part1:=Copy(BOut,1,11);
  BOut:=Copy(BOut,12,Length(BOut));
  strInput:=TStringStream.Create(BOut);
  strOutput:=TStringStream.Create;
  try
    Unzipper:=TZDecompressionStream.Create(strInput);
    try
      strOutput.CopyFrom(Unzipper, Unzipper.Size);
    finally
      Unzipper.Free;
    end;
    BOut:=Part1+AnsiString(strOutput.DataString);
  finally
    strInput.Free;
    strOutput.Free;
  end;
end;

procedure TCryptLib.FixSize;
begin
  BIn[11]:=AnsiChar(WORD((Length(BIn)-12) shr 8));
  BIn[12]:=AnsiChar(WORD(Length(BIn)-12));
end;

procedure TCryptLib.Write(value: Variant);
var
  bType: Integer;
  Year, Month, Day, Hour, Min, Sec, Mili: Word;
  Temp: DWORD;
begin
  bType:=VarType(value) and VarTypeMask;
  case bType of
    varLongWord:
      begin
        Temp:=value;
        BIn:=BIn+AnsiChar(Temp);
        BIn:=BIn+AnsiChar(Temp shr 8);
        BIn:=BIn+AnsiChar(Temp shr 16);
        BIn:=BIn+AnsiChar(Temp shr 24);
      end;
    varWord:
      begin
        BIn:=BIn+AnsiChar(WORD(value));
        BIn:=BIn+AnsiChar(WORD(value) shr 8);
      end;
    varDate:
      begin
        DecodeDateTime(TDateTime(value),Year,Month,Day,Hour,Min,Sec,Mili);
        Write(Word(Year));
        Write(Dword(Month));
        Write(Word(Day));
        Write(Word(Hour));
        Write(Word(Min));
        Write(Word(Sec));
        Write(Word(Mili));
      end;
    varByte:
      BIn:=BIn+AnsiChar(Byte(value));
    varBoolean:
      BIn:=BIn+AnsiChar(Byte(value));
    varString:
      BIn:=BIn+AnsiString(value);
    varUString:
      BIn:=BIn+AnsiString(value);
  end;
end;

procedure TCryptLib.WriteZd(value: AnsiString);
var
  i: Integer;
begin
  for i:=1 to Length(value) do
    BIn:=BIn+value[i]+#$00;
end;

procedure TCryptLib.WriteCw(value: Word);
var
  Temp: AnsiString;
begin
  SetLength(Temp,2);
  CopyMemory(@Temp[1],@value,2);
  BIn:=BIn+AnsiString(ReverseString(String(Temp)));
end;

procedure TCryptLib.WriteCd(value: Dword);
var
  Temp: AnsiString;
begin
  SetLength(Temp,4);
  CopyMemory(@Temp[1],@value,4);
  BIn:=BIn+AnsiString(ReverseString(String(Temp)));
end;

function TCryptLib.RD(Index: Integer): Dword;
begin
  result:=Ord(BOut[Index])+(Ord(BOut[Index+1]) shl 8)+(Ord(BOut[Index+2]) shl 16)+(Ord(BOut[Index+3]) shl 24);
end;

function TCryptLib.RW(Index: Integer): Word;
begin
  result:=Ord(BOut[Index])+(Ord(BOut[Index+1]) shl 8);
end;

function TCryptLib.RCw(Index: Integer): Word;
var
  Temp: AnsiString;
begin
  Temp:=AnsiString(AnsiReverseString(String(Copy(BOut,Index,2))));
  Move(Temp[1],result,2);
end;

function TCryptLib.RCd(Index: Integer): Dword;
var
  Temp: AnsiString;
begin
  Temp:=AnsiString(AnsiReverseString(String(Copy(BOut,Index,4))));
  Move(Temp[1],result,4);
end;

function TCryptLib.RB(Index: Integer): Byte;
begin
  result:=Ord(BOut[Index]);
end;

function TCryptLib.RBo(Index: Integer): Boolean;
begin
  if RB(Index) = 0 then
    result:=False
  else
    result:=True;
end;

function TCryptLib.RS(Index, Size: Integer): Ansistring;
var
  i: Integer;
  Temp, Temp2: AnsiString;
begin
  Temp:=Copy(BOut,Index,Size);
  for i:=1 to Length(Temp) do
    if Temp[i] <> #$00 then
      Temp2:=Temp2+Temp[i];
  result:=Temp2;
end;

function TCryptLib.RS(Index, Size: Integer; Fill: AnsiChar): Ansistring;
var
  x: Integer;
  Temp: AnsiString;
begin
  Temp:='';
  for x:=Index to Size do
    if BOut[x]=Fill then
      Break
    else begin
      Temp:=Temp+BOut[x];
    end;
  result:=temp;
end;

constructor TCryptLib.Create;
begin
  hInst:=LoadLibrary(PChar('GCDLL.dll'));
  if hInst = 0 then
    Exit;
  _Encrypt:=GetProcAddress(hInst, '_Encrypt');
  if @_Encrypt = nil then
    Exit;
  _Decrypt:=GetProcAddress(hInst, '_Decrypt');
  if @_Decrypt = nil then
    Exit;
  _GenerateIV:=GetProcAddress(hInst, '_GenerateIV');
  if @_GenerateIV = nil then
    Exit;
  _ClearPacket:=GetProcAddress(hInst, '_ClearPacket');
  if @_ClearPacket = nil then
    Exit;
end;

destructor TCryptLib.Destroy;
begin
  FreeLibrary(hInst);
  inherited;
end;

end.
