unit DBCon;

interface

uses Data.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
     FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
     FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Stan.Param, FireDAC.DatS,
     FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet,FireDAC.Comp.Client,
     FireDAC.Phys.MySQLDef, FireDAC.Phys.MySQL, Log, System.SysUtils;

type
  TQuery = class
    MySQL: TFDConnection;
    Query: TFDQuery;
    constructor Create(Server: AnsiString; Port: Integer; Login, Senha, DB: AnsiString);
    destructor Destroy; override;
    procedure SetQuery(Query: AnsiString);
    procedure AddParameter(Param, Value: AnsiString);
    procedure Run(Tp: Byte);
  end;

implementation

uses GlobalDefs;

constructor TQuery.Create(Server: AnsiString; Port: Integer; Login: AnsiString; Senha: AnsiString; DB: AnsiString);
begin
  MySQL:=TFDConnection.Create(nil);
  MySQL.Params.Add('DriverID=MySQL');
  MySQL.Params.Add('Server='+String(Server));
  MySQL.Params.Add('Port='+IntToStr(Port));
  MySQL.Params.Add('Database='+String(DB));
  MySQL.Params.Add('User_Name='+String(Login));
  MySQL.Params.Add('Password='+String(Senha));
  MySQL.ResourceOptions.AutoReconnect:=True;
  Query:=TFDQuery.Create(nil);
  Query.Connection:=MySQL;
  try
    MySQL.Open;
  except
    on E: Exception do begin
      MySQL.Connected:=False;
      Logger.Write(e.Message,Errors);
    end;
  end;
end;

destructor TQuery.Destroy;
begin
  MySQL.Close;
  Query.Destroy;
  MySQL.Destroy;
end;

procedure TQuery.SetQuery(Query: AnsiString);
begin
  Self.Query.Close;
  Self.Query.SQL.Clear;
  Self.Query.DisableControls;
  Self.Query.SQL.Text:=String(Query);
end;

procedure TQuery.AddParameter(Param: AnsiString; Value: AnsiString);
begin
  Self.Query.ParamByName(String(Param)).Value:=Value;
end;

procedure TQuery.Run(Tp: Byte);
begin
  try
    if Tp = 1 then
      Self.Query.Open
    else
      Self.Query.ExecSQL;
  except
    Logger.Write(Query.SQL.Text,Errors);
    Exit;
  end;
end;


end.
