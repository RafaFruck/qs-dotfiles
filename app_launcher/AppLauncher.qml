import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../config.js" as Config

PanelWindow {
  id: root

  property var screen
  property color colBg: Config.colors.bg
  property color colBgDark: Config.colors.bgDark
  property color colFg: Config.colors.fg
  property color colMuted: Config.colors.muted
  property color colRed: Config.colors.red
  property color colGreen: Config.colors.green
  property color colSkyBlue: Config.colors.skyBlue
  property color colOrange: Config.colors.orange
  property color colTurquoise: Config.colors.turquoise
  property color colBlue: Config.colors.blue
  property color colYellow: Config.colors.yellow
  property color colCrystalGreen: Config.colors.crystalGreen
  property color colPurple: Config.colors.purple
  property color colCyan: Config.colors.cyan

  property color accentIcon: Config.colors.purple
  property color accentFill: Config.colors.bg
  property int panelHeight: 120 + Math.min(filteredApps.length, Config.appLauncher.maxAppsVisible) * Config.appLauncher.itemHeight

  property bool isLauncherVisible: false

  IpcHandler {
    target: "applauncher"
    function toggle() { 
      root.isLauncherVisible = !root.isLauncherVisible    
    }
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: root.isLauncherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "qs-applauncher"

  anchors {
    top: true
    bottom: true 
    left: true
    right: true 
  }

  mask: Region {
    item: root.isLauncherVisible ? maskCover : null 
  }

  Item {
    id: maskCover
    anchors.fill: parent 
  }

  color: "transparent"

  property string searchQuery: ""
  property int selectedIndex: 0
  readonly property bool isSelected: searchQuery.trim() !== ""
  readonly property bool isSearching: searchQuery.trim() !== ""

  property var filteredApps: {
    var q = searchQuery.trim().toLowerCase()
    var vals = DesktopEntries.applications.values
    if (q !== "") {
      return vals.filter(function (e) {
        if (e.name.toLowerCase().indexOf(q) !== -1) return true
        if (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1) return true
        for (var i = 0; i < e.keywords.length; i++)
          if (e.keywords[i].toLowerCase().indexOf(q) !== -1) return true
        return false
      }).sort(function (a, b) { return a.name.localeCompare(b.name) })
    }
    var recent = AppLauncherState.recentIds || []
    return vals.slice().sort(function (a, b) {
      var aid = recent.indexOf(a.id); var bid = recent.indexOf(b.id)
      if (aid !== -1 && bid !== -1) return aid - bid
      if (aid !== -1) return -1
      if (bid !== -1) return 1
      return a.name.localeCompare(b.name)
    })
  }

  onFilteredAppsChanged: selectedIndex = 0
  function launchEntry(entry) {
    AppLauncherState.recordLaunch(entry.id)
    entry.execute()
    AppLauncherState.hide()
  }

  function navigate(delta) {
    if (filteredApps.length === 0) return
    selectedIndex = (selectedIndex + delta + filteredApps.length) % filteredApps.length
    listView.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  Connections {
    target: AppLauncherState
    function onVisibleChanged() {
      if (root.isLauncherVisible) {
	searchInput.text = ""
	root.searchQuery = ""
	root.selectedIndex = 0
	searchInput.forceActiveFocus()
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.isLauncherVisible
    onClicked: root.isLauncherVisible = false
  }

  Rectangle {
    id: panel
    width: Config.appLauncher.panelWidth
    height: root.panelHeight

    Behavior on height { 
      NumberAnimation {
	duration: 500
	easing.type: Easing.InOutSine 
      } 
    }
    
    clip: true

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    color: root.colBgDark
    opacity: 0.8
    border.color: root.colPurple
    border.width: 2

    transform: Translate {
      y: root.isLauncherVisible ? 0 : root.panelHeight
      Behavior on y {
	NumberAnimation {
	  duration: 500
	  easing.type: Easing.InOutSine 
	} 
      }
    }

    Column {

      anchors.top: parent.top
      anchors.topMargin: 10
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 10
      
      spacing: 0 

      Rectangle {
	width: parent.width
	height: 66 
	color: root.colBg

        Rectangle {
	  anchors.fill: parent
	  color: "transparent"
	  border.color: root.colPurple
	  border.width: 2
          opacity: searchInput.activeFocus ? 0.55 : 0 
	  Behavior on opacity {
	    NumberAnimation {
	      duration: 150 
	    } 
	  }
	}

        Row {
	  anchors { 
	    fill: parent
	    leftMargin: 15 
	    rightMargin: 10 
	  }

	  spacing: 10 

          Text {
	    text: ""
	    color: root.colMuted
	    opacity: 0.8
	    font.pixelSize: Config.appLauncher.fontSize
	    font.family: Config.appLauncher.fontFamily
            anchors.verticalCenter: parent.verticalCenter 
	  }

          Item {
	    width: parent.width - 60
	    height: parent.height

            Text {
	      anchors.fill: parent
	      text: root.isSearching ? "" : "Search apps…"
	      color: root.colMuted
	      opacity: 0.6
	      font.pixelSize: Config.appLauncher.fontSize
	      font.family: Config.appLauncher.fontFamily
	      verticalAlignment: Text.AlignVCenter
	      visible: searchInput.text === ""
	    }

            TextInput {
	      id: searchInput
	      anchors.fill: parent
	      color: root.colFg
	      selectionColor : root.accentFill
	      font.pixelSize: Config.appLauncher.fontSize
	      font.family: Config.appLauncher.fontFamily
	      verticalAlignment: Text.AlignVCenter
	      clip: true
              onTextChanged: root.searchQuery = text 

              Keys.onPressed: function(event) {
		if (event.key === Qt.Key_Down) {
		  root.navigate(1)
		  event.accepted = true 
		}
		else if (event.key === Qt.Key_Up) {
		  root.navigate(-1)
		  event.accepted = true 
		}
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
		  if (root.filteredApps.length > 0) 
		    root.launchEntry(root.filteredApps[root.selectedIndex])
		  event.accepted = true
		} else if (event.key === Qt.Key_Escape) {
		  root.isLauncherVisible = false
		  event.accepted = true 
		}
              }
            }
          }
        }
      }

      Item { 
	width: 1
	height: 12
      }

      ListView {
	id: listView
	width: parent.width 
        height: Math.min(filteredApps.length, Config.appLauncher.maxAppsVisible) * Config.appLauncher.itemHeight
	model: root.filteredApps
	clip: true
	interactive: false

        MouseArea {
          anchors.fill: parent 
	  onWheel: function (wheel) {
	    if (wheel.angleDelta.y < 0) root.navigate(1)
	    else root.navigate(-1) 
	  }
	}

        Text {
	  anchors.centerIn: parent
	  visible: root.filteredApps.length === 0
	  text: "No apps found"
	  color: root.colMuted
	  opacity: 0.6
	  font.pixelSize: Config.appLauncher.fontSize
	  font.family: Config.appLauncher.fontFamily
        }
        
        delegate: Item {
	  id: appRow
	  width: listView.width
	  height: Config.appLauncher.itemHeight 
          readonly property bool sel: root.selectedIndex === index 
          readonly property bool isRecent: {
	    if (root.isSearching || !AppLauncherState.recentIds) {
	      return false;
	    }
	    return AppLauncherState.recentIds.indexOf(modelData.id) !== -1;
	  }

          Rectangle {
	    anchors {
	      fill: parent
	      topMargin: 2 
	      bottomMargin: 2
	    }
            color: appRow.sel ? colBg : "transparent"
	    Behavior on color { 
	      ColorAnimation {
		duration: 100 
	      } 
	    }

            Row {
	      anchors {
		fill: parent
		leftMargin: 10
		rightMargin: 10 
	      }
	      spacing: 10

              Rectangle {
		width: 54
		height: 54
		anchors.verticalCenter: parent.verticalCenter 

                color: appRow.sel ? root.accentIcon : Qt.rgba(1, 1, 1, 0.08)
		Behavior on color { 
		  ColorAnimation {
		    duration: 100 
		  } 
		}

                Image {
		  id: appIcon
		  anchors.centerIn: parent
		  width: 48
		  height: 48
		  
		  sourceSize.width: 64
		  sourceSize.height: 64
		  source: modelData.icon !== "" ? Quickshell.iconPath(modelData.icon, true) : ""
		  
		  smooth: true
		  mipmap: true
		}

                Text {
		  anchors.centerIn: parent
		  visible: appIcon.status !== Image.Ready 
                  text: modelData.name.charAt(0).toUpperCase()
		  font.pixelSize: Config.appLauncher.fontSize + 2
		  font.family: Config.appLauncher.fontFamily
		  font.bold: true 
                  color: appRow.sel ? root.colCyan : root.colMuted 
		  Behavior on color {
		    ColorAnimation {
		      duration: 100
		      easing.type: Easing.InOutSine 
		    } 
		  }
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter 
                Text {
		  text: modelData.name;
		  font.family: Config.appLauncher.fontFamily;
		  font.pixelSize: Config.appLauncher.fontSize 
		  font.weight: appRow.sel ? Font.DemiBold : Font.Normal
		  color: appRow.sel ? root.colFg : root.colMuted 

		  Behavior on color {
		    ColorAnimation {
		      duration: 100 
		    } 
		  }
		}

                Row {
                  visible: appRow.isRecent || modelData.genericName !== ""
                  Rectangle {
		    visible: appRow.isRecent
		    width: recentLabel.width + 12
		    height: 21; color: root.colBlue
		    opacity: 0.22
		    anchors.verticalCenter: parent.verticalCenter 

                    Text {
		      id: recentLabel
		      anchors.centerIn: parent
		      text: "Recent"
		      font.family: Config.appLauncher.fontFamily
		      font.pixelSize: Config.appLauncher.fontSize - 10
		      color: root.colBlue 
                    }
                  }
                  Text {
		    visible: modelData.genericName !== ""
		    text: modelData.genericName 
		    font.family: Config.appLauncher.fontFamily
		    font.pixelSize: Config.appLauncher.fontSize - 8
		    color: root.colFg
		    opacity: 0.35
		    anchors.verticalCenter: parent.verticalCenter 
                  }
                }
              }
            }

            MouseArea {
	      anchors.fill: parent
	      hoverEnabled: true
	      onEntered: root.selectedIndex = index 
              onClicked: root.launchEntry(modelData)
	      onWheel: function(wheel) {
		if (wheel.angleDelta.y < 0) root.navigate(1)
		else root.navigate(-1) 
	      }
            }
          }
        }
      }
    }

    Item {
      width: 1
      height: 6
    }
  }
}

