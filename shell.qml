import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Vortex

ShellRoot {
    id: shellRoot

    property var activePlayer: {
        var l = Mpris.players.values
        if (!l || l.length === 0) return null
        for (var i = 0; i < l.length; i++) {
            if (l[i].isPlaying) return l[i]
        }
        return l[0]
    }
    property string lastSeenTitle: ""
    property bool wasPlaying: false

    Timer {
        interval: 200
        running: shellRoot.activePlayer !== null
        repeat: true
        onTriggered: {
            if (!shellRoot.activePlayer) {
                StateStore.isMusicPlaying = false
                return
            }
            var t = shellRoot.activePlayer.trackTitle || ""
            var a = shellRoot.activePlayer.trackArtist || ""
            var p = shellRoot.activePlayer.isPlaying
            StateStore.isMusicPlaying = p
            if (t !== "" && t !== shellRoot.lastSeenTitle) {
                shellRoot.lastSeenTitle = t
                StateStore.fetchLyrics(t, a)
                StateStore.updateArtUrl(shellRoot.activePlayer.trackArtUrl || "")
                if (p) StateStore.peekMedia()
            } else if (p && !shellRoot.wasPlaying) {
                StateStore.peekMedia()
            }
            shellRoot.wasPlaying = p
            if (p && StateStore.lyricsList.length > 0) {
                StateStore.updateLyricPosition(shellRoot.activePlayer.position)
            }
        }
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() {
            if (!UPower.displayDevice) return
            var raw = UPower.displayDevice.percentage
            var norm = raw > 1.0 ? (raw / 100.0) : raw
            StateStore.batteryPct = norm
            var charging = !UPower.onBattery
            StateStore.isCharging = charging
            StateStore.criticalBatteryWarning = (!charging && norm <= 0.10)
            StateStore.lowBatteryWarning = (!charging && norm > 0.10 && norm <= 0.20)
        }
    }

    Component.onCompleted: {
        if (UPower.displayDevice) {
            var raw = UPower.displayDevice.percentage
            StateStore.batteryPct = raw > 1.0 ? (raw / 100.0) : raw
            StateStore.isCharging = !UPower.onBattery
        }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged() {
            var charging = !UPower.onBattery
            StateStore.isCharging = charging
            var rawPct = UPower.displayDevice ? UPower.displayDevice.percentage : 0.70
            var normVal = rawPct > 1.0 ? (rawPct / 100.0) : rawPct
            StateStore.criticalBatteryWarning = (!charging && normVal <= 0.10)
            StateStore.lowBatteryWarning = (!charging && normVal > 0.10 && normVal <= 0.20)
            if (!charging && normVal <= 0.20) {
                StateStore.triggerMascotMood("surprised", 6000)
            }
            StateStore.enterAlertPopup(
                "battery",
                charging ? "Charging" : "On Battery",
                charging ? "Charger connected" : "Charger disconnected",
                normVal,
                "⚡"
            )
        }
    }

    Process {
        id: sysMonitorProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/vortex/scripts/sys_monitor.sh"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var trimmed = line.trim()
                if (!trimmed) return
                var parts = trimmed.split("|")
                var kind = parts[0]

                if (kind === "TELEMETRY" && parts.length >= 5) {
                    StateStore.cpuTemp = parseInt(parts[1], 10) || 45
                    StateStore.gpuTemp = parseInt(parts[2], 10) || 40
                    StateStore.rogProfile = parts[4] || "Balanced"
                    if (parts.length >= 7) {
                        StateStore.ramPct = parseInt(parts[5], 10) || 25
                        StateStore.ramGbText = parts[6] || "8G"
                    }
                } else if (kind === "CLIP" && parts.length >= 2) {
                    StateStore.pushClipboardItem(parts.slice(1).join("|"))
                } else if (kind === "PROFILE_CHANGED" && parts.length >= 4) {
                    StateStore.enterAlertPopup("rog", parts[1], parts[2], 1.0, "🚀")
                } else if (kind === "BT_CONN" && parts.length >= 4) {
                    StateStore.enterAlertPopup("bluetooth", parts[1], parts[2], parseFloat(parts[3]) / 100.0, "ᛒ")
                } else if (kind === "BT_DISC" && parts.length >= 4) {
                    StateStore.enterAlertPopup("bluetooth", parts[1], parts[2], 0.0, "ᛒ")
                } else if (kind === "WIFI" && parts.length >= 4) {
                    StateStore.enterAlertPopup("wifi", parts[1], parts[2], parseFloat(parts[3]) / 100.0, "󰖩")
                }
            }
        }
    }

    Process {
        id: checkFsModeProc
        command: ["bash", "-c", "hyprctl activewindow -j | jq -r '.fullscreen // 0'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var mode = data.trim()
                StateStore.onFullscreenChanged(mode === "2")
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event) return
            if (event.name === "fullscreen" || event.name === "activewindow" || event.name === "workspace") {
                checkFsModeProc.running = false
                checkFsModeProc.running = true
            } else if (event.name === "activelayout") {
                var parts = event.data.split(",")
                if (parts.length >= 2) {
                    var kbName = parts[0]
                    var layoutName = parts.slice(1).join(",")
                    if (kbName.indexOf("fcitx") !== -1 || kbName.indexOf("virtual") !== -1 || kbName.indexOf("hl-virtual") !== -1) {
                        return
                    }
                    if (StateStore.lastKeyboardLayout === "") {
                        StateStore.lastKeyboardLayout = layoutName
                        return
                    }
                    if (StateStore.lastKeyboardLayout !== layoutName) {
                        StateStore.lastKeyboardLayout = layoutName
                        StateStore.enterAlertPopup("keyboard", "Keyboard", layoutName, 1.0, "󰌌")
                    }
                }
            }
        }
    }

    Timer {
        id: pomodoroTimer
        interval: 1000
        running: StateStore.pomodoroRunning && StateStore.pomodoroRemainingSeconds > 0
        repeat: true
        onTriggered: {
            StateStore.pomodoroRemainingSeconds--
            if (StateStore.pomodoroRemainingSeconds <= 0) {
                StateStore.pomodoroRunning = false
                if (!StateStore.pomodoroIsBreak) {
                    StateStore.pomodoroCompletedToday++
                    StateStore.saveState()
                }
                StateStore.pomodoroIsBreak = !StateStore.pomodoroIsBreak
                StateStore.pomodoroRemainingSeconds = (StateStore.pomodoroIsBreak ? StateStore.pomodoroBreakMinutes : StateStore.pomodoroFocusMinutes) * 60
                StateStore.playChime()
                StateStore.triggerMascotMood("happy", 8000)
                StateStore.enterAlertPopup("pomodoro", "Pomodoro Complete!", StateStore.pomodoroIsBreak ? "Time for a short break ☕" : "Back to focus 🍅", 1.0, "🍅")
            }
        }
    }

    Timer {
        id: minuteChecker
        interval: 15000
        running: true
        repeat: true
        onTriggered: StateStore.checkTodoReminders()
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: notchWindow
            property var modelData
            screen: modelData
            WlrLayershell.namespace: "vortex-notch"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (notchContainer.localState === "EXPANDED" && notchContainer.isEditingLocal) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            readonly property real screenDpiBoost: {
                if (!modelData) return 1.0
                var sName = modelData.name || ""
                var sWidth = modelData.width || 1920
                if (sName.indexOf("eDP") !== -1 && sWidth >= 2400) {
                    return (sWidth / 1920.0) * (StateStore.omacleScale / 1.15)
                }
                return Math.max(0.85, StateStore.omacleScale / 1.25)
            }

            anchors.top: true
            anchors.left: true
            anchors.right: true
            margins.top: StateStore.topBarOffset
            exclusiveZone: -1
            color: "transparent"

            visible: !StateStore.isFullscreen
            implicitHeight: Math.ceil(350 * screenDpiBoost)

            mask: Region {
                item: notchMaskWrapper
                Region {
                    item: splitLyricsPill.visible ? splitLyricsPill : null
                }
            }

            Item {
                id: notchMaskWrapper
                width: Math.round(notchContainer.width * notchWindow.screenDpiBoost)
                height: Math.round(notchContainer.height * notchWindow.screenDpiBoost)
                x: Math.round((parent.width - width) / 2 + StateStore.horizontalOffset)
                y: 0

                NotchContainer {
                    id: notchContainer
                    x: 0
                    y: 0
                    transform: Scale {
                        origin.x: 0
                        origin.y: 0
                        xScale: notchWindow.screenDpiBoost
                        yScale: notchWindow.screenDpiBoost
                    }
                }
            }

            Rectangle {
                id: splitLyricsPill
                visible: StateStore.splitLyricsEnabled && notchContainer.localState !== "EXPANDED" && StateStore.currentLyricLine !== ""
                width: Math.min(440, Math.max(200, splitLyricText.implicitWidth + 28)) * notchWindow.screenDpiBoost
                height: 26 * notchWindow.screenDpiBoost
                x: (parent.width - width) / 2 + StateStore.horizontalOffset
                y: notchMaskWrapper.height + 4
                radius: 13 * notchWindow.screenDpiBoost
                color: "#000000"
                border.color: "#1f2229"
                border.width: 1

                Text {
                    id: splitLyricText
                    anchors.centerIn: parent
                    text: "🎤 " + StateStore.currentLyricLine
                    color: "#ffffff"
                    font.pixelSize: Math.round(11 * notchWindow.screenDpiBoost)
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(410 * notchWindow.screenDpiBoost, implicitWidth)
                }
            }
        }
    }
}
