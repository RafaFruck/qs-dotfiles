//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "app_launcher"

Scope {
  id: root

  Notifications { }

  ShellRoot {
    Variants {
      model: Quickshell.screens
      Bar { }
    }
  }

  AppLauncher { }
}
