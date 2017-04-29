## i3ipc client
## Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
## Released under LGPLv3 License, see LICENSE file

import asyncdispatch,
  asyncnet,
  endians,
  json,
  osproc,
  strutils

import nativesockets
from nativesockets import AF_UNIX, SOCK_STREAM, IPPROTO_IP
from net import Socket, newSocket, connectUnix, close, recv

import private/async_cu

const header = "i3-ipc"

type
  I3Conn* = ref object of RootObj
    sock: Socket

  AsyncI3Conn* = ref object of RootObj
    sock: AsyncSocket

  I3Event* {.pure.} = enum
    workspace = 1, output = 2, mode = 4, window = 8,
    barconfigupdate = 16, binding = 32

  I3MessageType* {.pure.} = enum
    command, get_workspaces, subscribe, get_outputs, get_tree,
    get_marks, get_bar_config, get_version

  PackedMsg {.packed.} = object
    head: array[6, char]
    payload_len: uint32
    msg_type: uint32
    msg: seq[char]

  MsgIntro* = object
    payload_size*: int
    mtype_num*: uint32
    mtype*: I3MessageType

proc get_i3ipc_socket_path*(): string =
  ## Get socket path by running i3 --get-socketpath
  execProcess("i3 --get-socketpath").strip()

proc newI3Conn*(path=""): I3Conn =
  ## Open connection to i3
  var path = path
  if path == "":
    path = get_i3ipc_socket_path()

  result = I3Conn()
  result.sock = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  result.sock.connectUnix(path)

proc newAsyncI3Conn*(path=""): AsyncI3Conn =
  ## Open async connection to i3
  var path = path
  if path == "":
    path = get_i3ipc_socket_path()

  result = AsyncI3Conn()
  result.sock = newAsyncSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  result.sock.connectUnix(path)

proc close*(self: I3Conn | AsyncI3Conn) =
  ## Close connection
  self.sock.close()

proc read_le_uint32(r: string): uint32 =
  littleEndian32(addr(result), unsafeAddr r[0])

proc to_le(i: int): string =
  result = "    "
  littleEndian32(result.cstring, unsafeAddr i)

proc pack*(msg_type: I3MessageType, msg: string): string =
  ## Pack message
  header & msg.len.to_le & msg_type.int.to_le & msg

proc send*(self: I3Conn, msg_type: I3MessageType, msg: string) {.multisync.} =
  ## Send a message
  let m = pack(msg_type, msg)
  when self.sock is Socket:
    net.send(self.sock, m)
  else:
    await self.sock.send(m)

proc unpack*(r: string): MsgIntro =
  ## Unpack initial part of a message
  doAssert r[0..5] == header
  result.payload_size = int read_le_uint32 r[6..9]
  result.mtype_num = read_le_uint32 r[10..13]
  try:
    result.mtype = I3MessageType read_le_uint32 r[10..13]
  except:
    discard

proc receive_msg*(self: I3Conn, timeout= -1): JsonNode =
  ## Receive one message and parse it into JsonNode
  # receive 14 bytes
  var r = self.sock.recv(14)
  assert r.len == 14
  let mi = unpack(r)
  r = self.sock.recv(mi.payload_size)
  doAssert r.len == mi.payload_size
  return parseJson r

proc receive_msg*(self: AsyncI3Conn, timeout= -1): Future[JsonNode] {.async.} =
  ## Receive one message and parse it into JsonNode
  # receive 14 bytes
  var r:string
  r = await self.sock.recv(14)
  assert r.len == 14
  let mi = unpack(r)
  # receive remaining data
  r = await self.sock.recv(mi.payload_size)
  doAssert r.len == mi.payload_size
  return parseJson r

proc send_recv*(self: I3Conn, msg_type: I3MessageType, msg: string): JsonNode =
  ## Send a message and wait for a reply
  let m = pack(msg_type, msg)
  when self.sock is Socket:
    net.send(self.sock, m)
    return self.receive_msg()
  else:
    await self.sock.send(m)
    return await self.receive_msg()

proc send_recv*(self: AsyncI3Conn, msg_type: I3MessageType, msg: string): Future[JsonNode] {.async.} =
  ## Send a message and wait for a reply
  let m = pack(msg_type, msg)
  await self.sock.send(m)
  return await self.receive_msg()

proc get_tree*(self: I3Conn | AsyncI3Conn): Future[JsonNode] {.multisync.} =
  ## Get tree
  return await self.send_recv(I3MessageType.get_tree, "")

proc get_bar_config*(self: I3Conn | AsyncI3Conn): Future[JsonNode] {.multisync.} =
  ## Get bar config
  return await self.send_recv(I3MessageType.get_bar_config, "")

proc get_outputs*(self: I3Conn | AsyncI3Conn): Future[JsonNode] {.multisync.} =
  ## Get outputs
  return await self.send_recv(I3MessageType.get_outputs, "")

proc get_workspaces*(self: I3Conn | AsyncI3Conn): Future[JsonNode] {.multisync.} =
  ## Get workspaces
  return await self.send_recv(I3MessageType.get_workspaces, "")

proc get_version*(self: I3Conn | AsyncI3Conn): Future[JsonNode] {.multisync.} =
  ## Get version
  return await self.send_recv(I3MessageType.get_version, "")

proc subscribe*(self: I3Conn | AsyncI3Conn, event: I3Event) {.multisync.} =
  ## Subscribe to notifications
  let selector = """["$#"]""" % $event
  let r = await self.send_recv(I3MessageType.subscribe, selector)
  doAssert r["success"].getBVal() == true


proc filter_dict(j: JsonNode, key: string, value: bool): seq[JsonNode] =
  ## Filter dict by key and value
  result = @[]
  case j.kind
  of JObject:
    for k, v in pairs j:
      if k == key and v.getBVal() == value:
        result.add j
      else:
        result.add filter_dict(v, key, value)
  of JArray:
    for i in j:
      result.add filter_dict(i, key, value)
  else:
    discard

proc get_focused_window*(j: JsonNode): JsonNode =
  ## Extract focused window: i3.get_tree().get_focused_window()
  j.filter_dict("focused", true)[0]
