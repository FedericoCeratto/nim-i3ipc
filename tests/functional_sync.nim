## i3ipc client - sync functional tests
## Copyright 2017 Federico Ceratto <federico.ceratto@gmail.com>
## Released under LGPLv3 License, see LICENSE file

import unittest,
  json

import i3ipc

suite "sync functional":
  setup:
    let i3 = newI3Conn()

  teardown:
    i3.close()

  test "get_version":
    check i3.get_version().len == 5

  test "get_tree":
    check i3.get_tree().len > 3

  test "get_focused_window":
    let w = i3.get_tree().get_focused_window()
    check w["focused"].getBVal() == true

  test "get_outputs":
    check i3.get_outputs().len > 1

  test "get_workspaces":
    check i3.get_workspaces().len > 1

  test "get_bar_config":
    check i3.get_bar_config().len > 0

  test "subscribe":
    i3.subscribe(I3Event.window)
