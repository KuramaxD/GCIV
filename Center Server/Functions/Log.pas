unit Log;

interface

uses Vcl.StdCtrls, Windows, System.SysUtils, Misc, System.StrUtils;

type TLogType = (Packets, Errors, Warnings, ServerStatus);

type TLog = class
  public
    procedure Write(str: String; logType: TLogType); overload;
    procedure Space(logType: TLogType);
end;

implementation

uses GlobalDefs;

procedure TLog.Write(str: String; logType : TLogType);
var
  PacketID: Word;
  i, i2, it: Integer;
  Temp: AnsiString;
begin
  MainCS.Acquire;
  try
    case logType of
      Packets:
        begin
          Temp:=AnsiString(AnsiReverseString(String(Copy(str,1,2))));
          Move(Temp[1],PacketID,2);
          Writeln('----------------- ID '+IntToStr(PacketID)+' -----------------');
          i:=1;
          while i <= Length(str) do begin
            Temp:=Misc.Space(StringToHex(AnsiString(Copy(str,i,10))));
            it:=29 - Length(Temp);
            for i2:=1 to it do
              Temp:=Temp+' ';
            System.Write(Temp);
            Temp:=AnsiString(Copy(str,i,10));
            for i2:=1 to Length(Temp) do
              if Temp[i2] = #$00 then
                Temp[i2]:='.';
            System.Write(' '+Temp+System.sLineBreak);
            i:=i+10;
          end;
        end;

      Errors:
        begin
          SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE),FOREGROUND_RED OR FOREGROUND_INTENSITY);
          Writeln(str);
          SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE),FOREGROUND_RED OR FOREGROUND_GREEN OR FOREGROUND_BLUE);
        end;

      Warnings:
        begin
          SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE),FOREGROUND_INTENSITY OR FOREGROUND_RED OR FOREGROUND_GREEN);
          Writeln(str);
          SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE),FOREGROUND_RED OR FOREGROUND_GREEN OR FOREGROUND_BLUE);
        end;

      ServerStatus:
        begin
          Writeln(str);
        end;
    end;
  finally
    MainCS.Release;
  end;
end;

procedure TLog.Space(logType: TLogType);
begin
  Write('--------------------------------------------------------------', logType);
end;

end.
