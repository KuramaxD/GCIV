unit Pets;

interface

uses DBCon, AccountInfo, System.SysUtils, Data.DB, Windows, Log;

type
  TRPet = record
    ID: Integer;
    ItemID: Integer;
    EXP: Integer;
    Health: Integer;
    Name: AnsiString;
    Slot1: Integer;
    Slot2: Integer;
    Level: Integer;
  end;

type
  TPetTransform = record
    PetID: Integer;
    nPetID: Integer;
  end;

type
  TPet = class
    private
      MySQL: TQuery;
      AccInfo: TAccountInfo;
    public
      Pets: array of TRPet;
      PetTransform: array of TPetTransform;
      constructor Create(MySQL: TQuery; AccInfo: TAccountInfo);
      function GetPetTransform(PetID: Integer): Integer;
      procedure AddPetTransform(PetID, nPetID: Integer);
      procedure Feed(PPlayer: Pointer);
      procedure ChangeName(PPlayer: Pointer);
      procedure Incube(PPlayer: Pointer);
  end;

implementation

uses Player, GlobalDefs, Inventory, SortUS;

constructor TPet.Create(MySQL: TQuery; AccInfo: TAccountInfo);
begin
  Self.AccInfo:=AccInfo;
  Self.MySQL:=MySQL;
  MySQL.SetQuery('SELECT PETID, PETIID, EXP, HEALTH, NAME, SLOT1, SLOT2, LEVEL FROM Pets WHERE UID = :ID');
  MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
  MySQL.Run(1);
  if MySQL.Query.IsEmpty = False then
    while MySQL.Query.Eof = False do begin
      SetLength(Pets,Length(Pets)+1);
      Pets[Length(Pets)-1].ID:=MySQL.Query.Fields[0].AsInteger;
      Pets[Length(Pets)-1].ItemID:=MySQL.Query.Fields[1].AsInteger;
      Pets[Length(Pets)-1].EXP:=MySQL.Query.Fields[2].AsInteger;
      Pets[Length(Pets)-1].Health:=MySQL.Query.Fields[3].AsInteger;
      Pets[Length(Pets)-1].Name:=MySQL.Query.Fields[4].AsAnsiString;
      Pets[Length(Pets)-1].Slot1:=MySQL.Query.Fields[5].AsInteger;
      Pets[Length(Pets)-1].Slot2:=MySQL.Query.Fields[6].AsInteger;
      Pets[Length(Pets)-1].Level:=MySQL.Query.Fields[7].AsInteger;
      MySQL.Query.Next;
    end;
  AddPetTransform(43510,42360); //Gon
  AddPetTransform(43540,43120); //Gosma
end;

function TPet.GetPetTransform(PetID: Integer): Integer;
var
  i: Integer;
begin
  Result:=-1;
  for i:=0 to Length(PetTransform)-1 do
    if PetTransform[i].PetID = PetID then begin
      Result:=PetTransform[i].nPetID;
      Break;
    end;
end;

procedure TPet.AddPetTransform(PetID, nPetID: Integer);
begin
  SetLength(PetTransform,Length(PetTransform)+1);
  PetTransform[Length(PetTransform)-1].PetID:=PetID;
  PetTransform[Length(PetTransform)-1].nPetID:=nPetID;
end;

procedure TPet.Feed(PPlayer: Pointer);
var
  Player: TPlayer;
  Pet, Food, i: Integer;
  Temp: TRInventory;
  Item: TItem;
begin
  Player:=TPlayer(PPlayer);
  Pet:=Player.Buffer.RCd(12);
  Food:=Player.Buffer.RCd(20);
  for i:=0 to Length(Pets)-1 do
    if Pets[i].ID = Pet then
      if Pets[i].Health < 6000 then begin
        Temp:=Player.Inventory.ContainID(Food);
        if Temp.ID > 0 then begin
          Player.SortUS.Items.TryGetValue(Temp.ItemID,Item);
          if Item.Food > 0 then begin
            Inc(Pets[i].Health,Item.Food);
            if Pets[i].Health > 6000 then
              Pets[i].Health:=6000;
            MySQL.SetQuery('UPDATE PETS SET HEALTH = :HEALTH WHERE PETID = :PETID');
            MySQL.AddParameter('HEALTH',AnsiString(IntToStr(Pets[i].Health)));
            MySQL.AddParameter('PETID',AnsiString(IntToStr(Pets[i].ID)));
            MySQL.Run(2);
            Temp:=Player.Inventory.RemoveID(Temp.ID,1);
            Player.Buffer.BIn:='';
            with Player.Buffer do begin
              Write(Prefix);
              Write(Dword(Count));
              WriteCw(Word(SVPID_FEEDPET));
              Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00);
              Write(#$00#$00#$00#$01);
              WriteCd(Dword(Pets[i].ID));
              WriteCd(Dword(Pets[i].Health));
              WriteCd(Dword(Temp.ItemID));
              Write(#$00#$00#$00#$01);
              WriteCd(Dword(Temp.ID));
              WriteCd(Dword(Temp.Quantity));
              WriteCd(Dword(Temp.Quantity+1));
              Write(#$00#$00#$FF#$FF#$00#$00#$FF#$FF#$FF#$FF+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                    #$00#$00#$FF#$00#$00#$00#$00#$00#$00#$00+
                    #$00);
              FixSize;
              Encrypt(GenerateIV(0),Random($FF));
              ClearPacket();
            end;
            Player.Send;
          end;
          Break;
        end;
      end;
end;

procedure TPet.ChangeName(PPlayer: Pointer);
var
  Player: TPlayer;
  ID, iID, Pet, i: Integer;
  Name: AnsiString;
  Temp: TRInventory;
begin
  Player:=TPlayer(PPlayer);
  iID:=Player.Buffer.RCd(12);
  ID:=Player.Buffer.RCd(20);
  Pet:=Player.Buffer.RCd(87);
  Name:=Player.Buffer.RS(99,Player.Buffer.RCd(95));
  Temp:=Player.Inventory.ContainID(ID);
  if (Temp.ID > 0) and (Temp.ItemID = iID) and (Temp.ItemID = 38970) then
    for i:=0 to Length(Pets)-1 do
      if Pets[i].ID = Pet then begin
        Pets[i].Name:=Name;
        MySQL.SetQuery('UPDATE PETS SET NAME = :NAME WHERE PETID = :PETID');
        MySQL.AddParameter('NAME',AnsiString(Pets[i].Name));
        MySQL.AddParameter('PETID',AnsiString(IntToStr(Pets[i].ID)));
        MySQL.Run(2);
        Player.Inventory.RemoveID(ID,1);
        Player.Buffer.BIn:='';
        with Player.Buffer do begin
          Write(Prefix);
          Write(Dword(Count));
          WriteCw(Word(SVPID_CHANGEPETNAME));
          Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00);
          FixSize;
          Encrypt(GenerateIV(0),Random($FF));
          ClearPacket();
        end;
        Player.Send;
        Break;
      end;
end;

procedure TPet.Incube(PPlayer: Pointer);
var
  Player: TPlayer;
  PetID, i: Integer;
  APet: TRPet;
  Temp: TRInventory;
  Temp2: TItem;
  Livro, Ovo, Atk, NPet: TRInventory;
begin
  Player:=TPlayer(PPlayer);
  PetID:=Player.Buffer.RCd(12);
  Livro:=Player.Inventory.ContainiID(43550);
  if Livro.ID > 0 then
    for i:=0 to Length(Pets)-1 do
      if (Pets[i].ID = PetID) and (Pets[i].Level >= 7) then begin
        if GetPetTransform(Pets[i].ItemID) > -1 then begin
          Livro:=Player.Inventory.RemoveID(Livro.ID,1);
          Ovo:=Player.Inventory.RemoveID(PetID,1);
          //isso ai ta errado
          for Temp2 in Player.SortUS.Items.Values do
            if Temp2.Atk = GetPetTransform(Pets[i].ItemID) then begin
              Atk:=Player.Inventory.Add(Temp.ItemID,100,1);
              Break;
            end;

          NPet:=Player.Inventory.Add(GetPetTransform(Pets[i].ItemID),$FFFFFFFF,0);
          APet:=Pets[i];
          Pets[i].ID:=NPet.ID;
          Pets[i].ItemID:=NPet.ItemID;
          Pets[i].EXP:=100;
          Pets[i].Health:=1000;
          Pets[i].Slot1:=0;
          Pets[i].Slot2:=0;
          Pets[i].Level:=0;
          Player.SortUS.Items.TryGetValue(Pets[i].ID,Temp2);
          Pets[i].Name:=Copy(Temp2.Name,10,Length(Temp2.Name));
          MySQL.SetQuery('DELETE FROM Pets WHERE UID = :ID AND PETID = :PETID');
          MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
          MySQL.AddParameter('PETID',AnsiString(IntToStr(APet.ID)));
          MySQL.Run(2);
          MySQL.SetQuery('INSERT INTO Pets (UID, PETID, PETiID, HEALTH, NAME) VALUES (:ID, :PETID, :PETiID, :HEALTH, :NAME)');
          MySQL.AddParameter('ID',AnsiString(IntToStr(AccInfo.ID)));
          MySQL.AddParameter('PETID',AnsiString(IntToStr(NPet.ID)));
          MySQL.AddParameter('PETiID',AnsiString(IntToStr(NPet.ItemID)));
          MySQL.AddParameter('HEALTH',AnsiString(IntToStr(1000)));
          MySQL.AddParameter('NAME',AnsiString(Pets[i].Name));
          MySQL.Run(2);
          Player.Buffer.BIn:='';
          with Player.Buffer do begin
            Write(Prefix);
            Write(Dword(Count));
            WriteCw(Word($10C));
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00);
            WriteCd(Dword(Livro.ItemID));
            WriteCd(Dword(NPet.ItemID));
            Write(#$00#$00#$00#$01);
            WriteCd(Dword(NPet.ID));
            Write(#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$FF#$00+
                  #$00#$00#$00#$00#$FF#$FF#$FF#$FF#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$FF#$00#$00#$00#$00#$00#$00#$00#$00);
            Write(#$00#$00#$00#$01);
            WriteCd(Dword(NPet.ID));
            WriteCd(Dword(NPet.ItemID));
            WriteCd(Dword(Length(Pets[i].Name)*2));
            WriteZd(Pets[i].Name);
            Write(#$00#$00#$00#$03#$00);
            WriteCd(Dword(Pets[i].EXP));
            Write(#$01#$00#$00#$00#$64#$02#$00#$00#$00#$64);
            WriteCd(Dword(Pets[i].EXP));
            WriteCd(Dword(Pets[i].Level));
            Write(#$00);
            WriteCd(Dword(GetPetTransform(Pets[i].ItemID)));
            WriteCd(Dword(Pets[i].Health));
            WriteCd(Dword(Pets[i].Health));
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$FF#$FF);
            Write(#$00#$00#$00#$01);
            WriteCd(Dword(APet.ID));
            WriteCd(Dword(APet.ItemID));
            WriteCd(Dword(Length(APet.Name)*2));
            WriteZd(APet.Name);
            Write(#$00#$00#$00#$03#$00);
            WriteCd(Dword(APet.EXP));
            Write(#$01#$00#$00#$00#$64#$02#$00#$00#$00#$64);
            WriteCd(Dword(APet.EXP));
            WriteCd(Dword(APet.Level));
            Write(#$00);
            WriteCd(Dword(GetPetTransform(APet.ItemID)));
            WriteCd(Dword(APet.Health));
            WriteCd(Dword(APet.Health));
            if (APet.Slot1 > 0) and (APet.Slot2 > 0) then
              Write(#$00#$00#$00#$02)
            else
              if (APet.Slot1 = 0) and (APet.Slot2 = 0) then
                Write(#$00#$00#$00#$00)
              else
                Write(#$00#$00#$00#$01);
            if APet.Slot2 > 0 then begin
              Temp:=Player.Inventory.ContainID(APet.Slot2);
              WriteCd(Dword(Temp.ItemID));
              Write(#$00#$00#$00#$01);
              WriteCd(Dword(Temp.ID));
              Write(#$00);
            end;
            if APet.Slot1 > 0 then begin
              Temp:=Player.Inventory.ContainID(APet.Slot1);
              WriteCd(Dword(Temp.ItemID));
              Write(#$00#$00#$00#$01);
              WriteCd(Dword(Temp.ID));
              Write(#$00);
            end;
            if (APet.Slot1 > 0) and (APet.Slot2 > 0) then
              Write(#$00#$00#$00#$02)
            else
              if (APet.Slot1 = 0) and (APet.Slot2 = 0) then
                Write(#$00#$00#$00#$00)
              else
                Write(#$00#$00#$00#$01);
            if APet.Slot2 > 0 then begin
              Temp:=Player.Inventory.ContainID(APet.Slot2);
              WriteCd(Dword(Temp.ItemID));
              Write(#$00#$00#$00#$01);
              WriteCd(Dword(Temp.ID));
              Write(#$00);
            end;
            if APet.Slot1 > 0 then begin
              Temp:=Player.Inventory.ContainID(APet.Slot1);
              WriteCd(Dword(Temp.ItemID));
              Write(#$00#$00#$00#$01);
              WriteCd(Dword(Temp.ID));
              Write(#$00);
            end;
            Write(#$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$FF#$FF);
            Write(#$00#$00#$00#$01);
            WriteCd(Dword(Atk.ItemID));
            Write(#$00#$00#$00#$01);
            WriteCd(Dword(Atk.ID));
            WriteCd(Dword(Atk.Quantity));
            WriteCd(Dword(Atk.Quantity));
            Write(#$00#$00#$FF#$FF#$00#$00#$FF#$FF#$FF+
                  #$FF#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$00#$00#$00+
                  #$00#$00#$00#$00#$00#$00#$FF#$00#$00+
                  #$00#$00#$00#$00#$00#$00);
            FixSize;
            Encrypt(GenerateIV(0),Random($FF));
            ClearPacket();
          end;
          Player.Send;
        end;
        Break;
      end;
end;

end.
