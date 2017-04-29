## i3ipc client - unit tests
## Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
## Released under LGPLv3 License, see LICENSE file

import unittest

import i3ipc

suite "unit test":
  test "pack":
    check pack(I3MessageType.get_tree, "") == "i3-ipc\0\0\0\0\4\0\0\0"

  test "unpack":
    const r = "i3-ipc8\x03\x00\x00\x03\x00\x00\x80"
    let m = unpack(r)
    check m.payload_size == 824
    check m.mtype_num == 2147483651.uint32
    check m.mtype == I3MessageType.command
