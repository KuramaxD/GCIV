unit Misc;

interface

uses System.SysUtils, System.Math;

function StringToHex(Data: AnsiString): AnsiString;
function Space(Data: AnsiString): AnsiString;
function GerarCode: AnsiString;

implementation

function StringToHex(Data: AnsiString): AnsiString;
var
  i, i2: Integer;
  s: AnsiString;
begin
  i2:=1;
  for i:=1 to Length(Data) do begin
    Inc(i2);
    if i2 = 2 then begin
      s :=s+'';
      i2:=1;
    end;
    s:=s+AnsiString(IntToHex(Ord(Data[i]),2));
  end;
  result:=s;
end;

function Space(Data: AnsiString): AnsiString;
var
  i: Integer;
begin
  i:=3;
  result:=Copy(Data,0,2);
  while i <= Length(Data) do begin
    result:=result+' '+Copy(Data,i,2);
    i:=i+2;
  end;
end;

function GerarCode: AnsiString;
var
  x, y: Integer;
  Temp, Code: AnsiString;
begin
  Temp:='abcdefghijklmnopqrstuvzywxABCDEFGHIJKLMNOPQRSTUVIYWZ1234567890';
  for y:=1 to 8 do begin
    x:=RandomRange(1,Length(Temp));
    Code:=Code + AnsiChar(Temp[x]);
  end;
  result:=Code;
end;

end.
