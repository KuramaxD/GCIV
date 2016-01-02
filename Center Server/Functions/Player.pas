unit Player;

interface

uses System.Win.ScktComp, System.SysUtils, CryptLib, Misc, System.StrUtils,
     Windows, Data.DB, Shop, Unknown, ServerList, DBCon, Loading;

type

  TPlayer = class
    Socket: TCustomWinSocket;
    Buffer: TCryptLib;
    Shop: TShop;
    Unknown: TUnknown;
    Servers: TServerList;
    Loading: TLoading;
    ID: Integer;
    Char: Integer;
    MySQL: TQuery;
    procedure LoadLogin;
    procedure SendSelectedChar;
    procedure Send;
    constructor Create(Socket: TCustomWinSocket; Shop: TShop; Unknown: TUnknown; Servers: TServerList; MySQL: TQuery; Loading: TLoading);
    destructor Destroy; override;
  end;

implementation

uses GlobalDefs, Log;

constructor TPlayer.Create(Socket: TCustomWinSocket; Shop: TShop; Unknown: TUnknown; Servers: TServerList; MySQL: TQuery; Loading: TLoading);
var
  TIV, TIV2: AnsiString;
begin
  Self.Socket:=Socket;
  Self.Shop:=Shop;
  Self.Unknown:=Unknown;
  Self.Servers:=Servers;
  Self.Loading:=Loading;
  Self.MySQL:=MySQL;
  ID:=0;
  Buffer:=TCryptLib.Create;
  Buffer.IV:=#$C7#$D8#$C4#$BF#$B5#$E9#$C0#$FD; //IV padrão pego do main
  Buffer.IV2:=#$C0#$D3#$BD#$C3#$B7#$CE#$B8#$B8; //IV2 padrão pego do main
  TIV:=GerarCode;
  TIV2:=GerarCode;
  Buffer.Prefix:=Copy(GerarCode,1,2);
  Buffer.Count:=0;
  Buffer.BIn:='';
  with Buffer do begin
    Write(#$00#$00#$14#$E3#$00#$00#$00);
    Write(Word(SVPID_IV_SET));
    Write(Dword(Count));
    Write(Prefix);
    Write(#$00#$00#$00);
    Write(Byte(Length(TIV2)));
    Write(TIV2);
    Write(#$00#$00#$00);
    Write(Byte(Length(TIV)));
    Write(TIV);
    Write(#$00#$00#$00#$01#$00#$00#$00#$00#$00#$00+
          #$00#$00);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Send;
  Buffer.IV:=TIV;
  Buffer.IV2:=TIV2;
  Buffer.Prefix:=AnsiString(AnsiReverseString(String(Buffer.Prefix)));
  Buffer.BIn:='';
  with Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    Write(#$00);
    Write(Word(SVPID_UNKNOWN_5));
    Write(#$00#$00#$00#$00#$00#$00#$27#$10);
    FixSize;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Send;
end;

destructor TPlayer.Destroy;
begin
  Buffer.Free;
  inherited;
end;

procedure TPlayer.LoadLogin;
var
  Login, Senha: AnsiString;
  CheckList: array of TCRCFILE;
  i, i2, i3, i4: Integer;
begin
  Buffer.Decompress;
  with Buffer do begin
    Login:=RS(16,RB(15));
    Senha:=RS(20+RB(15),RB(RB(15)+19));
    i2:=35+RB(15)+RB(RB(15)+19);
    for i:=1 to RD(31+RB(15)+RB(RB(15)+19)) do begin
      SetLength(CheckList,Length(CheckList)+1);
      CheckList[Length(CheckList)-1].nFile:=RS(i2+1,RB(i2));
      CheckList[Length(CheckList)-1].CRC:=RS(i2+9+RB(i2),RB(i2+8+RB(i2)));
      Inc(i2,12+RB(i2)+RB(i2+8+RB(i2)));
    end;
  end;
  for i:=0 to Length(CheckList)-1 do
    for i2:=0 to Length(Loading.CheckList)-1 do
      if CheckList[i].nFile = Loading.CheckList[i2].nFile then
        if CheckList[i].CRC <> Loading.CheckList[i2].CRC then begin
          Logger.Write(Format('Checagem de CRC falhou [Handle: %d]',[Socket.Handle]),Errors);
          Logger.Write(CheckList[i].CRC,ServerStatus);
          Buffer.BIn:='';
          with Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word(SVPID_WRONGPASS));
            Write(#$00#$00#$00#$00#$0F);
            WriteCd(Dword(Length(Login)*2));
            WriteZd(Login);
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$14#$58+
                  #$FF#$FF#$FF#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$FF#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00);
            i3:=Length(CheckList);
            for i4:=0 to Length(CheckList)-1 do begin
              Write(Dword(i3));
              Write(Byte(Length(CheckList[i4].nFile)*2));
              WriteZd(CheckList[i4].nFile);
              i3:=i3-1;
            end;
            Write(#$01#$00#$00#$00#$00#$00#$F8#$04#$68#$FD+
                  #$20#$04#$B5#$93#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00);
            Compress;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Send;
          Socket.Close;
          Exit;
        end;
  Logger.Write(Format('CRC OK! [Handle: %d]',[Socket.Handle]),Warnings);
  MySQL.SetQuery('SELECT ID, LOGIN, PASS, ONLINECS, ONLINEGS, SCHAR FROM Users WHERE LOGIN = :Login AND PASS = :Pass');
  MySQL.AddParameter('Login',Login);
  MySQL.AddParameter('Pass',Senha);
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then begin
    if (MySQL.Query.Fields[3].AsInteger = 1) or (MySQL.Query.Fields[4].AsInteger = 1) then begin
      Logger.Write(Format('Usuário já logado [Handle: %d]',[Socket.Handle]),Errors);
      Buffer.BIn:='';
      with Buffer do begin
        Write(Prefix);
        Write(Dword(Count));
        WriteCw(Word(SVPID_WRONGPASS));
        Write(#$00#$00#$00#$00#$05);
        WriteCd(Dword(Length(Login)*2));
        WriteZd(Login);
        Write(#$00#$00#$00#$00#$00#$00#$00#$00#$14#$58+
              #$FF#$FF#$FF#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$FF#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00);
        i2:=Length(CheckList);
        for i:=0 to Length(CheckList)-1 do begin
          Write(Dword(i2));
          Write(Byte(Length(CheckList[i].nFile)*2));
          WriteZd(CheckList[i].nFile);
          i2:=i2-1;
        end;
        Write(#$01#$00#$00#$00#$00#$00#$F8#$04#$68#$FD+
              #$20#$04#$B5#$93#$00#$00#$00#$00#$00#$00+
              #$00#$00#$00#$00#$00#$00);
        Compress;
        Encrypt(GenerateIV(0),Random($FF));
        ClearPacket();
      end;
      Send;
      Exit;
    end;
    ID:=MySQL.Query.Fields[0].AsInteger;
    Char:=MySQL.Query.Fields[5].AsInteger;
    MySQL.SetQuery('UPDATE Users SET ONLINECS = 1 WHERE ID = :ID');
    MySQL.AddParameter('ID',AnsiString(IntToStr(ID)));
    MySQL.Run(2);
    Logger.Write(Format('Login OK! [Handle: %d]',[Socket.Handle]),Warnings);
    Logger.Write(Format('Enviando ServerList [Handle: %d]',[Socket.Handle]),Warnings);
    Servers.Update;
    Servers.Compile(Self);
    Unknown.SendUnknown9(Self);
    Shop.Compile(Self);
    Unknown.SendUnknownE(Self);
    Unknown.SendUnknownF(Self);
    Unknown.SendUnknown1E(Self);
    Buffer.BIn:='';
    with Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(SVPID_WRONGPASS));
      Write(#$00#$00#$00#$00#$00);
      WriteCd(Dword(Length(Login)*2));
      WriteZd(Login);
      WriteCd(Dword(Length(Senha)));
      Write(Senha);
      Write(#$00#$00#$00#$00#$14#$00#$24#$F5#$18#$00+
            #$00#$00#$00#$00#$00#$00#$02#$42#$52#$00+
            #$02#$35#$05#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$FF+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$01#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$03#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00);
      WriteCd(Dword(Length(Loading.GuildMark)*2));
      WriteZd(Loading.GuildMark);
      Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00);
      i3:=Length(CheckList);
      for i4:=0 to Length(CheckList)-1 do begin
        Write(Byte(i3));
        WriteCd(Dword(Length(CheckList[i4].nFile)*2));
        WriteZd(CheckList[i4].nFile);
        i3:=i3-1;
      end;
      Write(#$01#$00#$00#$00#$01#$00#$00#$00#$04#$00+
            #$00#$00#$00#$00#$00#$00#$01#$9B#$01#$00+
            #$00#$00#$00#$01#$EE#$6C#$C6#$02#$00#$00+
            #$00#$00#$00#$00#$06#$01#$0E#$00#$00#$00+
            #$00#$00#$00#$01#$9B#$01#$BF#$80#$00#$00+
            #$20#$04#$98#$1B#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00);
      Compress;
      Encrypt(GenerateIV(0),Random($FF));
      ClearPacket();
    end;
    Send;
  end
  else begin
    Logger.Write(Format('Login ou senha incorretos [Handle: %d]',[Socket.Handle]),Errors);
    Buffer.BIn:='';
    with Buffer do begin
      Write(Prefix);
      Write(Dword(Count));
      WriteCw(Word(SVPID_WRONGPASS));
      Write(#$00#$00#$00#$00#$14);
      WriteCd(Dword(Length(Login)*2));
      WriteZd(Login);
      Write(#$00#$00#$00#$00#$00#$00#$00#$00#$14#$58+
            #$FF#$FF#$FF#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$FF#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00);
      i2:=Length(CheckList);
      for i:=0 to Length(CheckList)-1 do begin
        Write(Dword(i2));
        Write(Byte(Length(CheckList[i].nFile)*2));
        WriteZd(CheckList[i].nFile);
        i2:=i2-1;
      end;
      Write(#$01#$00#$00#$00#$00#$00#$F8#$04#$68#$FD+
            #$20#$04#$B5#$93#$00#$00#$00#$00#$00#$00+
            #$00#$00#$00#$00#$00#$00);
      Compress;
      Encrypt(GenerateIV(0),Random($FF));
      ClearPacket();
    end;
    Send;
  end;
end;

procedure TPlayer.SendSelectedChar;
begin
  Buffer.BIn:='';
  with Buffer do begin
    Write(Prefix);
    Write(Dword(Count));
    WriteCw(Word(SVPID_SELECTEDCHAR));
    Write(#$00#$00#$00#$00#$02#$00#$00#$00#$00#$00#$FF);
    WriteCw(Word(Char));
    Compress;
    Encrypt(GenerateIV(0),Random($FF));
    ClearPacket();
  end;
  Send;
end;

procedure TPlayer.Send;
var
  Data: PAnsiChar;
  DataLen, Sent: Integer;
begin
  Data:=PAnsiChar(Buffer.BIn);
  DataLen:=Length(Buffer.BIn);
  while DataLen > 0 do begin
    Sent:=Socket.SendBuf(Data^, DataLen);
    if Sent > 0 then begin
      Inc(Data,Sent);
      Dec(DataLen,Sent);
    end;
  end;
  if Buffer.Count = $FFFF then
    Buffer.Count:=1
  else
    Inc(Buffer.Count,1);
end;

end.
