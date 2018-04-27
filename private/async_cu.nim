## i3ipc client - async connectUnix
## Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
## Released under LGPLv3 License, see LICENSE file

from asyncnet import newAsyncSocket, AsyncSocket, getFd
from nativesockets import toInt
from posix import Sockaddr_un, Sockaddr_un_path_length, SockAddr, Socklen
import nativesockets
from os import raiseOSError, osLastError

proc makeUnixAddr(path: string): Sockaddr_un =
  result.sun_family = AF_UNIX.toInt
  if path.len >= Sockaddr_un_path_length:
    raise newException(ValueError, "socket path too long")
  copyMem(addr result.sun_path, path.cstring, path.len + 1)

proc connectUnix*(socket: AsyncSocket, path: string) =
  ## Connects to Unix socket on `path`.
  ## This only works on Unix-style systems: Mac OS X, BSD and Linux
  when not defined(nimdoc):
    var socketAddr = makeUnixAddr(path)
    if socket.getFd.connect(cast[ptr SockAddr](addr socketAddr), sizeof(socketAddr).Socklen) != 0'i32:
      raiseOSError(osLastError())
