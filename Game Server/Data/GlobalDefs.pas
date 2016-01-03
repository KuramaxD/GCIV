unit GlobalDefs;

interface

uses System.SyncObjs, Log, ServerSocket, System.SysUtils;

var
  MainCS: TCriticalSection;
  Logger: TLog;
  Server: TServer;

const
  TCP_RELAYIP = $CAC69EB3;
  TCP_RELAYPORT = 9700;

  UDP_RELAYIP = $CAC69EB3;
  UDP_RELAYPORT = 9600;

type

  TCLPID = (
    CLPID_HACKLIST_REQUEST                  = $0017,
    CLPID_CHECKLIST_REQUEST                 = $001B,
    CLPID_PLAYER_LOGIN                      = $0002,
    CLPID_KEEPALIVE                         = $0000,
    CLPID_CHAT                              = $0006,

    CLPID_UNKNOWN_11                        = $0011,
    CLPID_UNKNOWN_19                        = $0019,
    CLPID_NOTHING                           = $FFFF,



    CLPID_562                               = $0232
  );

  TSVPID = (
    SVPID_IV_SET                            = $0001,
    SVPID_INVENTORY                         = $00E0,
    SVPID_SENDVP                            = $0180,
    SVPID_CHAT                              = $0007,

    SVPID_UNKNOWN_0611                      = $0611,
    SVPID_UNKNOWN_0414                      = $0414,

    SVPID_WRONGPASS                         = $0003,
    SVPID_SERVERLIST                        = $0004,
    SVPID_UNKNOWN_5                         = $0005,
    SVPID_LOADING                           = $0018,
    SVPID_REQUEST_CHECK                     = $001C,
    SVPID_UNKNOWN_2                         = $001A,
    SVPID_UNKNOWN_9                         = $0009,
    SVPID_UNKNOWN_A                         = $000A,
    SVPID_UNKNOWN_E                         = $000E,
    SVPID_UNKNOWN_F                         = $000F,
    SVPID_UNKNOWN_1F                        = $001F,
    SVPID_UNKNOWN_1A                        = $001A,
    SVPID_UNKNOWN_12                        = $0012,
    SVPID_NOTHING                           = $FFFF
  );

implementation

end.
