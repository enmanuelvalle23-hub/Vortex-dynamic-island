import QtQuick

Item {
    id: root
    width: 36
    height: 22

    property real phase: 0.0

    // Si la CPU pasa de 75°C o hay batería crítica, la onda duplica su velocidad de oscilación
    readonly property bool highLoad: StateStore.cpuTemp >= 75 || StateStore.criticalBatteryWarning
    readonly property real speedStep: highLoad ? 0.34 : (StateStore.isMusicPlaying ? 0.22 : 0.11)

    Timer {
        interval: 35
        running: true
        repeat: true
        onTriggered: {
            root.phase = (root.phase + root.speedStep) % (Math.PI * 200)
            waveCanvas.requestPaint()
        }
    }

    Canvas {
        id: waveCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = width
            var h = height
            var cy = h / 2
            var amp = root.highLoad ? 6.2 : (StateStore.isMusicPlaying ? 5.2 : 3.8)

            var primaryColor = "#a6d189"
            var secondaryColor = "#38bdf8"

            if (StateStore.criticalBatteryWarning || StateStore.cpuTemp >= 85) {
                primaryColor = "#ef4444"
                secondaryColor = "#f59e0b"
            } else if (StateStore.cpuTemp >= 75) {
                primaryColor = "#f59e0b"
                secondaryColor = "#a6d189"
            }

            // Onda secundaria entrelazada (desfasada)
            ctx.beginPath()
            ctx.strokeStyle = secondaryColor
            ctx.lineWidth = 1.4
            ctx.lineCap = "round"
            for (var x2 = 2; x2 <= w - 2; x2 += 1.5) {
                var norm2 = (x2 - 2) / (w - 4)
                var env2 = Math.sin(norm2 * Math.PI)
                var y2 = cy + Math.sin((norm2 * Math.PI * 2.5) - root.phase + 1.6) * (amp * 0.85 * env2)
                if (x2 === 2) ctx.moveTo(x2, y2)
                else ctx.lineTo(x2, y2)
            }
            ctx.stroke()

            // Onda principal frontal
            ctx.beginPath()
            ctx.strokeStyle = primaryColor
            ctx.lineWidth = 2.0
            ctx.lineCap = "round"
            for (var x1 = 2; x1 <= w - 2; x1 += 1.5) {
                var norm1 = (x1 - 2) / (w - 4)
                var env1 = Math.sin(norm1 * Math.PI)
                var y1 = cy + Math.sin((norm1 * Math.PI * 2.5) + root.phase) * (amp * env1)
                if (x1 === 2) ctx.moveTo(x1, y1)
                else ctx.lineTo(x1, y1)
            }
            ctx.stroke()
        }
    }
}
