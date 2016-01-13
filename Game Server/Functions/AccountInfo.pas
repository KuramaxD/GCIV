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
      GM: Boolean;
      constructor Create(ID: Integer; MySQL: TQuery);
      procedure Update;
  end;

implementation

constructor TAccountInfo.Create(ID: Integer; MySQL: TQuery);
begin
  Self.ID:=ID;
  Self.MySQL:=MySQL;
  MySQL.SetQuery('SELECT LOGIN, NICK, SCHAR, GM FROM Users WHERE ID = :ID');
  MySQL.AddParameter('ID',AnsiString(IntToStr(ID)));
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then begin
    Login:=MySQL.Query.Fields[0].AsAnsiString;
    Nick:=MySQL.Query.Fields[1].AsAnsiString;
    Char:=MySQL.Query.Fields[2].AsInteger;
    GM:=Boolean(MySQL.Query.Fields[3].AsInteger);
  end;
  Room:=-1;
end;

procedure TAccountInfo.Update;
begin
  MySQL.SetQuery('UPDATE Users SET SCHAR = :SCHAR WHERE ID = :ID');
  MySQL.AddParameter('SCHAR',AnsiString(IntToStr(Char)));
  MySQL.AddParameter('ID',AnsiString(IntToStr(ID)));
  MySQL.Run(2);
end;

end.
