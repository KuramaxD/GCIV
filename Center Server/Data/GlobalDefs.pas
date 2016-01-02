unit GlobalDefs;

interface

uses System.SyncObjs, Log, ServerSocket;

var
  MainCS: TCriticalSection;
  Logger: TLog;
  Server: TServer;

type

  TCLPID = (
    CLPID_HACKLIST_REQUEST                  = $0017,
    CLPID_CHECKLIST_REQUEST                 = $001B,
    CLPID_PLAYER_LOGIN                      = $0002,
    CLPID_KEEPALIVE                         = $0000,
    CLPID_UNKNOWN_11                        = $0011,
    CLPID_UNKNOWN_19                        = $0019,
    CLPID_NOTHING                           = $FFFF
  );

  TSVPID = (
    SVPID_IV_SET                            = $0001,
    SVPID_WRONGPASS                         = $0003,
    SVPID_SERVERLIST                        = $0004,
    SVPID_SHOPLIST                          = $000A,
    SVPID_SELECTEDCHAR                      = $0012,
    SVPID_UNKNOWN_5                         = $0005,
    SVPID_LOADING                           = $0018,
    SVPID_REQUEST_CHECK                     = $001C,
    SVPID_UNKNOWN_2                         = $001A,
    SVPID_UNKNOWN_9                         = $0009,
    SVPID_UNKNOWN_E                         = $000E,
    SVPID_UNKNOWN_F                         = $000F,
    SVPID_UNKNOWN_1E                        = $001E,
    SVPID_UNKNOWN_1A                        = $001A,
    SVPID_NOTHING                           = $FFFF
  );

  TCRCFILE = record
    nFile: AnsiString;
    CRC: AnsiString;
  end;

implementation

end.
