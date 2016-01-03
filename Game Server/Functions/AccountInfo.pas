unit AccountInfo;

interface

uses Data.DB, DBCon, System.SysUtils;

type
  TAccountInfo = class
    private
      MySQL: TQuery;
    public
      ID: Integer;
      Login: AnsiString;
      Nick: AnsiString;
      Char: Integer;
      Room: Integer;
      Slot: Integer;
      Team: Integer;
      constructor Create(ID: Integer; MySQL: TQuery);
  end;

implementation

constructor TAccountInfo.Create(ID: Integer; MySQL: TQuery);
begin
  Self.ID:=ID;
  Self.MySQL:=MySQL;
  MySQL.SetQuery('SELECT LOGIN, NICK, SCHAR FROM Users WHERE ID = :ID');
  MySQL.AddParameter('ID',AnsiString(IntToStr(ID)));
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then begin
    Login:=MySQL.Query.Fields[0].AsAnsiString;
    Nick:=MySQL.Query.Fields[1].AsAnsiString;
    Char:=MySQL.Query.Fields[2].AsInteger;
  end;
  Room:=-1;
end;

end.
