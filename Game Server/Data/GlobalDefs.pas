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
    CLPID_PLAYER_LOGIN                      = $0002,
    CLPID_KEEPALIVE                         = $0000,
    CLPID_CHAT                              = $0006,
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

    SVPID_NOTHING                           = $FFFF
  );

implementation

end.
