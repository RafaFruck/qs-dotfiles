import Quickshell
import QtQuick
import QtCore

QtObject {
  id: root

  property bool launcherVisible: false
  property var recentIds: []

  property Settings _settings: Settings {
    category: "AppLauncher"
    property string recentIdsSerialized: "[]"
  }

  Component.onCompleted: {
    try {
      recentIds = JSON.parse(_settings.recentIdsSerialized) || []
    } catch(e) {
      recentIds = []
    }
  }

  function toggle() { launcherVisible = !launcherVisible }
  function show() { launcherVisible = true }
  function hide() { launcherVisible = false }

  function recordLaunch(id) {
    var list = recentIds.slice()
    var idx = list.indexOf(id)

    if (idx !== -1) {
      list.splice(idx, 1)
    }
    list.unshift(id)

    if (list.length > 12) {
      list = list.slice(0, 12)
    }

    recentIds = list
    _settings.recentIdsSerialized = JSON.stringify(list)
  }

  function clearRecents() {
    recentIds = []
    _settings.recentIdsSerialized = "[]"
  }
}

