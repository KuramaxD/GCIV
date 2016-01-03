unit Characters;

interface

uses DBCon, AccountInfo, System.SysUtils, Data.DB;

type
  TCharacter = record
    CharID: Integer;
    Promotion: Integer;
    EXP: Integer;
    Level: Integer;
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
  end;

implementation

constructor TCharacters.Create(MySQL: TQuery; AccInfo: TAccountInfo);
begin
  Self.MySQL:=MySQL;
  Self.AccInfo:=AccInfo;
  MySQL.SetQuery('SELECT CHARID, PROMOTION, EXP, LEVEL FROM Characters WHERE ID = :ID');
  MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then
    while MySQL.Query.Eof = False do begin
      SetLength(Chars,Length(Chars)+1);
      Chars[Length(Chars)-1].CharID:=MySQL.Query.Fields[0].AsInteger;
      Chars[Length(Chars)-1].Promotion:=MySQL.Query.Fields[1].AsInteger;
      Chars[Length(Chars)-1].EXP:=MySQL.Query.Fields[2].AsInteger;
      Chars[Length(Chars)-1].Level:=MySQL.Query.Fields[3].AsInteger;
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

end.
