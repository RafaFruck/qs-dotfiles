import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "config.js" as Config

Scope {
  id: root
  property bool centerOpen

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

  ListModel {
    id: history
  }

  NotificationServer {
    id: server
    actionsSupported: true
    bodySupported: true
    imageSupported: true

    onNotification: n => {
      history.insert(0, {
        notificationObject: n,
        summary: n.summary,
        body: n.body,
        appName: n.appName,
        urgency: n.urgency,
        time: Qt.formatDateTime(new Date(), "HH:mm:ss"),
        popupVisible: true
      })
      n.tracked = true
    }
  }

  IpcHandler {
    target: "notifications"
    function toggle(): void { root.centerOpen = !root.centerOpen }
    function show() : void { root.centerOpen = true }
    function hide() : void { root.centerOpen = false }
  }

  // Notification pop-up window
  PanelWindow {
    id: popupWindow
    anchors {
      top: true
      right: true
    }

    margins {
      top: Config.bar.height + 10 
      right: 10 
    }
    
    implicitWidth: 380
    implicitHeight: 1080
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: true

    ListView {
      id: popupListView
      anchors.fill: parent
      model: history
      spacing: 10
      clip: true
      interactive: false

      delegate: Rectangle {
        id: card
        visible: model.popupVisible
        width: ListView.view.width
        height: visible ? (layout.implicitHeight + 24) : 0
        color: "transparent"
        
        property bool animateIn: false
        property bool wasAnimated: false

        Component.onCompleted: {
          animateIn = true
          wasAnimated = true
        }

        Timer {
          running: card.visible && model.urgency != NotificationUrgency.Critical
          interval: Config.notifications.timeout
          onTriggered: {
            card.animateIn = false
          }
        }

        Rectangle {
          id: visualCard
          width: parent.width
          height: layout.implicitHeight + 24
          color: popupMouseArea.containsMouse ? root.colBgDark : root.colBg 
          border.width: card.visible ? 2 : 0
          border.color: popupMouseArea.containsMouse 
            ? (model.urgency === NotificationUrgency.Critical ? root.colOrange : root.colBlue)
            : (model.urgency === NotificationUrgency.Critical ? root.colRed : root.colPurple)

          x: card.animateIn ? 0 : 100
          opacity: card.animateIn ? 1.0 : 0.0

          Behavior on x {
            NumberAnimation {
              easing.type: card.animateIn ? Easing.InExpo : Easing.InOutSine
              duration: card.animateIn ? 350 : 250
            }
          }

          Behavior on opacity {
            NumberAnimation {
              easing.type: card.animateIn ? Easing.InExpo : Easing.OutSine
              duration: card.animateIn ? 350 : 250
            }
	  }

	  Behavior on color {
	    ColorAnimation {
	      easing.type: Easing.InOutSine
	      duration: 100 
	    }
	  }
	  
	  Behavior on border.color {
	    ColorAnimation {
	      easing.type: Easing.InOutSine
	      duration: 100 
	    }
	  }

          onOpacityChanged: {
            if (opacity === 0.0 && !card.animateIn && card.wasAnimated) {
              model.popupVisible = false
            }
          }

          RowLayout {
            id: layout 
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            spacing: 10

            Image {
              Layout.preferredHeight: 36
              Layout.preferredWidth: 36
              Layout.alignment: Qt.AlignTop
              fillMode: Image.PreserveAspectFit
              visible: source.toString() !== ""
              source: (model.notificationObject.image || model.notificationObject.appIcon || "")
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                text: model.appName ? model.appName : "System"
                color: root.colMuted
                font.family: Config.notifications.fontFamily
                font.pixelSize: Config.notifications.fontSize - 3
                font.bold: true
              }

              Text {
                Layout.fillWidth: true
                text: model.summary
                color: popupMouseArea.containsMouse ? root.colPurple : root.colCyan
                font.family: Config.notifications.fontFamily
                font.pixelSize: Config.notifications.fontSize
                font.bold: true
                elide: Text.ElideRight
		
		Behavior on color {
		  ColorAnimation {
		    easing.type: Easing.InOutSine
		    duration: 100 
		  }
		}
              }

              Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: model.body
                color: root.colFg
                font.family: Config.notifications.fontFamily
                font.pixelSize: Config.notifications.fontSize - 1
                wrapMode: Text.WordWrap
              }
            }
          }

          MouseArea {
            id: popupMouseArea
            anchors.fill: parent
	    hoverEnabled: true
	    cursorShape: Qt.PointingHandCursor
            onClicked: {
              var notif = model.notificationObject;
              if (notif && notif.actions) {
                for (var action of notif.actions) {
                  if (action.identifier === "default") {
                    action.invoke()
                    break
                  }
                }
              }
              card.animateIn = false;
            }
          }
        }
      }
    }
  }

  //Notification Center
  PanelWindow {
    id: centerWindow
    
    visible: root.centerOpen || (centerVisualPanel.opacity > 0.0)
    
    anchors { top: true; right: true }
    margins { 
      top: Config.bar.height + 10
      right: 0 
    }
    
    implicitWidth: 480
    implicitHeight: 450
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    property bool animateCenterIn: false

    onVisibleChanged: {
      if (root.centerOpen) {
        centerWindow.animateCenterIn = true
      }
    }

    Binding {
      target: centerWindow
      property: "animateCenterIn"
      value: root.centerOpen 
    }

    Rectangle {
      id: centerVisualPanel
      width: 380
      height: parent.height 
      color: root.colBg
      border.width: 2
      border.color: root.colPurple

      anchors.right: parent.right
      anchors.rightMargin: centerWindow.animateCenterIn ? 10 : -100
      anchors.top: parent.top

      opacity: centerWindow.animateCenterIn ? 1.0 : 0.0

      Behavior on anchors.rightMargin {
        NumberAnimation {
          easing.type: centerWindow.animateCenterIn ? Easing.InExpo : Easing.InOutSine
          duration: centerWindow.animateCenterIn ? 350 : 250
        }
      }

      Behavior on opacity {
        NumberAnimation {
          easing.type: centerWindow.animateCenterIn ? Easing.InExpo : Easing.OutSine
          duration: centerWindow.animateCenterIn ? 350 : 250
        }
      }

      ColumnLayout {
        id: centerCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
          Layout.fillWidth: true

          Text {
            Layout.fillWidth: true
            text: "Notifications"
            color: root.colCyan
            font.family: Config.notifications.fontFamily
            font.pixelSize: Config.notifications.fontSize + 2
            font.bold: true
          }

          Text {
            text: "Clear all"
            visible: history.count > 0
            color: root.colRed
            font.family: Config.notifications.fontFamily
            font.pixelSize: Config.notifications.fontSize - 1
            MouseArea {
	      cursorShape: Qt.PointingHandCursor
              anchors.fill: parent
              onClicked: {
                for (var i = 0; i < history.count; i++) {
                  var item = history.get(i)
                  if (item.notificationObject) {
                    item.notificationObject.dismiss();
                  }
                }
                history.clear();
              }
            }
          }
        }

        ListView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: history
          clip: true
          spacing: 8

          ScrollBar.vertical: ScrollBar {
            id: verticalScrollBar
            policy: ScrollBar.AsNeeded
            active: true

            contentItem: Rectangle {
              implicitWidth: 4
              color: root.colPurple
              opacity: verticalScrollBar.visualPosition > 0 ? 0.7 : 0.0
            }
          }

          Text {
            anchors.centerIn: parent
            text: "No notifications"
            color: root.colFg
            visible: history.count === 0
            font.family: Config.notifications.fontFamily
          }

          delegate: Rectangle {
            id: historyCard
            width: ListView.view.width - (verticalScrollBar.visible ? 8 : 0)
            height: historyLayout.implicitHeight + 16
            color: "transparent"
            border.width: 2
            border.color: centerMouseArea.containsMouse ? root.colBlue : root.colPurple
	    
	    Behavior on border.color {
	      ColorAnimation {
		easing.type: Easing.InOutSine
		duration: 100 
	      }
	    }

            MouseArea {
              id: centerMouseArea
              anchors.fill: parent
	      cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: {
                var item = history.get(index);
                if (item && item.notificationObject) {
                  var notif = item.notificationObject;
                  if (notif.actions) {
                    var actionTriggered = false;
                    for (var action of notif.actions) {
                      if (action.identifier === "default") {
                        action.invoke();
                        actionTriggered = true;
                        break;
                      }
                    }
                    if (!actionTriggered && notif.actions.length > 0) {
                      notif.actions.get(0).invoke();
                      actionTriggered = true;
                    }
                  }

                  if (!actionTriggered) {
                    var appLabel = model.appName ? model.appName : "System";
                    var rawText = appLabel + ": " + model.summary + "\n" + model.body;
                    var terminalCmd = "kitty";
                    var zshCommand = "echo -e " + Quickshell.arguments.quote(rawText) + " | less -RX ";
                    Quickshell.Process.run(["kitty", "zsh", "-c", zshCommand]);
                  }
                }
                if (item) {
                  item.popupVisible = false;
                }
                history.remove(index);
              }
            }

            RowLayout {
              id: historyLayout
              anchors.fill: parent
              anchors.margins: 8

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: model.summary
                    color: centerMouseArea.containsMouse ? root.colPurple : root.colCyan
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
		    
		    Behavior on color {
		      ColorAnimation {
			easing.type: Easing.InOutSine
			duration: 100 
		      }
		    }
                  }
                  Text {
                    text: model.time
                    color: centerMouseArea.containsMouse ? root.colCrystalGreen : root.colSkyBlue
                    wrapMode: Text.WordWrap
                    font.pixelSize: Config.notifications.fontSize - 1
		      
		    Behavior on color {
		      ColorAnimation {
			easing.type: Easing.InOutSine
			duration: 100 
		      }
		    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: model.body
                  color: root.colFg
                  wrapMode: Text.WordWrap
                  font.pixelSize: Config.notifications.fontSize - 1
                }
              }

              Text {
                text: ""
                color: root.colRed
                opacity: 0.8
                font.family: Config.notifications.fontFamily
                Layout.alignment: Qt.AlignTop
                font.bold: centerMouseArea.containsMouse

                MouseArea {
                  anchors.fill: parent
		  cursorShape: Qt.CrossCursor
                  onClicked: {
                    if (model.notificationObject) {
                      model.notificationObject.dismiss();
                    }
                    history.remove(index);
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

