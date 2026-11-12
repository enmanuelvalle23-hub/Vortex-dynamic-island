import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property int todayYear: new Date().getFullYear()
    property int todayMonth: new Date().getMonth()
    property int todayDate: new Date().getDate()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var monthNamesUpper: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    // Porcentaje del año transcurrido (ej: 2026 [━━━━──] 81%)
    readonly property int yearProgressPct: {
        var now = new Date()
        var start = new Date(now.getFullYear(), 0, 1)
        var end = new Date(now.getFullYear() + 1, 0, 1)
        return Math.round(((now - start) / (end - start)) * 100)
    }

    property var weeksModel: []

    function getISOWeek(d) {
        var date = new Date(d.getTime())
        date.setHours(0, 0, 0, 0)
        date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7)
        var week1 = new Date(date.getFullYear(), 0, 4)
        return 1 + Math.round(((date.getTime() - week1.getTime()) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7)
    }

    function rebuildCalendar() {
        var firstDay = new Date(viewYear, viewMonth, 1)
        var startDow = firstDay.getDay() // 0 = SUN
        var cur = new Date(viewYear, viewMonth, 1 - startDow)
        var rows = []
        for (var w = 0; w < 6; w++) {
            var thu = new Date(cur.getFullYear(), cur.getMonth(), cur.getDate() + 4)
            var wNum = getISOWeek(thu)
            var days = []
            for (var d = 0; d < 7; d++) {
                var isCurMonth = (cur.getMonth() === viewMonth)
                var isWeekend = (d === 0 || d === 6)
                var isToday = (cur.getFullYear() === todayYear && cur.getMonth() === todayMonth && cur.getDate() === todayDate)
                days.push({
                    dayNum: cur.getDate(),
                    inMonth: isCurMonth,
                    weekend: isWeekend,
                    today: isToday
                })
                cur.setDate(cur.getDate() + 1)
            }
            rows.push({ weekNum: wNum, days: days })
        }
        weeksModel = rows
    }

    function prevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11
            viewYear -= 1
        } else {
            viewMonth -= 1
        }
        rebuildCalendar()
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0
            viewYear += 1
        } else {
            viewMonth += 1
        }
        rebuildCalendar()
    }

    Component.onCompleted: rebuildCalendar()

    Column {
        anchors.fill: parent
        anchors.topMargin: 36
        anchors.bottomMargin: 18
        anchors.leftMargin: 44
        anchors.rightMargin: 44
        spacing: 5

        // 1. Título Grande Monospace: [📅] October 25
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Canvas {
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = "#ffffff"; ctx.fillStyle = "#ffffff"; ctx.lineWidth = 2.0
                    ctx.beginPath(); ctx.roundedRect(2, 4, 18, 16, 3, 3); ctx.stroke()
                    ctx.fillRect(2, 4, 18, 5)
                    ctx.fillRect(6, 1, 2, 4); ctx.fillRect(14, 1, 2, 4)
                    ctx.fillRect(12, 12, 4, 4)
                }
            }

            Text {
                text: root.monthNames[root.todayMonth] + " " + root.todayDate
                color: "#ffffff"
                font.family: "monospace"
                font.pixelSize: 22
                font.bold: true
            }
        }

        // 2. Barra de Progreso del Año: 2026 [━━━━━━━━━━───] 81%
        RowLayout {
            width: parent.width
            spacing: 10

            Text {
                text: String(root.viewYear)
                color: "#71717a"
                font.family: "monospace"
                font.pixelSize: 10
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: "#222226"

                Rectangle {
                    width: parent.width * (root.yearProgressPct / 100.0)
                    height: parent.height
                    radius: 2
                    color: "#3f3f46"
                }
            }

            Text {
                text: root.yearProgressPct + "%"
                color: "#d4d4d8"
                font.family: "monospace"
                font.pixelSize: 10
                font.bold: true
            }
        }

        // 3. Cabecera de Columnas: W | SUN MON TUE WED THU FRI SAT
        Row {
            width: parent.width
            height: 16

            Text {
                width: 36
                horizontalAlignment: Text.AlignHCenter
                text: "W"
                color: "#71717a"
                font.family: "monospace"
                font.pixelSize: 9
                font.bold: true
            }

            Item { width: 8; height: 1 }

            Repeater {
                model: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
                delegate: Text {
                    width: (parent.width - 44) / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: "#71717a"
                    font.family: "monospace"
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }

        // 4. Filas de Semanas (W 40..45 + Días)
        Item {
            width: parent.width
            height: 108

            // Línea divisoria vertical a la derecha de la columna W
            Rectangle {
                x: 38
                y: 0
                width: 1
                height: parent.height
                color: "#222226"
            }

            Column {
                anchors.fill: parent
                spacing: 2

                Repeater {
                    model: root.weeksModel
                    delegate: Row {
                        width: parent.width
                        height: 16

                        // Número de semana (40, 41, 42...)
                        Text {
                            width: 36
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.weekNum
                            color: "#71717a"
                            font.family: "monospace"
                            font.pixelSize: 10
                        }

                        Item { width: 8; height: 1 }

                        // Los 7 días de la semana
                        Repeater {
                            model: modelData.days
                            delegate: Item {
                                width: (parent.width - 44) / 7
                                height: 16

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 15
                                    radius: 4
                                    color: modelData.today ? "#22c55e" : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.dayNum
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    font.bold: modelData.today || (modelData.inMonth && !modelData.weekend)
                                    color: {
                                        if (modelData.today) return "#000000"
                                        if (!modelData.inMonth) return "#3f3f46"
                                        if (modelData.weekend) return "#71717a"
                                        return "#ffffff"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 5. Barra Inferior de Navegación de Mes: <   OCTOBER 2026   >
        Item {
            width: parent.width
            height: 18

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "<"
                color: "#d4d4d8"
                font.family: "monospace"
                font.pixelSize: 13
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prevMonth()
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.monthNamesUpper[root.viewMonth] + " " + root.viewYear
                color: "#71717a"
                font.family: "monospace"
                font.pixelSize: 10
                font.bold: true
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: ">"
                color: "#d4d4d8"
                font.family: "monospace"
                font.pixelSize: 13
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextMonth()
                }
            }
        }
    }
}
