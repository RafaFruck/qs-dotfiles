import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "config.js" as Config

PanelWindow {
  id: root
  required property var modelData
  screen: modelData

				// Variables
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
  property color colWhite: Config.colors.white

  property string fontFamily: Config.bar.fontFamily
  property int fontSize: Config.bar.fontSize
  
  property int cpuUsage: 0
  property var lastCpuIdle: 0
  property var lastCpuTotal: 0

  property int gpuUsage: 0

  property int cpuTemp: 0
  
  property int gpuTemp: 0

  property int volumeLevel: 0
  property bool isMuted: false

  property int memUsage: 0

  property string activeWindow: "Window"

  property string powerProfile: "balanced"
  property string powerIcon: "󰾅 "

  property string mprisStatus: "Stopped"

  property int batteryLevel: 0
  property string batteryStatus: "Unknown"

  property real lastRx: 0
  property real lastTx: 0
  property real rxSpeed: 0
  property real txSpeed: 0

  property var batteryIconsCharging:    ["󰢟 ", "󰢜 ", "󰂆 ", "󰂇 ", "󰂈 ", "󰢝 ", "󰂉 ", "󰢞 ", "󰂊 ", "󰂋 ", "󰂅 "]
  property var batteryIconsDischarging: ["󰁺 ", "󰁺 ", "󰁻 ", "󰁼 ", "󰁽 ", "󰁾 ", "󰁿 ", "󰂀 ", "󰂁 ", "󰂂 ", "󰁹 "]

				  //Processes
  // CPU tracker
  Process {
    id: cpuProc
    command: [
      "zsh", "--no-rcs", "-c",
      "head -1 /proc/stat"
    ]
  
    stdout: SplitParser {
      onRead: data => {
        var p = data.trim().split(/\s+/)
        var idle = parseInt(p[4]) + parseInt(p[5])
        var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
        if (lastCpuTotal > 0) {
  	cpuUsage = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
        }
        lastCpuTotal = total
        lastCpuIdle = idle
      }
    }
    Component.onCompleted: running = true
  }
  
  // Memory (RAM) tracker
  Process {
    id : memProc
    command: [
      "zsh", "--no-rcs", "-c",
      "free | grep Mem"
    ]

    stdout: SplitParser {
      onRead: data => {
	var parts = data.trim().split(/\s+/)
	var total = parseInt(parts[1]) || 1
	var used = parseInt(parts[2]) || 0
	memUsage = Math.round(100 * used / total)
      }
    }
    Component.onCompleted: running = true
  }

  // Volume tracker
  Process {
    id: volumeProc
    command: [
      "zsh", "--no-rcs", "-c",
      "wpctl get-volume @DEFAULT_AUDIO_SINK@"
    ]

    stdout: SplitParser {
      onRead: data => {
	if (data && data.trim()) {
	  var input = data.trim()            
	  var match = input.match(/Volume:\s*([0-9.]+)/)
	  if (match) {
	      volumeLevel = Math.round(parseFloat(match[1]) * 100)
	    }
	  isMuted = input.includes("[MUTED]")
	}
      }
    }
    Component.onCompleted: running = true
  }

  // Active Window Tracker
  Process {
    id: windowProc
    command: [ 
      "zsh", "--no-rcs", "-c", 
      "niri msg --json windows | jq -r '.[] | select(.is_focused == true) | .title' 2>/dev/null" 
    ]

    stdout: SplitParser {
      onRead: data => {
        var cleanedData = data ? data.trim() : ""
        if (cleanedData === "" || cleanedData === "null") return;
          if (cleanedData.length <= 65) {
            activeWindow = cleanedData
	    return
          }
	  var parts = cleanedData.split(/\s+[-—–|]\s+/)
	  if (parts.length >= 2) {
	    var appName = parts[parts.length - 1] 
            parts.pop() 
            var pageTitle = parts.join(" - ")
            var maxPageLength = 65 - appName.length - 1 
            if (maxPageLength < 65) maxPageLength = 65 
            if (pageTitle.length > maxPageLength) {
              pageTitle = pageTitle.substring(0, maxPageLength) + "…"
            }
	    activeWindow = pageTitle + " — " + appName
	  } else {
          activeWindow = cleanedData.substring(0, 64) + "…"
        }
      }
    }    
    Component.onCompleted: running = true
  } 

  // GPU tracker
  Process {
    id: gpuProc
    command: [
      "zsh", "--no-rcs", "-c",
      "/run/wrappers/bin/intel_gpu_top -J -o - -s 2000 2>/dev/null | jq --unbuffered --stream -c 'select(.[0][1]==\"engines\" and .[0][2]==\"Render/3D\" and .[0][3]==\"busy\") | .[1]'"
    ]
    
    running: true

    stdout: SplitParser {
      onRead: data => {
        if (data && data.trim()) {
          var busyValue = parseFloat(data.trim())
          
          if (!isNaN(busyValue)) {
            gpuUsage = Math.round(busyValue)
          }
        }
      }
    }
  }

  // CPU Temperature Tracker
  Process {
    id: cpuTempProc
    command: [ 
      "zsh", "--no-rcs", "-c",
      "cat /sys/class/thermal/thermal_zone1/temp" 
    ]

    stdout: SplitParser {
      onRead: data => {
        if (data && data.trim()) {
          cpuTemp = Math.round(parseInt(data.trim()) / 1000)
        }
      }
    }
    Component.onCompleted: running = true
  }

  // GPU Temperature Tracker
  Process {
    id: gpuTempProc
    command: [ 
      "zsh", "--no-rcs", "-c",
      "cat /sys/class/hwmon/hwmon*/temp1_input | head -1" 
    ]
    stdout: SplitParser {
      onRead: data => {
	if (data && data.trim()) {
          gpuTemp = Math.round(parseInt(data.trim()) / 1000)
        }
      }
    }
    Component.onCompleted: running = true
  }

  // Power Profiles Tracker
  Process {
    id: powerProc
    command: [ "zsh", "--no-rcs", "-c", "powerprofilesctl get 2>/dev/null" ]
    stdout: SplitParser {
      onRead: data => {
        if (data && data.trim()) {
          var profile = data.trim()
          powerProfile = profile      
          if (profile === "performance") {
            powerIcon = "󰓅 "
          } else if (profile === "power-saver") {
            powerIcon = "󰾆 "
          } else {
            powerIcon = "󰾅 "
          }
        }
      }
    }
    Component.onCompleted: running = true
  }

  // Power Profiles Changer
  Process {
    id: powerSetProc
    onExited: {
      powerProc.running = true
    }
  }

  // MPRIS status tracker 
  Process {
    id: mprisProc
    command: [
      "zsh", "--no-rcs", "-c",
      "playerctl status 2>/dev/null"
    ]
    stdout: SplitParser {
      onRead: data => {
	var cleanedData = data ? data.trim() : ""
	if (cleanedData === "" || cleanedData.includes("No players")) {
	  mprisStatus = "Stopped"
	} else {
	  mprisStatus = cleanedData
	}
      }
    }
    Component.onCompleted: running = true
  }

  // MPRIS media control 
  Process {
    id: mprisControlProc 
    command: [
      "zsh", "--no-rcs", "-c",
      "playerctl play-pause"
    ]
    onExited: {
      mprisProc.running = true
    }
  }

  // Battery tracking process 
  Process {
    id: batteryProc
    command: [
      "zsh", "--no-rcs", "-c",
      "echo $(cat /sys/class/power_supply/BAT*/capacity) $(cat /sys/class/power_supply/BAT*/status)"
    ]
    stdout: SplitParser {
      onRead: data => {
        var p = data.trim().split(/\s+/)
        if (p.length >= 2) {
          batteryLevel = parseInt(p[0]) || 0
          batteryStatus = p[1]
        }
      }
    }
    Component.onCompleted: running = true
  }

  Process {
    id: netProc
    command: [
      "zsh", "--no-rcs", "-c",
      "awk 'NR>2 && $1!=\"lo:\" {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev"
    ]
    stdout: SplitParser {
      onRead: data => {
        var p = data.trim().split(/\s+/)
        var rx = parseFloat(p[0]) || 0
        var tx = parseFloat(p[1]) || 0
        if (lastRx > 0) {
          // timer interval is 2000 ms
          rxSpeed = Math.max(0, (rx - lastRx) / 2)
          txSpeed = Math.max(0, (tx - lastTx) / 2)
        }
        lastRx = rx
        lastTx = tx
      }
    }
    Component.onCompleted: running = true
  }

  function sig(value, digits) {
    var s = value.toPrecision(digits)
    // fall back to a plain integer if JS switched to exponential notation
    return s.indexOf("e") === -1 ? s : Math.round(value).toString()
  }

  function formatSpeed(bytes) {
    if (bytes >= 1073741824) return sig(bytes / 1073741824, 3) + " GiB/s"
    if (bytes >= 1048576)    return sig(bytes / 1048576, 3) + " MiB/s"
    if (bytes >= 1024)       return sig(bytes / 1024, 3) + " KiB/s"
    return Math.round(bytes) + " B/s"
  }

  // Tracked hardware timer
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      cpuProc.running = true
      cpuTempProc.running = true
      gpuTempProc.running = true
      memProc.running = true
      powerProc.running = true
      mprisProc.running = true
      batteryProc.running = true 
      netProc.running = true
    }
  }

  // Niri event tracker
  Process {
    id: niriEventNotifier
    command: [
      "zsh", "--no-rcs", "-c",
      "niri msg --json event-stream"
    ]

    running: true
        
    stdout: SplitParser {
      onRead: line => {
        windowProc.running = true
        volumeProc.running = true
      }
    }
  }

  // Backup timer for niri events
  Timer {
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      windowProc.running = true
      volumeProc.running = true
    }
  }

				  // Panel window layout
  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: Config.bar.height
  color: root.colBg
  
  Item {
    anchors.fill: parent
    anchors.margins: 6

    // Left Widgets
    RowLayout {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Text {
	text: " " + (mprisStatus === "Playing" ? " " : mprisStatus === "Paused" ? " " : " ")
	color: mprisStatus === "Stopped" ? root.colMuted : root.colBlue 
	font.pixelSize: root.fontSize
	font.family: root.fontFamily
	font.bold: true

	MouseArea {
	  anchors.fill: parent
	  cursorShape: mprisStatus !== "Stopped" ? Qt.PointingHandCursor : Qt.ArrowCursor
	  onClicked: if (mprisStatus !== "Stopped") {
	    mprisControlProc.running = true 
	  }
	}
      }
      
      // Separator
      Rectangle { width: 1; height: 16; color: root.colMuted }

      //Active Window widget
      Text {
	text: activeWindow
	color: root.colPurple
	font.pixelSize: root.fontSize
	font.family: root.fontFamily
	//font.bold: true
      }
    }

    // Center widget (Clock)
    Text {
      id: clock
      anchors.centerIn: parent 
      text: Qt.formatDateTime(new Date(), "MMM dd - HH:mm")
      color: root.colFg
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      font.bold: true

      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "MMM dd - HH:mm")
      }
    }

    // Right widgets
    RowLayout {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Text {
	text: {
        if (volumeLevel == 0 || isMuted) {
            return volumeLevel + "%  "
        } else if (volumeLevel > 0 && volumeLevel <= 33) {
            return volumeLevel + "%  "
        } else if (volumeLevel > 33 && volumeLevel <= 67) {
            return volumeLevel + "%  "
        } else if (volumeLevel > 67 && volumeLevel <= 100) {
            return volumeLevel + "%  "
        } else {
          return volumeLevel + "%  "
        }
      }
	color: root.colOrange
	font.family: root.fontFamily
	font.pixelSize: root.fontSize
	font.bold: true
      }

      // Separator
      Rectangle { width: 1; height: 16; color: root.colMuted }

      // CPU widget
      Text {
        text: "  " + cpuUsage + "% " + cpuTemp + "°C"
        color: cpuTemp >= 96 ? root.colRed : root.colYellow
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.bold: true
      }

      // Separator
      Rectangle { width: 1; height: 16; color: root.colMuted }

      // GPU widget
      Text {
	text: "󰢮  " + gpuUsage + "% " + gpuTemp + "°C"
	color: gpuTemp >= 96 ? root.colRed : root.colGreen
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.bold: true
      }

      // Separator
      Rectangle { width: 1; height: 16; color: root.colMuted }

      // Memory (RAM) widget
      Text {
        text: memUsage + "% " + " "
        color: memUsage >= 95 ? root.colRed : root.colTurquoise
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.bold: true
      }

      // Separator
      Rectangle { width: 1; height: 16; color: root.colMuted }

      Text {
	text: "󰇚 " + formatSpeed(rxSpeed) + " 󰕒 " + formatSpeed(txSpeed)
	color: root.colCyan 
	font.pixelSize: root.fontSize
	font.family: root.fontFamily 
	font.bold: true
      }

      Rectangle { width: 1; height: 16; color: root.colMuted }

      Text {
	text: {
          var index = Math.round(batteryLevel / 10)
          var icons = batteryStatus === "Discharging" ? batteryIconsDischarging : batteryIconsCharging
          return icons[index] + batteryLevel + "%"
	}	
	color: batteryLevel <= 10 ? root.colRed : root.colBlue
	font.pixelSize: root.fontSize
	font.family: root.fontFamily 
	font.bold: true
      }

      // Separator
      Rectangle { width: 1; height: 16; color: root.colMuted }

      // Power Profiles widget
      Text {
	text: powerIcon
	color: root.colPurple
	font.pixelSize: root.fontSize
	font.family: root.fontFamily 
	font.bold: true

	MouseArea {
	  anchors.fill: parent
	  cursorShape: Qt.PointingHandCursor
	  onClicked: {
	    var nextProfile = "balanced"

	    if (powerProfile === "power-saver") {
	      nextProfile = "balanced"
	    } else if (powerProfile === "balanced") {
	      nextProfile = "performance"
	    } else if (powerProfile === "performance") {
	      nextProfile = "power-saver"
	    }

	    powerSetProc.command = [
	      "zsh", "--no-rcs", "-c",
	      "powerprofilesctl set " + nextProfile
	    ]
	    powerSetProc.running = true
	  }
	}
      }

      // Separator
      Rectangle { width: 1; height: 16; color: root.colMuted }

      // Tray icons 
      Repeater {
	model: SystemTray.items
  
	delegate: Item {
	  id: trayItem
	  required property var modelData
  
	  Layout.preferredWidth: 24
	  Layout.preferredHeight: 24
      
	  QsMenuAnchor {
	    id: menuAnchor
	    menu: trayItem.modelData.menu
	    anchor.window: root
	  }
      
	  function openMenu() {
	    if (!trayItem.modelData.hasMenu) return
	    // position the popup just below the icon, in the bar window's coordinates
	    menuAnchor.anchor.rect = root.contentItem.mapFromItem(
	      trayItem, 0, trayItem.height, trayItem.width, 1
	    )
	    menuAnchor.open()
	  }
      
	  Image {
	    anchors.fill: parent
	    source: trayItem.modelData.icon
	    sourceSize.width: width
	    sourceSize.height: height
	  }
      
	  MouseArea {
	    anchors.fill: parent
	    cursorShape: Qt.PointingHandCursor
	    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      
	    onClicked: mouse => {
	      console.log("tray click:", trayItem.modelData.id, "button:", mouse.button,
              "hasMenu:", trayItem.modelData.hasMenu, "onlyMenu:", trayItem.modelData.onlyMenu)
	      var item = trayItem.modelData
	      if (mouse.button === Qt.LeftButton) {
		if (item.hasMenu) trayItem.openMenu()
		else item.activate()
	      } else if (mouse.button === Qt.RightButton) {
		trayItem.openMenu()
	      } else if (mouse.button === Qt.MiddleButton) {
		item.secondaryActivate()
	      }
	    }
	  }
	}
      }
    }
  }
}
