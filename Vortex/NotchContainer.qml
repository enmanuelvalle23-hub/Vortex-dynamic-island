import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Services.Mpris

Item {
    id: root

    property string localState: StateStore.minimalMode ? "MINIMAL" : "CLOSED_CLOCK"
    property bool isHovering: false
    property bool isEditingLocal: false

    function openTodoEditor(idx, existingTime, existingTitle) {
        StateStore.todoEditingIndex = idx
        StateStore.todoAddingMode = true
        root.isEditingLocal = true
        todoTimeInput.text = existingTime || (StateStore.todoShowAgenda ? Qt.formatTime(new Date(), "HH:mm") : "")
        newTodoInput.text = existingTitle || ""
        newTodoInput.forceActiveFocus()
    }

    function closeTodoEditor() {
        root.isEditingLocal = false
        StateStore.cancelTodoInput()
        todoTimeInput.text = ""
        newTodoInput.text = ""
    }

    Connections {
        target: StateStore
        function onMinimalModeChanged() {
            if (root.localState !== "EXPANDED") {
                root.localState = StateStore.minimalMode ? "MINIMAL" : "CLOSED_CLOCK"
            }
        }
        function onAlertSeqChanged() {
            if (root.localState !== "EXPANDED") {
                root.localState = "ALERT_POPUP"
                localAlertTimer.restart()
            }
        }
        function onMediaPeekSeqChanged() {
            if (!root.isHovering && root.localState !== "EXPANDED") {
                root.localState = "EXPANDED"
                localPeekTimer.restart()
            }
        }
        function onForceExpandSeqChanged() {
            root.localState = "EXPANDED"
            localPeekTimer.interval = 4500
            localPeekTimer.restart()
        }
    }

    Timer {
        id: localHoverLeaveTimer
        interval: 240
        repeat: false
        onTriggered: {
            if (!root.isHovering && !root.isEditingLocal) {
                root.localState = StateStore.minimalMode ? "MINIMAL" : "CLOSED_CLOCK"
            }
        }
    }

    Timer {
        id: localAlertTimer
        interval: 2800
        repeat: false
        onTriggered: {
            if (!root.isHovering && root.localState === "ALERT_POPUP") {
                root.localState = StateStore.minimalMode ? "MINIMAL" : "CLOSED_CLOCK"
            }
        }
    }

    Timer {
        id: localPeekTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.isHovering && !root.isEditingLocal) {
                root.localState = StateStore.minimalMode ? "MINIMAL" : "CLOSED_CLOCK"
            }
        }
    }

    readonly property int topFlareRadius: root.localState === "MINIMAL" ? 6 : 20

    readonly property int bodyWidth: {
        if (root.localState === "MINIMAL") return 100
        if (root.localState === "ALERT_POPUP") return 360
        if (root.localState === "EXPANDED") return 620
        return 212
    }

    readonly property int targetHeight: {
        if (root.localState === "MINIMAL") return 6
        if (root.localState === "ALERT_POPUP") return 74
        if (root.localState === "EXPANDED") return 310
        return 34
    }

    width: bodyWidth + (topFlareRadius * 2)
    height: targetHeight

    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    property var activePlayer: {
        var l = Mpris.players.values
        if (!l || l.length === 0) return null
        for (var i = 0; i < l.length; i++) {
            if (l[i].isPlaying) return l[i]
        }
        return l[0]
    }

    readonly property real ringProgress: {
        if (StateStore.pomodoroRunning) {
            var t = (StateStore.pomodoroIsBreak ? StateStore.pomodoroBreakMinutes : StateStore.pomodoroFocusMinutes) * 60
            return t > 0 ? Math.max(0.05, StateStore.pomodoroRemainingSeconds / t) : 0.75
        }
        if (StateStore.ringMode === "cpu") return Math.min(1.0, Math.max(0.12, (StateStore.cpuTemp - 30) / 65.0))
        if (StateStore.ringMode === "ram") return Math.min(1.0, Math.max(0.10, StateStore.ramPct / 100.0))
        if (StateStore.ringMode === "todo") {
            if (StateStore.todoList.length === 0) return 1.0
            return Math.max(0.10, StateStore.todoList.filter(t => t.done).length / StateStore.todoList.length)
        }
        return Math.min(1.0, Math.max(0.08, StateStore.batteryPct))
    }

    readonly property string ringStrokeColor: {
        if (StateStore.criticalBatteryWarning) return "#ef4444"
        if (StateStore.pomodoroRunning) return "#ff4d4f"
        if (StateStore.ringMode === "cpu" && StateStore.cpuTemp >= 80) return "#ef4444"
        if (StateStore.ringMode === "ram" && StateStore.ramPct >= 85) return "#f59e0b"
        if (StateStore.ringMode === "battery" && StateStore.lowBatteryWarning) return "#f59e0b"
        return "#22c55e"
    }

    DropArea {
        anchors.fill: parent
        onEntered: drag => {
            if (drag.hasUrls) {
                StateStore.activeTab = 3
                root.isHovering = true
                localHoverLeaveTimer.stop()
                root.localState = "EXPANDED"
            }
        }
        onDropped: drop => {
            if (drop.hasUrls) {
                StateStore.addShelfUrls(drop.urls)
                StateStore.activeTab = 3
            }
        }
    }

    Rectangle {
        id: mainBody
        x: root.topFlareRadius
        y: 0
        width: parent.width - (root.topFlareRadius * 2)
        height: parent.height
        color: "#000000"
        radius: Math.round((root.localState === "MINIMAL" ? 3 : (root.localState === "EXPANDED" ? 26 : 15)) * StateStore.omacleRounding)
        Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(1, parent.radius)
            color: "#000000"
        }
    }

    Canvas {
        width: root.topFlareRadius
        height: root.topFlareRadius
        anchors.right: mainBody.left
        anchors.top: parent.top
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "#000000"
            ctx.beginPath()
            ctx.moveTo(width, 0)
            ctx.lineTo(width, height)
            ctx.quadraticCurveTo(width, 0, 0, 0)
            ctx.closePath()
            ctx.fill()
        }
    }

    Canvas {
        width: root.topFlareRadius
        height: root.topFlareRadius
        anchors.left: mainBody.right
        anchors.top: parent.top
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "#000000"
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(0, height)
            ctx.quadraticCurveTo(0, 0, width, 0)
            ctx.closePath()
            ctx.fill()
        }
    }

    Item {
        id: bg
        x: root.topFlareRadius
        y: 0
        width: parent.width - (root.topFlareRadius * 2)
        height: parent.height
        clip: true

        property real touchAccumX: 0
        property real touchAccumY: 0

        Timer {
            id: swipeCooldown
            interval: 280
            repeat: false
            onTriggered: {
                bg.touchAccumX = 0
                bg.touchAccumY = 0
            }
        }

        Timer {
            id: gestureResetTimer
            interval: 160
            repeat: false
            onTriggered: {
                bg.touchAccumX = 0
                bg.touchAccumY = 0
            }
        }

        // Capa superior transparente: deja pasar todos los clics pero captura el deslizamiento de 2 dedos en toda la superficie
        MouseArea {
            anchors.fill: parent
            z: 999
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            onWheel: wheel => {
                if (root.localState !== "EXPANDED" || root.isEditingLocal) {
                    wheel.accepted = false
                    return
                }
                if (swipeCooldown.running) {
                    wheel.accepted = true
                    return
                }

                gestureResetTimer.restart()

                var dx = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.pixelDelta.x
                var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y

                bg.touchAccumX += dx
                bg.touchAccumY += dy

                // Umbral bajo (18) para que responda al instante al deslizar 2 dedos en el touchpad
                var threshold = 18

                if (Math.abs(bg.touchAccumX) >= Math.abs(bg.touchAccumY) && Math.abs(bg.touchAccumX) >= threshold) {
                    if (bg.touchAccumX < 0) {
                        StateStore.activeTab = (StateStore.activeTab + 1) % 6
                    } else {
                        StateStore.activeTab = (StateStore.activeTab + 5) % 6
                    }
                    bg.touchAccumX = 0
                    bg.touchAccumY = 0
                    swipeCooldown.restart()
                    wheel.accepted = true
                } else if (Math.abs(bg.touchAccumY) > Math.abs(bg.touchAccumX) && Math.abs(bg.touchAccumY) >= threshold) {
                    if (bg.touchAccumY < 0) {
                        StateStore.activeTab = (StateStore.activeTab + 1) % 6
                    } else {
                        StateStore.activeTab = (StateStore.activeTab + 5) % 6
                    }
                    bg.touchAccumX = 0
                    bg.touchAccumY = 0
                    swipeCooldown.restart()
                    wheel.accepted = true
                }
            }
        }

        Rectangle {
            z: 100
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: toastL.implicitWidth + 24
            height: 24
            radius: 12
            color: "#0e1f14"
            border.color: "#a6d189"
            border.width: 1
            opacity: StateStore.ringToastVisible ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Text {
                id: toastL
                anchors.centerIn: parent
                text: StateStore.ringToastText
                color: "#ffffff"
                font.pixelSize: 11
                font.bold: true
            }
        }

        // =========================================================
        // ESTADO CERRADO (Con Onda Sinusoidal CoreWave en lugar de ojos)
        // =========================================================
        Item {
            anchors.fill: parent
            visible: root.localState === "RESTING_MASCOT" || root.localState === "CLOSED_CLOCK"

            Canvas {
                width: 18
                height: 18
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true
                property real prog: root.ringProgress
                property string col: root.ringStrokeColor
                onProgChanged: requestPaint()
                onColChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.lineWidth = 3.2
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(9, 9, 6.5, 0, Math.PI * 2, false)
                    ctx.strokeStyle = StateStore.criticalBatteryWarning ? "#451417" : "#143824"
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(9, 9, 6.5, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * prog), false)
                    ctx.strokeStyle = col
                    ctx.stroke()
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.cycleRingMode()
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                CoreWave {
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: StateStore.pomodoroRunning ? StateStore.formatTime(StateStore.pomodoroRemainingSeconds) : StateStore.currentTimeStr
                    color: StateStore.pomodoroRunning ? "#ff4d4f" : "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        width: 3
                        radius: 1.5
                        color: (StateStore.audioBars[index] || 0) > 0.05 ? "#22c55e" : "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        height: {
                            var lvl = StateStore.audioBars[index] || 0.0
                            var idleHeights = [5, 8, 11, 8, 5]
                            if (lvl > 0.02) {
                                return Math.round(4 + (lvl * 14))
                            }
                            return idleHeights[index]
                        }
                        Behavior on height { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
        }

        OsdAlert {
            anchors.fill: parent
            visible: root.localState === "ALERT_POPUP"
        }

        // =========================================================
        // ESTADO EXPANDIDO
        // =========================================================
        Item {
            anchors.fill: parent
            visible: root.localState === "EXPANDED"

            // 1. Título y Botones de la Pestaña Activa (Izquierda)
            Row {
                anchors.top: parent.top
                anchors.topMargin: 11
                anchors.left: parent.left
                anchors.leftMargin: 18
                spacing: 8
                z: 15

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        text: {
                            if (StateStore.activeTab === 0) return "Vortex"
                            if (StateStore.activeTab === 1) return "Media"
                            if (StateStore.activeTab === 2) return "Santo Domingo"
                            if (StateStore.activeTab === 3) return "Shelf"
                            if (StateStore.activeTab === 4) return "Todo"
                            if (StateStore.activeTab === 5) return "Calendar"
                            return ""
                        }
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        visible: StateStore.activeTab === 0 || StateStore.activeTab === 1 || StateStore.activeTab === 4
                        text: StateStore.activeTab === 0 ? "Core" : (StateStore.activeTab === 1 ? "Player" : (StateStore.todoShowAgenda ? "Agenda" : "List"))
                        color: "#a6d189"
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        visible: StateStore.activeTab === 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "· " + StateStore.spanishDateStr
                        color: "#8b929e"
                        font.pixelSize: 11
                    }
                }

                Row {
                    visible: StateStore.activeTab === 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text {
                        text: "🌅 " + StateStore.weatherSunrise
                        color: "#a6d189"
                        font.pixelSize: 10
                        font.bold: true
                    }
                    Text {
                        text: "🌙 " + StateStore.weatherSunset
                        color: "#38bdf8"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                Rectangle {
                    visible: StateStore.activeTab === 3
                    width: 50
                    height: 20
                    radius: 10
                    color: "#0d0e11"
                    border.color: "#1f2229"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "Paste"
                        color: "#a6d189"
                        font.pixelSize: 9
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.pasteFileToShelf()
                    }
                }

                Rectangle {
                    visible: StateStore.activeTab === 3 && ((StateStore.shelfShowClipboard && StateStore.clipboardHistory.length > 0) || (!StateStore.shelfShowClipboard && StateStore.shelfFiles.length > 0))
                    width: 40
                    height: 20
                    radius: 10
                    color: "#0d0e11"
                    border.color: "#1f2229"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: "#8b929e"
                        font.pixelSize: 9
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.clearShelf()
                    }
                }

                Rectangle {
                    visible: StateStore.activeTab === 3
                    width: 52
                    height: 20
                    radius: 10
                    color: "#0d0e11"
                    border.color: "#2c313c"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: StateStore.shelfShowClipboard ? "Clips" : "Files"
                        color: "#ffffff"
                        font.pixelSize: 9
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.shelfShowClipboard = !StateStore.shelfShowClipboard
                    }
                }

                // Botón de Modo Privado / Incógnito en el Portapapeles
                Rectangle {
                    visible: StateStore.activeTab === 3 && StateStore.shelfShowClipboard
                    width: 72
                    height: 20
                    radius: 10
                    color: StateStore.clipboardIncognito ? "#271416" : "#0d0e11"
                    border.color: StateStore.clipboardIncognito ? "#ef4444" : "#2c313c"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: StateStore.clipboardIncognito ? "🕵 Paused" : "🕵 Incognito"
                        color: StateStore.clipboardIncognito ? "#ef4444" : "#a1a1aa"
                        font.pixelSize: 9
                        font.bold: StateStore.clipboardIncognito
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.toggleClipboardIncognito()
                    }
                }

                Rectangle {
                    visible: StateStore.activeTab === 4
                    width: 68
                    height: 20
                    radius: 10
                    color: StateStore.todoShowAgenda ? "#0e2216" : "#0d0e11"
                    border.color: StateStore.todoShowAgenda ? "#a6d189" : "#2c313c"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: StateStore.todoShowAgenda ? "📅 Agenda" : "✓ Tasks"
                        color: "#ffffff"
                        font.pixelSize: 9
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeTodoEditor()
                            StateStore.todoShowAgenda = !StateStore.todoShowAgenda
                        }
                    }
                }
            }

            // 2. Ruedita Verde + CoreWave + Hora + 5 Barritas de Sonido
            Row {
                anchors.top: parent.top
                anchors.topMargin: 11
                anchors.right: parent.right
                anchors.rightMargin: 18
                spacing: 8
                z: 15

                Canvas {
                    width: 15
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter
                    antialiasing: true
                    property real prog: root.ringProgress
                    property string col: root.ringStrokeColor
                    onProgChanged: requestPaint()
                    onColChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.lineWidth = 2.8
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.arc(7.5, 7.5, 5.2, 0, Math.PI * 2, false)
                        ctx.strokeStyle = StateStore.criticalBatteryWarning ? "#451417" : "#143824"
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(7.5, 7.5, 5.2, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * prog), false)
                        ctx.strokeStyle = col
                        ctx.stroke()
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StateStore.cycleRingMode()
                    }
                }

                CoreWave {
                    anchors.verticalCenter: parent.verticalCenter
                    scale: 0.9
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: StateStore.pomodoroRunning ? StateStore.formatTime(StateStore.pomodoroRemainingSeconds) : StateStore.currentTimeStr
                    color: StateStore.pomodoroRunning ? "#ff4d4f" : "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            width: 3
                            radius: 1.5
                            color: (StateStore.audioBars[index] || 0) > 0.05 ? "#22c55e" : "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            height: {
                                var lvl = StateStore.audioBars[index] || 0.0
                                var idleHeights = [5, 8, 11, 8, 5]
                                if (lvl > 0.02) {
                                    return Math.round(4 + (lvl * 12))
                                }
                                return idleHeights[index]
                            }
                            Behavior on height { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }

            // 3. Botones de navegación CIRCULAR (< y > siempre visibles)
            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: "#14161b"
                border.color: "#2c313c"
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                z: 25
                Text {
                    anchors.centerIn: parent
                    text: "<"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.activeTab = (StateStore.activeTab + 5) % 6
                }
            }

            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: "#14161b"
                border.color: "#2c313c"
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                z: 25
                Text {
                    anchors.centerIn: parent
                    text: ">"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: StateStore.activeTab = (StateStore.activeTab + 1) % 6
                }
            }

            // ==========================================
            // CONTENEDOR DE PESTAÑAS (0 al 5)
            // ==========================================
            Item {
                anchors.fill: parent

                // =========================================================
                // TAB 0: VORTEX CORE (CPU, GPU, STORAGE, NET & SEC, MEMORY, BATTERY LIMIT)
                // =========================================================
                Item {
                    anchors.fill: parent
                    opacity: StateStore.activeTab === 0 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle {
                        x: 32
                        y: 36
                        width: 234
                        height: 112
                        radius: 18
                        color: "#0d0e11"
                        border.color: "#1f2229"

                        Canvas {
                            x: 12
                            y: 12
                            width: 36
                            height: 36
                            antialiasing: true
                            property real uProg: Math.max(0.08, Math.min(1.0, StateStore.cpuUsage / 100.0))
                            onUProgChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 3.2
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.arc(18, 18, 14, 0, Math.PI * 2)
                                ctx.strokeStyle = "#1f2229"
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(18, 18, 14, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * uProg))
                                ctx.strokeStyle = "#a6d189"
                                ctx.stroke()
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰻠"
                                color: "#a6d189"
                                font.pixelSize: 13
                            }
                        }

                        Column {
                            x: 54
                            y: 12
                            spacing: 2
                            Text {
                                text: "CPU"
                                color: "#a6d189"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "AMD Ryzen 9 5900HS..."
                                color: "#8b929e"
                                font.pixelSize: 9
                                width: 108
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            x: 14
                            y: 62
                            spacing: 4
                            Text {
                                text: "🌡"
                                color: StateStore.cpuTemp >= 85 ? "#ef4444" : "#a6d189"
                                font.pixelSize: 12
                            }
                            Text {
                                text: StateStore.cpuTemp + "°C"
                                color: "#ffffff"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Rectangle {
                            x: 14
                            y: 88
                            width: 136
                            height: 6
                            radius: 3
                            color: "#1f2229"
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.1, (StateStore.cpuTemp - 30) / 70.0))
                                height: parent.height
                                radius: 3
                                color: StateStore.cpuTemp >= 85 ? "#ef4444" : "#a6d189"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: cpuBadge.horizontalCenter
                            y: 12
                            text: "Usage"
                            color: "#8b929e"
                            font.pixelSize: 9
                        }

                        Canvas {
                            id: cpuBadge
                            x: 164
                            y: 28
                            width: 60
                            height: 68
                            antialiasing: true
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var cx = width / 2
                                var cy = height / 2
                                var rBase = 26
                                ctx.fillStyle = "#14261a"
                                ctx.beginPath()
                                for (var a = 0; a <= 360; a += 4) {
                                    var rad = a * Math.PI / 180.0
                                    var r = rBase + 2.5 * Math.sin(rad * 12)
                                    var px = cx + r * Math.cos(rad)
                                    var py = cy + r * Math.sin(rad)
                                    if (a === 0) ctx.moveTo(px, py)
                                    else ctx.lineTo(px, py)
                                }
                                ctx.closePath()
                                ctx.fill()
                            }
                            Text {
                                anchors.centerIn: parent
                                text: StateStore.cpuUsage.toFixed(1) + "%"
                                color: "#a6d189"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        x: 274
                        y: 36
                        width: 234
                        height: 112
                        radius: 18
                        color: "#0d0e11"
                        border.color: "#1f2229"

                        Canvas {
                            x: 12
                            y: 12
                            width: 36
                            height: 36
                            antialiasing: true
                            property real gProg: Math.max(0.08, Math.min(1.0, StateStore.gpuUsage / 100.0))
                            onGProgChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 3.2
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.arc(18, 18, 14, 0, Math.PI * 2)
                                ctx.strokeStyle = "#1f2229"
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(18, 18, 14, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * gProg))
                                ctx.strokeStyle = "#38bdf8"
                                ctx.stroke()
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰍹"
                                color: "#38bdf8"
                                font.pixelSize: 13
                            }
                        }

                        Column {
                            x: 54
                            y: 12
                            spacing: 2
                            Text {
                                text: "GPU"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "NVIDIA GeForce RTX 3070..."
                                color: "#8b929e"
                                font.pixelSize: 9
                                width: 108
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            x: 14
                            y: 62
                            spacing: 4
                            Text {
                                text: "🌡"
                                color: "#38bdf8"
                                font.pixelSize: 12
                            }
                            Text {
                                text: StateStore.gpuTemp + "°C"
                                color: "#ffffff"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Rectangle {
                            x: 14
                            y: 88
                            width: 136
                            height: 6
                            radius: 3
                            color: "#1f2229"
                            Rectangle {
                                width: parent.width * Math.min(1.0, Math.max(0.1, (StateStore.gpuTemp - 30) / 70.0))
                                height: parent.height
                                radius: 3
                                color: "#38bdf8"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: gpuBadge.horizontalCenter
                            y: 12
                            text: "Usage"
                            color: "#8b929e"
                            font.pixelSize: 9
                        }

                        Canvas {
                            id: gpuBadge
                            x: 164
                            y: 28
                            width: 60
                            height: 68
                            antialiasing: true
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var cx = width / 2
                                var cy = height / 2
                                var rBase = 26
                                ctx.fillStyle = "#12222e"
                                ctx.beginPath()
                                for (var a = 0; a <= 360; a += 4) {
                                    var rad = a * Math.PI / 180.0
                                    var r = rBase + 2.2 * Math.sin(rad * 6)
                                    var px = cx + r * Math.cos(rad)
                                    var py = cy + r * Math.sin(rad)
                                    if (a === 0) ctx.moveTo(px, py)
                                    else ctx.lineTo(px, py)
                                }
                                ctx.closePath()
                                ctx.fill()
                            }
                            Text {
                                anchors.centerIn: parent
                                text: Math.round(StateStore.gpuUsage) + "%"
                                color: "#38bdf8"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        x: 32
                        y: 154
                        width: 156
                        height: 124
                        radius: 18
                        color: "#0d0e11"
                        border.color: "#1f2229"

                        Canvas {
                            x: 10
                            y: 10
                            width: 66
                            height: 66
                            antialiasing: true
                            property real dProg: Math.max(0.05, Math.min(1.0, StateStore.diskPct / 100.0))
                            onDProgChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 4.5
                                ctx.lineCap = "round"
                                var startA = 0.75 * Math.PI
                                var spanA = 1.5 * Math.PI
                                ctx.beginPath()
                                ctx.arc(33, 35, 25, startA, startA + spanA)
                                ctx.strokeStyle = "#1f2229"
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(33, 35, 25, startA, startA + (spanA * dProg))
                                ctx.strokeStyle = "#e4e4e7"
                                ctx.stroke()
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 0
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: StateStore.diskPct.toFixed(1) + "%"
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Used"
                                    color: "#8b929e"
                                    font.pixelSize: 8
                                }
                            }
                        }

                        Column {
                            x: 80
                            y: 22
                            spacing: 2
                            Text {
                                text: "Storage"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                text: StateStore.diskGbText
                                color: "#8b929e"
                                font.pixelSize: 8
                                width: 70
                                wrapMode: Text.Wrap
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 88
                            spacing: 5
                            Repeater {
                                model: [
                                    { id: "Quiet", l: "🌙" },
                                    { id: "Balanced", l: "⚖ /" },
                                    { id: "Performance", l: "🚀" }
                                ]
                                delegate: Rectangle {
                                    readonly property bool activeP: StateStore.rogProfile.toLowerCase().indexOf(modelData.id.toLowerCase()) !== -1
                                    width: index === 1 ? 66 : 30
                                    height: 24
                                    radius: 12
                                    color: activeP ? "#143824" : "#16181d"
                                    border.color: activeP ? "#a6d189" : "#262932"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.l
                                        color: activeP ? "#a6d189" : "#a1a1aa"
                                        font.pixelSize: 10
                                        font.bold: activeP
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: StateStore.setRogProfile(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    // 4. TARJETA NET & SEC (Con Puertos LISTEN + Túnel Tailscale/VPN 1-Clic)
                    Rectangle {
                        x: 194
                        y: 154
                        width: 180
                        height: 124
                        radius: 18
                        color: "#0d0e11"
                        border.color: StateStore.vpnActive ? "#1e462f" : "#1f2229"

                        RowLayout {
                            x: 12
                            y: 8
                            width: parent.width - 24
                            Row {
                                spacing: 4
                                Layout.fillWidth: true
                                Text {
                                    text: "🛡"
                                    color: "#a6d189"
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: "Net & Sec"
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            // Contador de Puertos en LISTEN
                            Rectangle {
                                width: portTxt.implicitWidth + 10
                                height: 16
                                radius: 8
                                color: "#14161b"
                                border.color: "#262932"
                                Text {
                                    id: portTxt
                                    anchors.centerIn: parent
                                    text: StateStore.listenPortsCount + " LISTEN"
                                    color: "#38bdf8"
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                        }

                        Canvas {
                            x: 12
                            y: 26
                            width: 156
                            height: 24
                            antialiasing: true
                            property var hist: StateStore.netHistory
                            onHistChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var arr = hist || []
                                if (arr.length < 2) return
                                var step = width / (arr.length - 1)
                                ctx.beginPath()
                                ctx.moveTo(0, height)
                                for (var i = 0; i < arr.length; i++) {
                                    ctx.lineTo(i * step, height - (arr[i] * (height - 4)) - 2)
                                }
                                ctx.lineTo(width, height)
                                ctx.closePath()
                                ctx.fillStyle = "rgba(166, 209, 137, 0.20)"
                                ctx.fill()

                                ctx.beginPath()
                                for (var j = 0; j < arr.length; j++) {
                                    var py = height - (arr[j] * (height - 4)) - 2
                                    if (j === 0) ctx.moveTo(0, py)
                                    else ctx.lineTo(j * step, py)
                                }
                                ctx.strokeStyle = "#a6d189"
                                ctx.lineWidth = 1.6
                                ctx.stroke()
                            }
                        }

                        Column {
                            x: 12
                            y: 52
                            width: 156
                            spacing: 2
                            RowLayout {
                                width: parent.width
                                Text { text: "↓ Down"; color: "#8b929e"; font.pixelSize: 8; Layout.fillWidth: true }
                                Text { text: StateStore.netDownStr; color: "#a6d189"; font.pixelSize: 8; font.bold: true }
                            }
                            RowLayout {
                                width: parent.width
                                Text { text: "↑ Up"; color: "#8b929e"; font.pixelSize: 8; Layout.fillWidth: true }
                                Text { text: StateStore.netUpStr; color: "#38bdf8"; font.pixelSize: 8; font.bold: true }
                            }
                        }

                        // Barra de Túnel VPN / Tailscale (Clic Izquierdo en IP = Copiar | Clic Izquierdo en Botón = ON/OFF)
                        Rectangle {
                            x: 10
                            y: 88
                            width: parent.width - 20
                            height: 26
                            radius: 10
                            color: StateStore.vpnActive ? "#122b1d" : "#14161b"
                            border.color: StateStore.vpnActive ? "#a6d189" : "#262932"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 4

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: StateStore.vpnActive ? "#22c55e" : "#ef4444"
                                }

                                Text {
                                    text: StateStore.vpnActive ? StateStore.vpnIp : "Tailscale: Off"
                                    color: StateStore.vpnActive ? "#a6d189" : "#8b929e"
                                    font.pixelSize: 9
                                    font.bold: StateStore.vpnActive
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: 38
                                    height: 18
                                    radius: 6
                                    color: StateStore.vpnActive ? "#271416" : "#143824"
                                    border.color: StateStore.vpnActive ? "#ef4444" : "#a6d189"
                                    z: 10

                                    Text {
                                        anchors.centerIn: parent
                                        text: StateStore.vpnActive ? "OFF" : "ON"
                                        color: StateStore.vpnActive ? "#ef4444" : "#a6d189"
                                        font.pixelSize: 8
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: StateStore.toggleTailscaleTunnel()
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 44
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: m => {
                                    if (m.button === Qt.RightButton || !StateStore.vpnActive) StateStore.toggleTailscaleTunnel()
                                    else StateStore.copyVpnIp()
                                }
                            }
                        }
                    }

                    Rectangle {
                        x: 380
                        y: 154
                        width: 128
                        height: 124
                        radius: 18
                        color: "#0d0e11"
                        border.color: "#1f2229"

                        Row {
                            x: 12
                            y: 10
                            spacing: 5
                            Text {
                                text: "󰍛"
                                color: "#a6d189"
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Memory"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        Canvas {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 30
                            width: 66
                            height: 66
                            antialiasing: true
                            property real mProg: Math.max(0.05, Math.min(1.0, StateStore.ramPct / 100.0))
                            onMProgChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 4.5
                                ctx.lineCap = "round"
                                var startA = 0.75 * Math.PI
                                var spanA = 1.5 * Math.PI
                                ctx.beginPath()
                                ctx.arc(33, 33, 25, startA, startA + spanA)
                                ctx.strokeStyle = "#1f2229"
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(33, 33, 25, startA, startA + (spanA * mProg))
                                ctx.strokeStyle = "#a6d189"
                                ctx.stroke()
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 0
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: StateStore.ramPct.toFixed(1) + "%"
                                    color: "#a6d189"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Used"
                                    color: "#8b929e"
                                    font.pixelSize: 8
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 102
                            text: StateStore.ramGbText
                            color: "#e4e4e7"
                            font.pixelSize: 9
                        }
                    }

                    // 6. TARJETA BATTERY CON LÍMITE DE CARGA NATIVO (60% / 80% / 100%)
                    Rectangle {
                        x: 514
                        y: 36
                        width: 74
                        height: 242
                        radius: 18
                        color: "#0d0e11"
                        border.color: "#1f2229"
                        clip: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * Math.min(1.0, Math.max(0.12, StateStore.batteryPct))
                            radius: 18
                            color: "#122b1d"
                            border.color: "#1e462f"
                        }

                        Column {
                            x: 10
                            y: 12
                            spacing: 3
                            Text {
                                text: "🔋"
                                font.pixelSize: 13
                            }
                            Text {
                                text: "Battery"
                                color: "#a6d189"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            // Píldora indicadora del límite físico de carga
                            Rectangle {
                                width: 54
                                height: 18
                                radius: 9
                                color: "#14161b"
                                border.color: "#38bdf8"
                                Text {
                                    anchors.centerIn: parent
                                    text: "LIM " + StateStore.batteryChargeLimit + "%"
                                    color: "#38bdf8"
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: StateStore.batteryPct >= 0.99 ? "Full" : (StateStore.isCharging ? "Charging" : "On Bat")
                                color: "#8b929e"
                                font.pixelSize: 9
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "⚡" + Math.round(StateStore.batteryPct * 100) + "%"
                                color: "#a6d189"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: StateStore.cycleBatteryChargeLimit()
                        }
                    }
                }

                // =========================================================
                // TAB 1: MEDIA PLAYER
                // =========================================================
                Item {
                    anchors.fill: parent
                    opacity: StateStore.activeTab === 1 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle {
                        x: 34
                        y: 38
                        width: parent.width - 68
                        height: 128
                        radius: 20
                        color: "#0d0e11"
                        border.color: "#1f2229"

                        ClippingRectangle {
                            x: 16
                            y: 16
                            width: 96
                            height: 96
                            radius: 16
                            color: "#14161b"
                            Image {
                                anchors.fill: parent
                                source: StateStore.localArtUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "♪"
                                color: "#a6d189"
                                font.pixelSize: 36
                                font.bold: true
                                visible: StateStore.localArtUrl === ""
                            }
                        }

                        Column {
                            x: 128
                            anchors.verticalCenter: parent.verticalCenter
                            width: 242
                            spacing: 5

                            Rectangle {
                                width: srcTxt.implicitWidth + 16
                                height: 20
                                radius: 10
                                color: "#122b1d"
                                border.color: "#1e462f"
                                Text {
                                    id: srcTxt
                                    anchors.centerIn: parent
                                    text: "󰓇 " + (root.activePlayer && root.activePlayer.identity ? root.activePlayer.identity : "Media Stream")
                                    color: "#a6d189"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.activePlayer && root.activePlayer.trackTitle ? root.activePlayer.trackTitle : "Paper Sky"
                                color: "#ffffff"
                                font.pixelSize: 19
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.activePlayer && root.activePlayer.trackArtist ? root.activePlayer.trackArtist : "No media playing"
                                color: "#a6d189"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: StateStore.currentLyricLine !== "" ? ("♪ " + StateStore.currentLyricLine) : (root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : "Ready to play")
                                color: "#8b929e"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 154
                            height: 98
                            radius: 14
                            color: "#08090b"
                            border.color: StateStore.showLyricsPanel ? "#24472c" : "#181a20"
                            clip: true

                            Item {
                                anchors.fill: parent
                                visible: !StateStore.showLyricsPanel

                                Text {
                                    anchors.top: parent.top
                                    anchors.topMargin: 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "LIVE SPECTRUM"
                                    color: "#525866"
                                    font.pixelSize: 8
                                    font.bold: true
                                }

                                Row {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    height: 58

                                    Repeater {
                                        model: 15
                                        delegate: Rectangle {
                                            width: 4
                                            radius: 2
                                            anchors.bottom: parent.bottom
                                            readonly property real rawLvl: StateStore.audioBars[index % 5] || 0.0
                                            readonly property real modFactor: ((index * 3) % 4) * 0.14
                                            color: rawLvl > 0.03 ? (index % 2 === 0 ? "#a6d189" : "#38bdf8") : "#262932"
                                            height: {
                                                if (rawLvl > 0.02) {
                                                    return Math.min(58, Math.max(8, Math.round(8 + (rawLvl * (50 - modFactor * 18)))))
                                                }
                                                var idle = [8, 12, 16, 10, 18, 12, 8, 20, 14, 10, 16, 12, 14, 10, 8]
                                                return idle[index]
                                            }
                                            Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                        }
                                    }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: 8
                                visible: StateStore.showLyricsPanel

                                Text {
                                    anchors.centerIn: parent
                                    visible: StateStore.lyricsLoading || StateStore.lyricsList.length === 0
                                    text: StateStore.lyricsLoading ? "Loading lyrics..." : (StateStore.currentLyricLine !== "" ? StateStore.currentLyricLine : "No synced lyrics\nfor this track")
                                    horizontalAlignment: Text.AlignHCenter
                                    color: "#8b929e"
                                    font.pixelSize: 10
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    spacing: 4
                                    visible: !StateStore.lyricsLoading && StateStore.lyricsList.length > 0

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: (StateStore.currentLyricIndex > 0 && StateStore.lyricsList[StateStore.currentLyricIndex - 1]) ? StateStore.lyricsList[StateStore.currentLyricIndex - 1].text : "· · ·"
                                        color: "#525866"
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: StateStore.currentLyricLine !== "" ? StateStore.currentLyricLine : "♪ · · ·"
                                        color: "#a6d189"
                                        font.pixelSize: 11
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: (StateStore.currentLyricIndex >= 0 && StateStore.currentLyricIndex + 1 < StateStore.lyricsList.length) ? StateStore.lyricsList[StateStore.currentLyricIndex + 1].text : ""
                                        color: "#8b929e"
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        x: 34
                        y: 176
                        width: parent.width - 68
                        height: 102
                        radius: 20
                        color: "#0d0e11"
                        border.color: "#1f2229"

                        Item {
                            x: 18
                            y: 14
                            width: parent.width - 36
                            height: 22

                            Text {
                                id: pT
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.activePlayer ? StateStore.formatTime(root.activePlayer.position) : "00:00"
                                color: "#a6d189"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                id: rT
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: (!root.activePlayer || root.activePlayer.length <= 0) ? "-00:00" : "-" + StateStore.formatTime(Math.max(0, root.activePlayer.length - root.activePlayer.position))
                                color: "#8b929e"
                                font.pixelSize: 12
                            }

                            Rectangle {
                                anchors.left: pT.right
                                anchors.leftMargin: 14
                                anchors.right: rT.left
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                height: 6
                                radius: 3
                                color: "#1f2229"

                                Rectangle {
                                    width: (root.activePlayer && root.activePlayer.length > 0) ? parent.width * Math.min(1, root.activePlayer.position / root.activePlayer.length) : parent.width * 0.35
                                    height: parent.height
                                    radius: 3
                                    color: "#a6d189"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: m => {
                                        if (root.activePlayer && root.activePlayer.length > 0) root.activePlayer.position = Math.max(0, Math.min(1, m.x / width)) * root.activePlayer.length
                                    }
                                }
                            }
                        }

                        Item {
                            x: 18
                            y: 44
                            width: parent.width - 36
                            height: 46

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 92
                                height: 32
                                radius: 16
                                color: StateStore.showLyricsPanel ? "#122b1d" : "#14161b"
                                border.color: StateStore.showLyricsPanel ? "#a6d189" : "#262932"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Canvas {
                                        width: 13
                                        height: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                        property bool act: StateStore.showLyricsPanel
                                        onActChanged: requestPaint()
                                        Component.onCompleted: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.strokeStyle = act ? "#a6d189" : "#e4e4e7"
                                            ctx.lineWidth = 1.5
                                            ctx.roundedRect(1, 2, 11, 8, 2, 2)
                                            ctx.stroke()
                                        }
                                    }
                                    Text {
                                        text: "Lyrics"
                                        color: StateStore.showLyricsPanel ? "#a6d189" : "#e4e4e7"
                                        font.pixelSize: 11
                                        font.bold: StateStore.showLyricsPanel
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        StateStore.showLyricsPanel = !StateStore.showLyricsPanel
                                        StateStore.showRingToast(StateStore.showLyricsPanel ? "🎤 Lyrics View enabled" : "📊 Live Spectrum enabled")
                                    }
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 14

                                Rectangle {
                                    width: 38
                                    height: 32
                                    radius: 16
                                    color: "#14161b"
                                    border.color: "#262932"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: "-10s"; color: "#8b929e"; font.pixelSize: 10; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.position = Math.max(0, root.activePlayer.position - 10)
                                    }
                                }

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: "#14161b"
                                    border.color: "#262932"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Canvas {
                                        width: 14
                                        height: 14
                                        anchors.centerIn: parent
                                        Component.onCompleted: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.fillStyle = "#ffffff"
                                            ctx.fillRect(1, 2, 2.2, 10)
                                            ctx.beginPath()
                                            ctx.moveTo(12, 2)
                                            ctx.lineTo(4, 7)
                                            ctx.lineTo(12, 12)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.previous()
                                    }
                                }

                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 22
                                    color: "#122b1d"
                                    border.color: "#a6d189"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Canvas {
                                        width: 16
                                        height: 16
                                        anchors.centerIn: parent
                                        property bool playing: root.activePlayer ? root.activePlayer.isPlaying : false
                                        onPlayingChanged: requestPaint()
                                        Component.onCompleted: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.fillStyle = "#a6d189"
                                            if (playing) {
                                                ctx.roundedRect(2, 2, 4, 12, 1, 1)
                                                ctx.roundedRect(10, 2, 4, 12, 1, 1)
                                                ctx.fill()
                                            } else {
                                                ctx.beginPath()
                                                ctx.moveTo(3, 1.5)
                                                ctx.lineTo(14.5, 8)
                                                ctx.lineTo(3, 14.5)
                                                ctx.closePath()
                                                ctx.fill()
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
                                    }
                                }

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: "#14161b"
                                    border.color: "#262932"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Canvas {
                                        width: 14
                                        height: 14
                                        anchors.centerIn: parent
                                        Component.onCompleted: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.fillStyle = "#ffffff"
                                            ctx.fillRect(10.8, 2, 2.2, 10)
                                            ctx.beginPath()
                                            ctx.moveTo(2, 2)
                                            ctx.lineTo(10, 7)
                                            ctx.lineTo(2, 12)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer) root.activePlayer.next()
                                    }
                                }

                                Rectangle {
                                    width: 38
                                    height: 32
                                    radius: 16
                                    color: "#14161b"
                                    border.color: "#262932"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: "+10s"; color: "#8b929e"; font.pixelSize: 10; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.activePlayer && root.activePlayer.length > 0) root.activePlayer.position = Math.min(root.activePlayer.length, root.activePlayer.position + 10)
                                    }
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 92
                                height: 32
                                radius: 16
                                color: StateStore.splitLyricsEnabled ? "#122b1d" : "#14161b"
                                border.color: StateStore.splitLyricsEnabled ? "#a6d189" : "#262932"
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: StateStore.splitLyricsEnabled ? "#a6d189" : "#525866"
                                    }
                                    Text {
                                        text: "Pill Bar"
                                        color: StateStore.splitLyricsEnabled ? "#a6d189" : "#e4e4e7"
                                        font.pixelSize: 11
                                        font.bold: StateStore.splitLyricsEnabled
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        StateStore.splitLyricsEnabled = !StateStore.splitLyricsEnabled
                                        if (StateStore.splitLyricsEnabled && StateStore.currentLyricLine === "") {
                                            StateStore.currentLyricLine = (root.activePlayer && root.activePlayer.trackTitle) ? root.activePlayer.trackTitle : "♪ Listening..."
                                        }
                                        StateStore.showRingToast(StateStore.splitLyricsEnabled ? "💊 Floating Pill Lyrics ON (Close notch to see)" : "💊 Floating Pill Lyrics OFF")
                                    }
                                }
                            }
                        }
                    }
                }

                // =========================================================
                // TAB 2: WEATHER
                // =========================================================
                Item {
                    anchors.fill: parent
                    opacity: StateStore.activeTab === 2 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle {
                        x: 34
                        y: 36
                        width: parent.width - 68
                        height: 80
                        radius: 20
                        color: "#0d0e11"
                        border.color: "#1f2229"

                        Row {
                            anchors.centerIn: parent
                            spacing: 22

                            Canvas {
                                width: 64
                                height: 60
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: true
                                property string cond: StateStore.weatherCondition
                                onCondChanged: requestPaint()
                                Component.onCompleted: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = "#a6d189"
                                    ctx.fillStyle = "#a6d189"
                                    ctx.lineWidth = 3.5
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"

                                    ctx.beginPath()
                                    ctx.moveTo(18, 36)
                                    ctx.lineTo(46, 36)
                                    ctx.arc(46, 27, 9, Math.PI * 0.5, Math.PI * 1.5, true)
                                    ctx.arc(31, 20, 12, Math.PI * 0.1, Math.PI * 1.15, true)
                                    ctx.arc(18, 27, 9, Math.PI * 1.4, Math.PI * 0.5, true)
                                    ctx.stroke()

                                    if (cond.toLowerCase().indexOf("thunder") !== -1) {
                                        ctx.beginPath()
                                        ctx.moveTo(26, 42); ctx.lineTo(22, 49); ctx.lineTo(27, 49); ctx.lineTo(24, 56)
                                        ctx.moveTo(40, 42); ctx.lineTo(36, 49); ctx.lineTo(41, 49); ctx.lineTo(38, 56)
                                        ctx.stroke()
                                    } else {
                                        ctx.beginPath()
                                        ctx.moveTo(20, 43); ctx.lineTo(24, 53)
                                        ctx.moveTo(32, 43); ctx.lineTo(36, 53)
                                        ctx.moveTo(44, 43); ctx.lineTo(48, 53)
                                        ctx.stroke()
                                    }
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: -2
                                Text {
                                    text: StateStore.weatherTemp
                                    color: "#ffffff"
                                    font.pixelSize: 38
                                    font.bold: true
                                }
                                Text {
                                    text: StateStore.weatherCondition
                                    color: "#a6d189"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }

                    Row {
                        x: 34
                        y: 124
                        spacing: 10

                        Rectangle {
                            width: 177
                            height: 36
                            radius: 10
                            color: "#0d0e11"
                            border.color: "#1f2229"
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "💧"; color: "#38bdf8"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    spacing: -1
                                    Text { text: "Humidity"; color: "#8b929e"; font.pixelSize: 9 }
                                    Text { text: StateStore.weatherHumidity; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                }
                            }
                        }

                        Rectangle {
                            width: 177
                            height: 36
                            radius: 10
                            color: "#0d0e11"
                            border.color: "#1f2229"
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "🌡"; color: "#a6d189"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    spacing: -1
                                    Text { text: "Feels like"; color: "#8b929e"; font.pixelSize: 9 }
                                    Text { text: StateStore.weatherFeelsLike; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                }
                            }
                        }

                        Rectangle {
                            width: 177
                            height: 36
                            radius: 10
                            color: "#0d0e11"
                            border.color: "#1f2229"
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "💨"; color: "#a6d189"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    spacing: -1
                                    Text { text: "Wind"; color: "#8b929e"; font.pixelSize: 9 }
                                    Text { text: StateStore.weatherWind; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                }
                            }
                        }
                    }

                    Text {
                        x: 36
                        y: 166
                        text: "7-day forecast"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Row {
                        x: 34
                        y: 186
                        spacing: 7

                        Repeater {
                            model: StateStore.forecastDays
                            delegate: Rectangle {
                                width: 72
                                height: 96
                                radius: 12
                                color: "#0d0e11"
                                border.color: index === 0 ? "#24472c" : "#1f2229"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.day
                                        color: index === 0 ? "#a6d189" : "#ffffff"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.date
                                        color: "#8b929e"
                                        font.pixelSize: 8
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon
                                        font.pixelSize: 19
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.min + " / " + modelData.max
                                        color: "#a6d189"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // =========================================================
                // TAB 3: SHELF & SMART CLIPBOARD
                // =========================================================
                Item {
                    anchors.fill: parent
                    opacity: StateStore.activeTab === 3 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Item {
                        anchors.fill: parent
                        visible: !StateStore.shelfShowClipboard

                        Rectangle {
                            x: 34
                            y: 38
                            width: parent.width - 68
                            height: 164
                            radius: 18
                            color: "#08090b"
                            border.color: "#181a20"

                            Column {
                                anchors.centerIn: parent
                                spacing: 6
                                visible: StateStore.shelfFiles.length === 0
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "📂"
                                    font.pixelSize: 28
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Drop files here or click Paste above"
                                    color: "#8b929e"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Left-click: Open · Right-click: Copy URI · Middle-click: Remove"
                                    color: "#525866"
                                    font.pixelSize: 10
                                }
                            }

                            ListView {
                                anchors.fill: parent
                                anchors.margins: 12
                                orientation: ListView.Horizontal
                                spacing: 12
                                clip: true
                                visible: StateStore.shelfFiles.length > 0
                                model: StateStore.shelfFiles
                                delegate: Rectangle {
                                    width: 118
                                    height: 140
                                    radius: 14
                                    color: "#0d0e11"
                                    border.color: "#1f2229"

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        anchors.top: parent.top
                                        anchors.topMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        color: "#181a20"
                                        z: 5
                                        Text { anchors.centerIn: parent; text: "✕"; color: "#8b929e"; font.pixelSize: 9 }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: StateStore.removeShelfFile(index)
                                        }
                                    }

                                    Canvas {
                                        width: 52
                                        height: 52
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 16
                                        Component.onCompleted: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            if (modelData.isDir) {
                                                ctx.fillStyle = "#22c55e"
                                                ctx.beginPath()
                                                ctx.roundedRect(4, 10, 22, 10, 4, 4)
                                                ctx.fill()
                                                ctx.fillStyle = "#a6d189"
                                                ctx.beginPath()
                                                ctx.roundedRect(4, 15, 44, 32, 6, 6)
                                                ctx.fill()
                                            } else {
                                                ctx.fillStyle = "#38bdf8"
                                                ctx.beginPath()
                                                ctx.roundedRect(4, 4, 44, 44, 11, 11)
                                                ctx.fill()
                                                ctx.fillStyle = "#ffffff"
                                                ctx.beginPath()
                                                ctx.arc(34, 16, 5, 0, Math.PI * 2)
                                                ctx.fill()
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width - 14
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 78
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.name
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideMiddle
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 102
                                        width: szT.implicitWidth + 14
                                        height: 20
                                        radius: 10
                                        color: modelData.isDir ? "#122b1d" : "#12222e"
                                        Text {
                                            id: szT
                                            anchors.centerIn: parent
                                            text: modelData.isDir ? "Folder" : (modelData.sizeStr || "File")
                                            color: modelData.isDir ? "#a6d189" : "#38bdf8"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.topMargin: 24
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: m => {
                                            if (m.button === Qt.RightButton) StateStore.copyFileUriToClipboard(modelData.uri, modelData.path)
                                            else if (m.button === Qt.MiddleButton) StateStore.removeShelfFile(index)
                                            else StateStore.openFile(modelData.path)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            x: 34
                            y: 212
                            width: parent.width - 68
                            height: 66
                            radius: 16
                            color: "#0d0e11"
                            border.color: "#1f2229"

                            Text {
                                x: 14
                                y: 8
                                text: "QUICK FOLDERS"
                                color: "#525866"
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Row {
                                x: 12
                                y: 24
                                spacing: 8

                                Repeater {
                                    model: [
                                        { lbl: "📥 Downloads", path: Quickshell.env("HOME") + "/Downloads" },
                                        { lbl: "🖼 Pictures", path: Quickshell.env("HOME") + "/Pictures" },
                                        { lbl: "📄 Documents", path: Quickshell.env("HOME") + "/Documents" },
                                        { lbl: "⚙ .config", path: Quickshell.env("HOME") + "/.config" },
                                        { lbl: "🏠 Home", path: "/home/valle" }
                                    ]
                                    delegate: Rectangle {
                                        width: 100
                                        height: 30
                                        radius: 10
                                        color: "#14161b"
                                        border.color: "#262932"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.lbl
                                            color: "#e4e4e7"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: StateStore.openFile(modelData.path)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // VISTA DEL PORTAPAPELES CON SMART ACTIONS (Ping / Base64 / Hash) + MODO INCÓGNITO
                    Rectangle {
                        x: 34
                        y: 38
                        width: parent.width - 68
                        height: 240
                        radius: 18
                        color: "#08090b"
                        border.color: StateStore.clipboardIncognito ? "#ef4444" : "#181a20"
                        visible: StateStore.shelfShowClipboard

                        Text {
                            anchors.centerIn: parent
                            visible: StateStore.clipboardHistory.length === 0
                            text: StateStore.clipboardIncognito ? "🕵 Incognito Mode Active — Clipboard history paused" : "📋 Copy any text, IP, Hash or Base64 (Ctrl+C) to see it here"
                            color: StateStore.clipboardIncognito ? "#ef4444" : "#8b929e"
                            font.pixelSize: 12
                        }

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 7
                            clip: true
                            model: StateStore.clipboardHistory
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                radius: 10
                                color: "#0d0e11"
                                border.color: "#1f2229"

                                readonly property string smartKind: StateStore.detectClipAction(modelData.text)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8
                                    Text { text: "📋"; font.pixelSize: 12 }
                                    Text {
                                        text: modelData.text
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Botón de Smart Action contextual (Ping / Base64 / Hash)
                                    Rectangle {
                                        visible: smartKind !== ""
                                        width: saTxt.implicitWidth + 14
                                        height: 22
                                        radius: 8
                                        color: smartKind === "PING" ? "#122b1d" : (smartKind === "B64" ? "#12222e" : "#241b2f")
                                        border.color: smartKind === "PING" ? "#a6d189" : (smartKind === "B64" ? "#38bdf8" : "#c084fc")
                                        z: 5
                                        Text {
                                            id: saTxt
                                            anchors.centerIn: parent
                                            text: smartKind === "PING" ? "⚡ Ping" : (smartKind === "B64" ? "🔓 B64" : "🔐 Hash")
                                            color: smartKind === "PING" ? "#a6d189" : (smartKind === "B64" ? "#38bdf8" : "#c084fc")
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: StateStore.runSmartClipAction(modelData.text)
                                        }
                                    }

                                    Text {
                                        text: modelData.time || ""
                                        color: "#a6d189"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: smartKind !== "" ? 76 : 0
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: StateStore.copyTextToClipboard(modelData.text)
                                }
                            }
                        }
                    }
                }

                // =========================================================
                // TAB 4: TODOLIST & AGENDA
                // =========================================================
                Item {
                    anchors.fill: parent
                    opacity: StateStore.activeTab === 4 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Item {
                        x: 34
                        y: 38
                        width: 184
                        height: 240

                        Rectangle {
                            width: parent.width
                            height: 118
                            radius: 16
                            color: "#0d0e11"
                            border.color: "#1f2229"

                            Text {
                                x: 14
                                y: 8
                                color: "#a6d189"
                                font.pixelSize: 32
                                font.bold: true
                                text: StateStore.todoShowAgenda ? String(StateStore.agendaEvents.length) : (StateStore.todoList.filter(t => t.done).length + "/" + StateStore.todoList.length)
                            }
                            Text {
                                x: 14
                                y: 46
                                text: StateStore.todoEditMode ? "Click item to edit or ✕" : (StateStore.todoShowAgenda ? "Events Scheduled" : "Tasks Completed")
                                color: StateStore.todoEditMode ? "#a6d189" : "#8b929e"
                                font.pixelSize: 11
                            }

                            Row {
                                x: 10
                                y: 74
                                spacing: 8
                                visible: !StateStore.todoAddingMode
                                Rectangle {
                                    width: 78
                                    height: 30
                                    radius: 15
                                    color: "#14161b"
                                    border.color: "#262932"
                                    Text {
                                        anchors.centerIn: parent
                                        text: StateStore.todoShowAgenda ? "+ Event" : "+ Add Task"
                                        color: "#ffffff"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openTodoEditor(-1, "", "")
                                    }
                                }
                                Rectangle {
                                    width: 78
                                    height: 30
                                    radius: 15
                                    color: StateStore.todoEditMode ? "#122b1d" : "#14161b"
                                    border.color: StateStore.todoEditMode ? "#a6d189" : "#262932"
                                    Text {
                                        anchors.centerIn: parent
                                        text: StateStore.todoEditMode ? "✓ Done" : "✎ Edit"
                                        color: StateStore.todoEditMode ? "#a6d189" : "#ffffff"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            StateStore.todoEditMode = !StateStore.todoEditMode
                                            if (!StateStore.todoEditMode) root.closeTodoEditor()
                                        }
                                    }
                                }
                            }

                            Row {
                                x: 8
                                y: 74
                                spacing: 4
                                visible: StateStore.todoAddingMode

                                Rectangle {
                                    width: 46
                                    height: 30
                                    radius: 9
                                    color: "#14161b"
                                    border.color: todoTimeInput.activeFocus ? "#a6d189" : "#2c313c"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "HH:MM"
                                        color: "#8b929e"
                                        font.pixelSize: 8
                                        visible: todoTimeInput.text === "" && !todoTimeInput.activeFocus
                                    }
                                    TextInput {
                                        id: todoTimeInput
                                        anchors.fill: parent
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "#a6d189"
                                        font.pixelSize: 10
                                        font.bold: true
                                        maximumLength: 5
                                        KeyNavigation.tab: newTodoInput
                                        Keys.onEscapePressed: root.closeTodoEditor()
                                        onAccepted: newTodoInput.forceActiveFocus()
                                    }
                                }

                                Rectangle {
                                    width: 92
                                    height: 30
                                    radius: 9
                                    color: "#14161b"
                                    border.color: newTodoInput.activeFocus ? "#a6d189" : "#2c313c"
                                    clip: true
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: StateStore.todoShowAgenda ? "Event..." : "Task..."
                                        color: "#8b929e"
                                        font.pixelSize: 9
                                        visible: newTodoInput.text === "" && !newTodoInput.activeFocus
                                    }
                                    TextInput {
                                        id: newTodoInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "#ffffff"
                                        font.pixelSize: 10
                                        KeyNavigation.tab: todoTimeInput
                                        Keys.onEscapePressed: root.closeTodoEditor()
                                        onAccepted: {
                                            if (newTodoInput.text.trim() !== "") {
                                                StateStore.submitTodoOrEvent(newTodoInput.text, todoTimeInput.text)
                                                root.closeTodoEditor()
                                            } else {
                                                root.closeTodoEditor()
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 22
                                    height: 30
                                    radius: 9
                                    color: "#271416"
                                    border.color: "#ef4444"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: "#ef4444"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.closeTodoEditor()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            y: 126
                            width: parent.width
                            height: 114
                            radius: 16
                            color: "#0d0e11"
                            border.color: StateStore.pomodoroRunning ? "#a6d189" : "#1f2229"

                            RowLayout {
                                x: 12
                                y: 10
                                width: parent.width - 24
                                Text {
                                    text: StateStore.pomodoroIsBreak ? "☕ BREAK TIMER" : "🍅 FOCUS TIMER"
                                    color: StateStore.pomodoroRunning ? "#a6d189" : "#8b929e"
                                    font.pixelSize: 9
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: StateStore.pomodoroCompletedToday + " done"
                                    color: "#38bdf8"
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 30
                                text: StateStore.formatTime(StateStore.pomodoroRemainingSeconds)
                                color: "#ffffff"
                                font.pixelSize: 26
                                font.bold: true
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 72
                                spacing: 8

                                Rectangle {
                                    width: 88
                                    height: 28
                                    radius: 14
                                    color: StateStore.pomodoroRunning ? "#271416" : "#122b1d"
                                    border.color: StateStore.pomodoroRunning ? "#ef4444" : "#a6d189"
                                    Text {
                                        anchors.centerIn: parent
                                        text: StateStore.pomodoroRunning ? "⏸ Pause" : "▶ Start"
                                        color: StateStore.pomodoroRunning ? "#ef4444" : "#a6d189"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: StateStore.pomodoroRunning = !StateStore.pomodoroRunning
                                    }
                                }

                                Rectangle {
                                    width: 64
                                    height: 28
                                    radius: 14
                                    color: "#14161b"
                                    border.color: "#262932"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "↺ Reset"
                                        color: "#a1a1aa"
                                        font.pixelSize: 10
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            StateStore.pomodoroRunning = false
                                            StateStore.pomodoroIsBreak = false
                                            StateStore.pomodoroRemainingSeconds = StateStore.pomodoroFocusMinutes * 60
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        x: 228
                        y: 38
                        width: parent.width - 262
                        height: 240
                        radius: 18
                        color: "#08090b"
                        border.color: "#181a20"

                        ListView {
                            id: aLV
                            visible: StateStore.todoShowAgenda
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 7
                            clip: true
                            model: StateStore.agendaEvents
                            delegate: Rectangle {
                                width: aLV.width
                                height: 38
                                radius: 12
                                color: (StateStore.todoAddingMode && StateStore.todoEditingIndex === index) ? "#0e2216" : "#0d0e11"
                                border.color: StateStore.todoEditMode ? "#38bdf8" : "#1f2229"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Rectangle {
                                        width: 46
                                        height: 22
                                        radius: 6
                                        color: "#0e2216"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.time
                                            color: "#a6d189"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    Text {
                                        text: modelData.title
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: StateStore.todoEditMode
                                        text: "✎"
                                        color: "#38bdf8"
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        visible: StateStore.todoEditMode
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "#271416"
                                        z: 5
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: "#ef4444"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: StateStore.removeAgendaEvent(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: StateStore.todoEditMode ? 28 : 0
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (StateStore.todoEditMode) {
                                            root.openTodoEditor(index, modelData.time, modelData.title)
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            id: tLV
                            visible: !StateStore.todoShowAgenda
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 7
                            clip: true
                            model: StateStore.todoList
                            delegate: Rectangle {
                                width: tLV.width
                                height: 38
                                radius: 12
                                color: (StateStore.todoAddingMode && StateStore.todoEditingIndex === index) ? "#0e2216" : (modelData.done ? "#0b1710" : "#0d0e11")
                                border.color: StateStore.todoEditMode ? "#38bdf8" : (modelData.done ? "#1c3825" : "#1f2229")
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: modelData.done ? "#a6d189" : "transparent"
                                        border.color: modelData.done ? "#a6d189" : "#525866"
                                        border.width: 2
                                        Text {
                                            anchors.centerIn: parent
                                            visible: modelData.done
                                            text: "✓"
                                            color: "#000000"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        visible: (modelData.time || "") !== ""
                                        width: 40
                                        height: 20
                                        radius: 5
                                        color: "#0e2216"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.time || ""
                                            color: "#a6d189"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }

                                    Text {
                                        text: modelData.text
                                        color: modelData.done ? "#8b929e" : "#ffffff"
                                        font.pixelSize: 12
                                        font.strikeout: modelData.done
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: StateStore.todoEditMode
                                        text: "✎"
                                        color: "#38bdf8"
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        visible: StateStore.todoEditMode
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "#271416"
                                        z: 5
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: "#ef4444"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: StateStore.removeTodo(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: StateStore.todoEditMode ? 28 : 0
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (StateStore.todoEditMode) {
                                            root.openTodoEditor(index, modelData.time || "", modelData.text)
                                        } else {
                                            StateStore.toggleTodo(index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =========================================================
                // TAB 5: CALENDAR
                // =========================================================
                CalendarView {
                    anchors.fill: parent
                    opacity: StateStore.activeTab === 5 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                z: 10
                Repeater {
                    model: 6
                    delegate: Rectangle {
                        width: StateStore.activeTab === index ? 16 : 5
                        height: 4
                        radius: 2
                        color: StateStore.activeTab === index ? "#a6d189" : "#2c313c"
                        Behavior on width { NumberAnimation { duration: 180 } }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: StateStore.activeTab = index
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                root.isHovering = true
                localHoverLeaveTimer.stop()
                StateStore.triggerMascotMood("wink", 600)
                root.localState = "EXPANDED"
            } else {
                root.isHovering = false
                if (!root.isEditingLocal) {
                    localHoverLeaveTimer.restart()
                }
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        onTapped: {
            if (root.localState !== "EXPANDED") StateStore.toggleMinimalMode()
        }
    }
}
