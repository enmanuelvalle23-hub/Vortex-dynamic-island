import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Color principal según el tipo de alerta: Verde (#22c55e) para Carga/Agua, Celeste (#38bdf8) para Bluetooth/Volumen/Wi-Fi
    readonly property string ringColor: {
        if (StateStore.currentAlertType === "battery") return "#22c55e"
        if (StateStore.currentAlertType === "bluetooth") return "#38bdf8"
        if (StateStore.currentAlertType === "wifi") return StateStore.currentAlertValue > 0 ? "#38bdf8" : "#ef4444"
        return "#22c55e"
    }

    readonly property string trackColor: {
        if (StateStore.currentAlertType === "battery") return "#143824"
        if (StateStore.currentAlertType === "bluetooth") return "#27272a"
        return "#1f2937"
    }

    // IZQUIERDA: Aro grueso con icono central (⚡ en Charging, ᛒ en Bluetooth)
    Item {
        id: leftRing
        width: 44; height: 44
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter

        Canvas {
            id: alertArcCanvas
            anchors.fill: parent
            antialiasing: true
            property real val: StateStore.currentAlertValue >= 0 ? StateStore.currentAlertValue : 0.75
            property string col: root.ringColor
            property string trk: root.trackColor
            onValChanged: requestPaint()
            onColChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2
                var cy = height / 2
                var r = 17
                ctx.lineWidth = 5.2
                ctx.lineCap = "round"

                // Pista circular de fondo
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
                ctx.strokeStyle = trk
                ctx.stroke()

                // Arco de progreso activo
                var startAngle = -Math.PI / 2
                var endAngle = startAngle + (Math.PI * 2 * Math.max(0.08, Math.min(1.0, val)))
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, endAngle, false)
                ctx.strokeStyle = col
                ctx.stroke()
            }
        }

        // Icono interior blanco (Rayo ⚡, Bluetooth ᛒ, Volumen, etc.)
        Text {
            anchors.centerIn: parent
            text: StateStore.currentAlertIcon !== "" ? StateStore.currentAlertIcon : "⚡"
            color: "#ffffff"
            font.pixelSize: 15
            font.bold: true
        }
    }

    // CENTRO: Título grande en blanco bold ("Charging" / "AirBuds Pro") + Subtítulo gris ("Charger connected" / "Connected · 70%")
    Column {
        anchors.left: leftRing.right
        anchors.leftMargin: 16
        anchors.right: rightIndicator.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: StateStore.currentAlertTitle
            color: "#ffffff"
            font.pixelSize: 18
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: StateStore.currentAlertDetail !== ""
            text: StateStore.currentAlertDetail
            color: "#71717a"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    // DERECHA: Porcentaje grande "70%" (en Charging/Volume) O Doble Anillo Azul con Audífonos (en Bluetooth)
    Item {
        id: rightIndicator
        width: 68; height: 54
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter

        // Modo 1: Texto grande "70%" (Foto 1: Charging)
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: StateStore.currentAlertType !== "bluetooth"
            text: StateStore.currentAlertValue >= 0 ? Math.round(StateStore.currentAlertValue * 100) + "%" : ""
            color: "#ffffff"
            font.pixelSize: 28
            font.weight: Font.Normal
        }

        // Modo 2: Doble círculo azul concéntrico con icono de audífonos (Foto 2: AirBuds Pro)
        Item {
            width: 54; height: 54
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: StateStore.currentAlertType === "bluetooth"

            Canvas {
                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2
                    var cy = height / 2

                    // Fondo circular azul noche oscuro
                    ctx.fillStyle = "#081420"
                    ctx.beginPath()
                    ctx.arc(cx, cy, 26, 0, Math.PI * 2)
                    ctx.fill()

                    // Anillo exterior azul tenue
                    ctx.strokeStyle = "#163a59"
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.arc(cx, cy, 22, 0, Math.PI * 2)
                    ctx.stroke()

                    // Anillo interior celeste brillante
                    ctx.strokeStyle = "#2970a6"
                    ctx.lineWidth = 1.8
                    ctx.beginPath()
                    ctx.arc(cx, cy, 16, 0, Math.PI * 2)
                    ctx.stroke()

                    // Icono vectorial blanco de audífonos de diadema en el centro
                    ctx.strokeStyle = "#ffffff"
                    ctx.lineWidth = 1.8
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(cx, cy, 6.5, Math.PI, 0, false)
                    ctx.stroke()
                    // Almohadillas izquierda y derecha
                    ctx.strokeRect(cx - 6.5, cy, 3, 5.5)
                    ctx.strokeRect(cx + 3.5, cy, 3, 5.5)
                }
            }
        }
    }
}
