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
    CLPID_WHISPER                           = $0008,
    CLPID_CHANGEGAMESETTINGS                = $001C,
    CLPID_CHANGEROOMSETTINGS                = $0117,
    CLPID_AFK                               = $0343,
    CLPID_REQUESTPLAYERSINGAME              = $0345,
    CLPID_REQUESTPLAYSIGN                   = $0027,
    CLPID_LOADINFO                          = $034A,
    CLPID_REQUESTGAMEINFO                   = $0024,
    CLPID_CHANGEUSERSETTINGS                = $0028,
    CLPID_EXITROOMREQUEST                   = $0021,
    CLPID_NOTHING                           = $FFFF,


    CLPID_562                               = $0232
  );

  TSVPID = (
    SVPID_IV_SET                            = $0001,
    SVPID_INVENTORY                         = $00E0,
    SVPID_SENDVP                            = $0180,
    SVPID_CHAT                              = $0007,
    SVPID_WHISPER                           = $0009,
    SVPID_GAMEUPDATE                        = $001D,
    SVPID_ROOMUPDATE                        = $0119,
    SVPID_AFK                               = $0344,
    SVPID_PLAYERSINGAME                     = $0346,
    SVPID_LOADSYNC                          = $034A,
    SVPID_GAMEINFORMATION                   = $0026,
    SVPID_PLAYSIGN                          = $0349,
    SVPID_EXITROOM                          = $0022,
    SVPID_USERUPDATE                        = $0029,
    SVPID_CHANGELEADER                      = $0080,
    SVPID_EXITSIGN                          = $0081,

    SVPID_UNKNOWN_0611                      = $0611,
    SVPID_UNKNOWN_0414                      = $0414,

    SVPID_NOTHING                           = $FFFF
  );

implementation

end.
