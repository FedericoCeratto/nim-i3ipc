## i3ipc client - async functional tests
## Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
## Released under LGPLv3 License, see LICENSE file
import asyncdispatch, unittest, json
import tables
import algorithm
from sequtils import toSeq

import i3ipc

suite "async functional":
  setup:
    let i3 = newAsyncI3Conn()

  teardown:
    i3.close()

  test "get_version":
    check waitFor(i3.get_version).len == 5

  test "get_tree":
    check waitFor(i3.get_tree).len > 3

  test "get_outputs":
    check waitFor(i3.get_outputs).len > 1

  test "get_workspaces":
    check waitFor(i3.get_workspaces).len > 1

  test "get_bar_config":
    check waitFor(i3.get_bar_config).len > 0

  test "subscribe and gather events":
    var incoming_events_count = 0
    proc count_incoming_events(self: AsyncI3Conn) {.async.} =
      await self.subscribe(I3Event.window)
      while true:
        let j = await self.receive_msg()
        incoming_events_count.inc
        await self.subscribe(I3Event.window)

    asyncCheck i3.count_incoming_events()
    waitFor sleepAsync 1000
    check incoming_events_count >= 0
    echo "       ", $incoming_events_count, " events received"
