unit Unknown;

interface

uses Player, Windows;

type
  TUnknown = class
    destructor Destroy; override;
  end;

implementation

uses GlobalDefs;

destructor TUnknown.Destroy;
begin
  inherited;
end;

end.
