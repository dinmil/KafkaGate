unit nano;

{$mode objfpc}{$H+}
{$A1}

interface

uses
  Classes, SysUtils, ctypes;


const
  LIB_NANO = 'libnanomsg.dll';


  NN_VERSION_CURRENT = 5;
{  The latest revision of the current interface.  }
  NN_VERSION_REVISION = 0;
{  How many past interface versions are still supported.  }
  NN_VERSION_AGE = 0;

{**************************************************************************** }
{  Errors.                                                                    }
{**************************************************************************** }
{  A number random enough not to collide with different errno ranges on       }
{  different OSes. The assumption is that error_t is at least 32-bit type.    }
const
  NN_HAUSNUMERO = 156384712;

  {  On some platforms some standard POSIX errnos are not defined.     }
const
  ENOTSUP = NN_HAUSNUMERO+1;
  EPROTONOSUPPORT = NN_HAUSNUMERO+2;
  ENOBUFS = NN_HAUSNUMERO+3;
  ENETDOWN = NN_HAUSNUMERO+4;
  EADDRINUSE = NN_HAUSNUMERO+5;
  EADDRNOTAVAIL = NN_HAUSNUMERO+6;
  ECONNREFUSED = NN_HAUSNUMERO+7;
  EINPROGRESS = NN_HAUSNUMERO+8;
  ENOTSOCK = NN_HAUSNUMERO+9;
  EAFNOSUPPORT = NN_HAUSNUMERO+10;
  EPROTO = NN_HAUSNUMERO+11;
  EAGAIN = NN_HAUSNUMERO+12;
  EBADF = NN_HAUSNUMERO+13;
  EINVAL = NN_HAUSNUMERO+14;
  EMFILE = NN_HAUSNUMERO+15;
  EFAULT = NN_HAUSNUMERO+16;
  EACCES = NN_HAUSNUMERO+17;
  EACCESS = EACCES;
  ENETRESET = NN_HAUSNUMERO+18;
  ENETUNREACH = NN_HAUSNUMERO+19;
  EHOSTUNREACH = NN_HAUSNUMERO+20;
  ENOTCONN = NN_HAUSNUMERO+21;
  EMSGSIZE = NN_HAUSNUMERO+22;
  ETIMEDOUT = NN_HAUSNUMERO+23;
  ECONNABORTED = NN_HAUSNUMERO+24;
  ECONNRESET = NN_HAUSNUMERO+25;
  ENOPROTOOPT = NN_HAUSNUMERO+26;
  EISCONN = NN_HAUSNUMERO+27;
  ESOCKTNOSUPPORT = NN_HAUSNUMERO+28;

{  Native nanomsg error codes.                                                }
  ETERM = NN_HAUSNUMERO+53;
  EFSM = NN_HAUSNUMERO+54;

  {**************************************************************************** }
  {  Socket mutliplexing support.                                               }
  {**************************************************************************** }
const
  NN_POLLIN = 1;
  NN_POLLOUT = 2;

  NN_TCP = -3;


    {  This function retrieves the errno as it is known to the library.           }
  {  The goal of this function is to make the code 100% portable, including     }
  {  where the library is compiled with certain CRT library (on Windows) and    }
  {  linked to an application that uses different CRT library.                  }
function nn_errno: cint; cdecl; external LIB_NANO;
// NN_EXPORT int nn_errno (void);

  {  Resolves system errors and native errors to human-readable string.         }
function nn_strerror (errnum: cint): PChar; cdecl; external LIB_NANO;
//  NN_EXPORT const char *nn_strerror (int errnum);

  {  Returns the symbol name (e.g. "NN_REQ") and value at a specified index.    }
  {  If the index is out-of-range, returns NULL and sets errno to EINVAL        }
  {  General usage is to start at i=0 and iterate until NULL is returned.       }
//NN_EXPORT const char *nn_symbol (int i, int *value);
function nn_symbol(i: cint; var value: cint): pchar; cdecl; external LIB_NANO;

  {  Constants that are returned in `ns` member of nn_symbol_properties         }

  const
    NN_NS_NAMESPACE = 0;
    NN_NS_VERSION = 1;
    NN_NS_DOMAIN = 2;
    NN_NS_TRANSPORT = 3;
    NN_NS_PROTOCOL = 4;
    NN_NS_OPTION_LEVEL = 5;
    NN_NS_SOCKET_OPTION = 6;
    NN_NS_TRANSPORT_OPTION = 7;
    NN_NS_OPTION_TYPE = 8;
    NN_NS_OPTION_UNIT = 9;
    NN_NS_FLAG = 10;
    NN_NS_ERROR = 11;
    NN_NS_LIMIT = 12;
    NN_NS_EVENT = 13;
    NN_NS_STATISTIC = 14;
  {  Constants that are returned in `type` member of nn_symbol_properties       }
    NN_TYPE_NONE = 0;
    NN_TYPE_INT = 1;
    NN_TYPE_STR = 2;
  {  Constants that are returned in the `unit` member of nn_symbol_properties   }
    NN_UNIT_NONE = 0;
    NN_UNIT_BYTES = 1;
    NN_UNIT_MILLISECONDS = 2;
    NN_UNIT_PRIORITY = 3;
    NN_UNIT_BOOLEAN = 4;
    NN_UNIT_MESSAGES = 5;
    NN_UNIT_COUNTER = 6;
  {  Structure that is returned from nn_symbol   }
  {  The constant value   }
  {  The constant name   }
(* Const before type ignored *)
  {  The constant namespace, or zero for namespaces themselves  }
  {  The option type for socket option constants   }
  {  The unit for the option value for socket option constants   }

  type
    Pnn_symbol_properties = ^nn_symbol_properties;
    nn_symbol_properties = packed record
        value : longint;
        name : Pchar;
        ns : longint;
        _type : longint;
        _unit : longint;
      end;

  {  Fills in nn_symbol_properties structure and returns it's length            }
  {  If the index is out-of-range, returns 0                                    }
  {  General usage is to start at i=0 and iterate until zero is returned.       }
  // NN_EXPORT int nn_symbol_info (int i, struct nn_symbol_properties *buf, int buflen);
  function nn_symbol_info (i: cint; var buf: nn_symbol_properties; buflen: cint): cint; cdecl; external LIB_NANO;

  {**************************************************************************** }
  {  Helper function for shutting down multi-threaded applications.             }
  {**************************************************************************** }
// NN_EXPORT void nn_term (void);
   procedure nn_term; cdecl; external LIB_NANO;
  {**************************************************************************** }
  {  Zero-copy support.                                                         }
  {**************************************************************************** }

  { was #define dname def_expr }
  // #define NN_MSG ((size_t) -1)
  // function NN_MSG : csize_t;


  // NN_EXPORT void *nn_allocmsg (size_t size, int type);
  // NN_EXPORT void *nn_reallocmsg (void *msg, size_t size);
  // NN_EXPORT int nn_freemsg (void *msg);

   procedure nn_allocmsg (size: csize_t; msgtype: cint); cdecl; external LIB_NANO;
   procedure nn_reallocmsg (msg: pointer; size: csize_t); cdecl; external LIB_NANO;
   procedure nn_freemsg (msg: pointer); cdecl; external LIB_NANO;


  {**************************************************************************** }
  {  Socket definition.                                                         }
  {**************************************************************************** }

  type
    Pnn_iovec = ^nn_iovec;
    nn_iovec = packed record
        iov_base : pointer;
        iov_len : csize_t;
      end;

    Pnn_msghdr = ^nn_msghdr;
    nn_msghdr = packed record
        msg_iov : Pnn_iovec;
        msg_iovlen : longint;
        msg_control : pointer;
        msg_controllen : csize_t;
      end;

    Pnn_cmsghdr = ^nn_cmsghdr;
    nn_cmsghdr = packed record
        cmsg_len : csize_t;
        cmsg_level : longint;
        cmsg_type : longint;
      end;

  {  Internal stuff. Not to be used directly.                                   }
  // NN_EXPORT  struct nn_cmsghdr *nn_cmsg_nxthdr_ (const struct nn_msghdr *mhdr, const struct nn_cmsghdr *cmsg);
  nn_cmsg_nxthdr_ = packed record
    mhdr: Pnn_msghdr;
    cmsg: Pnn_cmsghdr
  end;

  // #define NN_CMSG_ALIGN_(len) \ (((len) + sizeof (size_t) - 1) & (size_t) ~(sizeof (size_t) - 1))
  //function NN_CMSG_ALIGN_(len : longint) : longint;

{ POSIX-defined msghdr manipulation.  }
{ was #define dname(params) para_def_expr }
{ argument types are unknown }
{ return type might be wrong }
// #define NN_CMSG_FIRSTHDR(mhdr) \ nn_cmsg_nxthdr_ ((struct nn_msghdr*) (mhdr), NULL)
//function NN_CMSG_FIRSTHDR(mhdr : longint) : longint;

{ was #define dname(params) para_def_expr }
{ argument types are unknown }
{ return type might be wrong }
// #define NN_CMSG_NXTHDR(mhdr, cmsg) \ nn_cmsg_nxthdr_ ((struct nn_msghdr*) (mhdr), (struct nn_cmsghdr*) (cmsg))
//function NN_CMSG_NXTHDR(mhdr,cmsg : longint) : longint;

{ was #define dname(params) para_def_expr }
{ argument types are unknown }
// #define NN_CMSG_DATA(cmsg) \ ((unsigned char*) (((struct nn_cmsghdr*) (cmsg)) + 1))
//function NN_CMSG_DATA(cmsg : longint) : Pbyte;

{ Extensions to POSIX defined by RFC 3542.                                    }
// #define NN_CMSG_SPACE(len) \ (NN_CMSG_ALIGN_ (len) + NN_CMSG_ALIGN_ (sizeof (struct nn_cmsghdr)))
// #define NN_CMSG_LEN(len) \ (NN_CMSG_ALIGN_ (sizeof (struct nn_cmsghdr)) + (len))

    {  SP address families.                                                       }
  const
    NN_PROTO_PIPELINE = 5;
    NN_PUSH = (NN_PROTO_PIPELINE * 16 + 0);
    NN_PULL = (NN_PROTO_PIPELINE * 16 + 1);

    NN_PROTO_PUBSUB=2;
    NN_PUB=NN_PROTO_PUBSUB * 16 + 0;
    NN_SUB=NN_PROTO_PUBSUB * 16 + 1;
    NN_SUB_SUBSCRIBE =1;
    NN_SUB_UNSUBSCRIBE=2;

    NN_PROTO_BUS=7;
    NN_BUS=(NN_PROTO_BUS * 16 + 0);

    NN_PROTO_PAIR = 1;
    NN_PAIR = NN_PROTO_PAIR * 16 + 0;

    NN_PROTO_SURVEY = 6;
    NN_SURVEYOR = (NN_PROTO_SURVEY * 16 + 2);
    NN_RESPONDENT = (NN_PROTO_SURVEY * 16 + 3);
    NN_SURVEYOR_DEADLINE = 1;

    NN_INPROC=-1;
    NN_IPC=-2;

    REQREP_H_INCLUDED=1;
    NN_PROTO_REQREP = 3;

    NN_REQ=NN_PROTO_REQREP * 16 + 0;
    NN_REP=NN_PROTO_REQREP * 16 + 1;

    NN_REQ_RESEND_IVL=1;

    AF_SP: integer = 1;
    AF_SP_RAW: integer = 2;
  {  Max size of an SP address.                                                 }
    NN_SOCKADDR_MAX = 128;
  {  Socket option levels: Negative numbers are reserved for transports,
      positive for socket types.  }
    NN_SOL_SOCKET = 0;
  {  Generic socket options (NN_SOL_SOCKET level).                              }
    NN_LINGER = 1;
    NN_SNDBUF = 2;
    NN_RCVBUF = 3;
    NN_SNDTIMEO = 4;
    NN_RCVTIMEO = 5;
    NN_RECONNECT_IVL = 6;
    NN_RECONNECT_IVL_MAX = 7;
    NN_SNDPRIO = 8;
    NN_RCVPRIO = 9;
    NN_SNDFD = 10;
    NN_RCVFD = 11;
    NN_DOMAIN = 12;
    NN_PROTOCOL = 13;
    NN_IPV4ONLY = 14;
    NN_SOCKET_NAME = 15;
    NN_RCVMAXSIZE = 16;
    NN_MAXTTL = 17;
  {  Send/recv options.                                                         }
    NN_DONTWAIT = 1;
  {  Ancillary data.                                                            }
    PROTO_SP = 1;
    SP_HDR = 1;

    (*
    NN_EXPORT int nn_socket (int domain, int protocol);
    NN_EXPORT int nn_close (int s);
    NN_EXPORT int nn_setsockopt (int s, int level, int option, const void *optval,
        size_t optvallen);
    NN_EXPORT int nn_getsockopt (int s, int level, int option, void *optval,
        size_t *optvallen);
    NN_EXPORT int nn_bind (int s, const char *addr);
    NN_EXPORT int nn_connect (int s, const char *addr);
    NN_EXPORT int nn_shutdown (int s, int how);
    NN_EXPORT int nn_send (int s, const void *buf, size_t len, int flags);
    NN_EXPORT int nn_recv (int s, void *buf, size_t len, int flags);
    NN_EXPORT int nn_sendmsg (int s, const struct nn_msghdr *msghdr, int flags);
    NN_EXPORT int nn_recvmsg (int s, struct nn_msghdr *msghdr, int flags);
    *)

    function nn_socket (domain: integer; protocol: integer): integer; cdecl; external LIB_NANO;
    function nn_close (s: integer): integer; cdecl; external LIB_NANO;
    function nn_setsockopt (s, level, option: integer; optval: pointer; optvallen: csize_t): integer; cdecl; external LIB_NANO;
//    function nn_getsockopt (s, level, option: integer; optval: pointer; optvallen: csize_t): integer; cdecl; external LIB_NANO;
    function nn_getsockopt (s, level, option: integer; optval: pointer; var optvallen: dword): integer; cdecl; external LIB_NANO;
    function nn_bind (s: integer; addr: pchar): integer; cdecl; external LIB_NANO;
    function nn_connect (s: integer; addr: pchar): integer; cdecl; external LIB_NANO;
    function nn_shutdown (s, how: integer): integer; cdecl; external LIB_NANO;
    function nn_send (s: integer; buf: Pointer; len: csize_t; flags: integer): integer; cdecl; external LIB_NANO;
    function nn_recv (s: integer; buf: Pointer; len: csize_t; flags: integer): integer; cdecl; external LIB_NANO;
    function nn_sendmsg (s: integer; var msghdr: nn_msghdr; flags: integer): integer; cdecl; external LIB_NANO;
    function nn_recvmsg (s: integer; var msghdr: nn_msghdr ;flags: integer): integer; cdecl; external LIB_NANO;

  {**************************************************************************** }
  {  Socket mutliplexing support.                                               }
  {**************************************************************************** }
  type
    Pnn_pollfd = ^nn_pollfd;
    nn_pollfd = packed record
        fd : longint;
        events : smallint;
        revents : smallint;
      end;

// NN_EXPORT int nn_poll (struct nn_pollfd *fds, int nfds, int timeout);
  function nn_poll (var fds: nn_pollfd; nfds: cint; timeout: cint): cint; cdecl; external LIB_NANO;
  {**************************************************************************** }
  {  Built-in support for devices.                                              }
  {**************************************************************************** }


//  NN_EXPORT int nn_device (int s1, int s2);
    function nn_device (s1, s2: cint): cint; cdecl; external LIB_NANO;
  {**************************************************************************** }
  {  Statistics.                                                                }
  {**************************************************************************** }
  {  Transport statistics   }

  const
    NN_STAT_ESTABLISHED_CONNECTIONS = 101;
    NN_STAT_ACCEPTED_CONNECTIONS = 102;
    NN_STAT_DROPPED_CONNECTIONS = 103;
    NN_STAT_BROKEN_CONNECTIONS = 104;
    NN_STAT_CONNECT_ERRORS = 105;
    NN_STAT_BIND_ERRORS = 106;
    NN_STAT_ACCEPT_ERRORS = 107;
    NN_STAT_CURRENT_CONNECTIONS = 201;
    NN_STAT_INPROGRESS_CONNECTIONS = 202;
    NN_STAT_CURRENT_EP_ERRORS = 203;
  {  The socket-internal statistics   }
    NN_STAT_MESSAGES_SENT = 301;
    NN_STAT_MESSAGES_RECEIVED = 302;
    NN_STAT_BYTES_SENT = 303;
    NN_STAT_BYTES_RECEIVED = 304;
  {  Protocol statistics   }
    NN_STAT_CURRENT_SND_PRIORITY = 401;

    function nn_get_statistic (s, stat: cint): QWord; cdecl; external LIB_NANO;

{ C++ end of extern C conditionnal removed }

implementation
(*
  { was #define dname def_expr }
  function NN_MSG : csize_t;
    begin
      NN_MSG:=csize_t(-(1));
    end;

  { was #define dname(params) para_def_expr }
  { argument types are unknown }
  { return type might be wrong }
  function NN_CMSG_ALIGN_(len : longint) : longint;
  begin
    // #define NN_CMSG_ALIGN_(len) \ (((len) + sizeof (size_t) - 1) & (size_t) ~(sizeof (size_t) - 1))

  NN_CMSG_ALIGN_:=(len + sizeof(csize_t) -1) and (csize_t(not(sizeof(csize_t)-1)));
  end;

{ was #define dname(params) para_def_expr }
{ argument types are unknown }
{ return type might be wrong }
function NN_CMSG_FIRSTHDR(mhdr : longint) : longint;
begin
  // NN_CMSG_FIRSTHDR := nn_cmsg_nxthdr_(Pnn_msghdr.mhdr, NULL);
end;

{ was #define dname(params) para_def_expr }
{ argument types are unknown }
{ return type might be wrong }
function NN_CMSG_NXTHDR(mhdr,cmsg : longint) : longint;
begin
     // NN_CMSG_NXTHDR:=nn_cmsg_nxthdr_(Pnn_msghdr(mhdr),Pnn_cmsghdr(cmsg));
end;

{ was #define dname(params) para_def_expr }
{ argument types are unknown }
function NN_CMSG_DATA(cmsg : longint) : Pbyte;
begin
  //NN_CMSG_DATA:=Pbyte((Pnn_cmsghdr(cmsg))+1);
end;
*)


end.

