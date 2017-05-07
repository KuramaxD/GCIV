 program CenterServer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SimpleShareMem,
  System.SysUtils,
  System.SyncObjs,
  Windows,
  System.DateUtils,
  GlobalDefs in 'Data\GlobalDefs.pas',
  Log in 'Functions\Log.pas',
  Misc in 'Functions\Misc.pas',
  ServerSocket in 'Connection\ServerSocket.pas',
  Player in 'Functions\Player.pas',
  CryptLib in 'Connection\CryptLib.pas',
  Loading in 'Functions\Loading.pas',
  ServerList in 'Functions\ServerList.pas',
  Unknown in 'Functions\Unknown.pas',
  DBCon in 'Connection\DBCon.pas',
  Shop in 'Functions\Shop.pas';

var
  Msg: TMsg;
  bRet: LongBool;
  UpTime: TDateTime;
  TimeInit: Integer;

begin
  try
    SetConsoleTitle('Center Server');
    MainCS:=TCriticalSection.Create;
    Randomize;
    UpTime:=Now;
    Logger:=TLog.Create;
    Logger.Write('Iniciando servidor',ServerStatus);
    try
      Server:=TServer.Create(9501);
      if (Server.Socket<>nil) and (Server.Socket.Active) then begin
        TimeInit:=MilliSecondsBetween(Now, UpTime);
        Logger.Write('Servidor levou ' + IntToStr(TimeInit) + ' milisegundos para carregar(aprox: ' + FloatToStr(TimeInit/1000) +' segundos).', Warnings);
      end else exit;
    except
      on E : Exception do
        Logger.Write(E.ClassName,Errors);
    end;
    while Server.Socket.Active do begin
      bRet:=GetMessage(Msg,0,0,0);
      if Integer(bRet) = -1 then begin
        Break;
      end
      else begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
