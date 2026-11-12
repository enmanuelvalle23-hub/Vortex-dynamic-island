pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int topBarOffset: 0
    property real omacleScale: 1.25
    property real omacleRounding: 0.95
    property int horizontalOffset: 0
    property bool minimalMode: false
    property bool mascotInClosed: true
    property bool isFullscreen: false
    property string mascotTemporaryMood: ""
    property bool isMusicPlaying: false
    property bool lowBatteryWarning: false
    property bool criticalBatteryWarning: false
    property string ringToastText: ""
    property bool ringToastVisible: false
    property string lastKeyboardLayout: ""
    property int activeTab: 0
    property int forceExpandSeq: 0

    property string currentTimeStr: "12:00"
    property string currentDateStr: "Wed 11 Nov 2026"
    property string spanishDateStr: "miércoles, noviembre 11"

    function updateGlobalClock() {
        var d = new Date()
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var esDays = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
        var esMonths = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        root.currentDateStr = days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear()
        root.spanishDateStr = esDays[d.getDay()] + ", " + esMonths[d.getMonth()] + " " + d.getDate()
        root.currentTimeStr = String(d.getHours()).padStart(2, '0') + ":" + String(d.getMinutes()).padStart(2, '0')
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateGlobalClock()
    }

    property int alertSeq: 0
    property int mediaPeekSeq: 0
    property string currentAlertType: ""
    property string currentAlertTitle: ""
    property string currentAlertDetail: ""
    property real currentAlertValue: -1
    property string currentAlertIcon: ""

    property var audioBars: [0.0, 0.0, 0.0, 0.0, 0.0]

    // Métricas de rendimiento + Módulo Net & Sec + Control de Carga
    property string rogProfile: "Balanced"
    property int cpuTemp: 72
    property real cpuUsage: 12.6
    property int gpuTemp: 52
    property real gpuUsage: 23.0
    property real ramPct: 38.6
    property string ramGbText: "14.9 / 38.6 GiB"
    property real diskPct: 65.7
    property string diskGbText: "405 / 616.9 GiB"
    property string netDownStr: "444 B/s"
    property string netUpStr: "574 B/s"
    property string netTotalStr: "↓765 KiB ↑479 KiB"
    property var netHistory: [0.1, 0.15, 0.08, 0.12, 0.45, 0.1, 0.05, 0.08, 0.65, 0.12, 0.05, 0.1]

    // Nuevas propiedades Net & Sec + Battery Charge Limit
    property bool vpnActive: false
    property string vpnName: "Tailscale"
    property string vpnIp: "Offline"
    property int listenPortsCount: 0
    property int batteryChargeLimit: 80

    property int brightnessPct: 75
    property int pendingBrightness: -1
    property int volumePct: 65
    property real batteryPct: 1.0
    property bool isCharging: true
    property string ringMode: "battery"

    property string currentTrackKey: ""
    property var lyricsList: []
    property int currentLyricIndex: -1
    property string currentLyricLine: ""
    property bool showLyricsPanel: false
    property bool splitLyricsEnabled: false
    property bool lyricsLoading: false
    property string localArtUrl: ""
    property string lastRawArtUrl: ""

    property bool pomodoroRunning: false
    property bool pomodoroIsBreak: false
    property int pomodoroFocusMinutes: 25
    property int pomodoroBreakMinutes: 5
    property int pomodoroRemainingSeconds: 1500
    property int pomodoroCompletedToday: 0

    property string weatherTemp: "25°C"
    property string weatherCondition: "Thunderstorm"
    property string weatherFeelsLike: "29°C"
    property string weatherHumidity: "95%"
    property string weatherWind: "11 km/h"
    property string weatherSunrise: "06:37"
    property string weatherSunset: "18:09"
    property string weatherIcon: "⛈️"
    property var forecastDays: [
        { day: "Today", date: "nov 11", icon: "⛈️", min: "24°", max: "28°" },
        { day: "jue", date: "nov 12", icon: "🌧️", min: "24°", max: "28°" },
        { day: "vie", date: "nov 13", icon: "🌧️", min: "24°", max: "31°" },
        { day: "sáb", date: "nov 14", icon: "🌧️", min: "23°", max: "30°" },
        { day: "dom", date: "nov 15", icon: "🌧️", min: "23°", max: "31°" },
        { day: "lun", date: "nov 16", icon: "🌧️", min: "23°", max: "30°" },
        { day: "mar", date: "nov 17", icon: "🌧️", min: "22°", max: "30°" }
    ]

    property var shelfFiles: []
    property var clipboardHistory: []
    property bool shelfShowClipboard: false
    property bool clipboardIncognito: false

    property var todoList: []
    property var agendaEvents: []
    property bool todoShowAgenda: false
    property bool todoEditMode: false
    property bool todoAddingMode: false
    property int todoEditingIndex: -1

    readonly property string stateFilePath: Quickshell.env("HOME") + "/.local/share/vortex-linux/state.json"
    readonly property string agendaFilePath: Quickshell.env("HOME") + "/.local/share/vortex-linux/agenda.txt"
    readonly property string ipcCmdFilePath: "/tmp/vortex_ctl_cmd"

    Timer { id: rToastT; interval: 2400; repeat: false; onTriggered: root.ringToastVisible = false }
    Timer { id: moodResetTimer; repeat: false; onTriggered: root.mascotTemporaryMood = "" }

    // Monitor de Telemetría + Net & Sec (Tailscale/VPN IP, Puertos LISTEN y Límite de Batería)
    Process {
        id: extraMetricsProc
        command: ["bash", "-c", "
            read -r _ u1 n1 s1 i1 w1 x1 y1 _ < /proc/stat
            r1=$(awk '/Inter-|face/{next} {r+=$2; t+=$10} END{print r, t}' /proc/net/dev)
            sleep 0.45
            read -r _ u2 n2 s2 i2 w2 x2 y2 _ < /proc/stat
            r2=$(awk '/Inter-|face/{next} {r+=$2; t+=$10} END{print r, t}' /proc/net/dev)
            t1=$((u1+n1+s1+i1+w1+x1+y1)); t2=$((u2+n2+s2+i2+w2+x2+y2))
            dt=$((t2-t1)); di=$(( (i2+w2) - (i1+w1) ))
            cpu_p=$(awk -v dt=\"$dt\" -v di=\"$di\" 'BEGIN{if(dt>0) printf \"%.1f\", (dt-di)*100.0/dt; else print \"0.0\"}')
            gpu_p=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ')
            [ -z \"$gpu_p\" ] && gpu_p=11
            mem_info=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{u=t-a; printf \"%.1f|%.1f / %.1f GiB\", (u/t)*100, u/1048576, t/1048576}' /proc/meminfo)
            dsk_info=$(df -B1 / | awk 'NR==2{u=$3; t=$2; printf \"%.1f|%.1f / %.1f GiB\", (u/t)*100, u/1073741824, t/1073741824}')
            rx1=$(echo \"$r1\" | cut -d' ' -f1); tx1=$(echo \"$r1\" | cut -d' ' -f2)
            rx2=$(echo \"$r2\" | cut -d' ' -f1); tx2=$(echo \"$r2\" | cut -d' ' -f2)
            drx=$(( (rx2-rx1)*2 )); dtx=$(( (tx2-tx1)*2 ))
            fmt_spd() {
                local b=$1
                if [ \"$b\" -ge 1048576 ]; then awk -v b=\"$b\" 'BEGIN{printf \"%.1f MiB/s\", b/1048576}'
                elif [ \"$b\" -ge 1024 ]; then awk -v b=\"$b\" 'BEGIN{printf \"%.1f KiB/s\", b/1024}'
                else echo \"${b} B/s\"; fi
            }
            fmt_tot() {
                local b=$1
                if [ \"$b\" -ge 1073741824 ]; then awk -v b=\"$b\" 'BEGIN{printf \"%.1f GiB\", b/1073741824}'
                else awk -v b=\"$b\" 'BEGIN{printf \"%.0f MiB\", b/1048576}'; fi
            }
            # Detección real de BackendState en Tailscale + Respaldo WireGuard/OpenVPN
            vpn_state=0
            vpn_name=\"Tailscale\"
            vpn_ip=\"Offline\"
            if command -v tailscale >/dev/null 2>&1; then
                ts_status=$(tailscale status --json 2>/dev/null)
                if echo \"$ts_status\" | grep -q '\"BackendState\": \"Running\"'; then
                    vpn_state=1
                    vpn_ip=$(tailscale ip -4 2>/dev/null | head -n1 | tr -d '[:space:]')
                    [ -z \"$vpn_ip\" ] && vpn_ip=$(ip -4 -o addr show dev tailscale0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
                fi
            fi
            if [ \"$vpn_state\" -eq 0 ]; then
                vpn_iface=$(ip -4 -o addr show 2>/dev/null | awk '$2 ~ /^(tun|wg|tap|proton|nord)/ {print $2\":\"$4}' | head -n1)
                if [ -n \"$vpn_iface\" ]; then
                    vpn_state=1
                    vpn_name=$(echo \"$vpn_iface\" | cut -d: -f1)
                    vpn_ip=$(echo \"$vpn_iface\" | cut -d: -f2 | cut -d/ -f1)
                fi
            fi
            # Contador de puertos locales en LISTEN
            l_ports=$(ss -tulnH 2>/dev/null | wc -l)
            # Límite físico de batería actual
            bat_lim=$(cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n1 | tr -d ' ')
            echo \"${cpu_p}|${gpu_p}|${mem_info}|${dsk_info}|$(fmt_spd $drx)|$(fmt_spd $dtx)|↓$(fmt_tot $rx2) ↑$(fmt_tot $tx2)|${drx}|${vpn_state}|${vpn_name}|${vpn_ip}|${l_ports}|${bat_lim}\"
        "]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var p = line.trim().split("|")
                if (p.length >= 10) {
                    root.cpuUsage = parseFloat(p[0]) || 0.0
                    root.gpuUsage = parseFloat(p[1]) || 0.0
                    root.ramPct = parseFloat(p[2]) || 0.0
                    root.ramGbText = p[3]
                    root.diskPct = parseFloat(p[4]) || 0.0
                    root.diskGbText = p[5]
                    root.netDownStr = p[6]
                    root.netUpStr = p[7]
                    root.netTotalStr = p[8]
                    var rawRx = parseFloat(p[9]) || 0
                    var normNet = Math.min(1.0, Math.max(0.05, Math.log10(rawRx + 10) / 7.0))
                    var nh = root.netHistory.slice(1)
                    nh.push(normNet)
                    root.netHistory = nh
                    if (p.length >= 15) {
                        root.vpnActive = (p[10] === "1")
                        root.vpnName = p[11] || "Tailscale"
                        root.vpnIp = p[12] || "Offline"
                        root.listenPortsCount = parseInt(p[13], 10) || 0
                        var bl = parseInt(p[14], 10)
                        if (!isNaN(bl) && bl >= 40 && bl <= 100) {
                            root.batteryChargeLimit = bl
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 2200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!extraMetricsProc.running) extraMetricsProc.running = true
    }

    // Motor de Espectro de Audio en Vivo (con splitMarker "\n" corregido)
    Process {
        id: audioVisProc
        running: true
        command: [Quickshell.env("HOME") + "/.config/quickshell/vortex/scripts/audio_spectrum.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var p = line.trim().split(";")
                if (p.length >= 5) {
                    var b0 = Math.min(1.0, Math.max(0.0, (parseInt(p[0], 10) || 0) / 100.0))
                    var b1 = Math.min(1.0, Math.max(0.0, (parseInt(p[1], 10) || 0) / 100.0))
                    var b2 = Math.min(1.0, Math.max(0.0, (parseInt(p[2], 10) || 0) / 100.0))
                    var b3 = Math.min(1.0, Math.max(0.0, (parseInt(p[3], 10) || 0) / 100.0))
                    var b4 = Math.min(1.0, Math.max(0.0, (parseInt(p[4], 10) || 0) / 100.0))
                    root.audioBars = [b0, b1, b2, b3, b4]
                }
            }
        }
    }

    // Lector IPC para el CLI vortex-ctl
    Process {
        id: ipcPollProc
        command: ["bash", "-c", "if [ -s /tmp/vortex_ctl_cmd ]; then cat /tmp/vortex_ctl_cmd; : > /tmp/vortex_ctl_cmd; fi"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var cmdLine = line.trim()
                if (!cmdLine) return
                var parts = cmdLine.split("|")
                var action = parts[0]
                if (action === "TAB" && parts.length >= 2) {
                    var tIdx = parseInt(parts[1], 10)
                    if (!isNaN(tIdx) && tIdx >= 0 && tIdx <= 5) {
                        root.activeTab = tIdx
                        root.forceExpandSeq++
                    }
                } else if (action === "MINIMAL") {
                    root.toggleMinimalMode()
                } else if (action === "ALERT") {
                    var title = parts[1] || "Vortex Alert"
                    var detail = parts[2] || ""
                    var icon = parts[3] || "⚡"
                    root.enterAlertPopup("info", title, detail, 1.0, icon)
                } else if (action === "INCOGNITO") {
                    root.toggleClipboardIncognito()
                } else if (action === "LIMIT" && parts.length >= 2) {
                    var lim = parseInt(parts[1], 10)
                    if (!isNaN(lim)) root.applyBatteryChargeLimit(lim)
                }
            }
        }
    }

    Timer {
        interval: 350
        running: true
        repeat: true
        onTriggered: if (!ipcPollProc.running) ipcPollProc.running = true
    }

    // Funciones Net & Sec (Tailscale Toggle & Copy IP)
    function copyVpnIp() {
        if (vpnActive && vpnIp !== "Offline") {
            copyTextToClipboard(vpnIp)
            showRingToast("🔒 " + vpnName + " IP copied: " + vpnIp)
        } else {
            toggleTailscaleTunnel()
        }
    }

    function toggleTailscaleTunnel() {
        var targetState = !vpnActive
        vpnActive = targetState
        if (!targetState) vpnIp = "Offline"
        var targetCmd = targetState
            ? "(tailscale up --operator=$USER 2>/dev/null || tailscale up 2>/dev/null || pkexec tailscale up)"
            : "(tailscale down 2>/dev/null || pkexec tailscale down)"
        showRingToast(targetState ? "⚡ Tailscale Connected!" : "🔌 Tailscale Disconnected")
        vpnProc.command = ["bash", "-c", targetCmd]
        vpnProc.running = true
    }

    Process {
        id: vpnProc
        onExited: {
            if (!extraMetricsProc.running) extraMetricsProc.running = true
        }
    }

    // Funciones de Control Nativo de Carga de Batería (60% -> 80% -> 100%)
    function cycleBatteryChargeLimit() {
        var nextLim = 80
        if (batteryChargeLimit === 60) nextLim = 80
        else if (batteryChargeLimit === 80) nextLim = 100
        else nextLim = 60
        applyBatteryChargeLimit(nextLim)
    }

    function applyBatteryChargeLimit(nextLim) {
        batteryChargeLimit = nextLim
        showRingToast("🔋 Battery Charge Limit: " + nextLim + "%")
        saveState()
        batLimitProc.command = ["bash", "-c", "asusctl -c " + nextLim + " 2>/dev/null || echo " + nextLim + " | tee /sys/class/power_supply/BAT*/charge_control_end_threshold >/dev/null 2>&1 || true"]
        batLimitProc.running = true
    }

    Process { id: batLimitProc }

    // Funciones de Clipboard Smart Actions + Modo Incógnito
    function toggleClipboardIncognito() {
        clipboardIncognito = !clipboardIncognito
        showRingToast(clipboardIncognito ? "🕵 Incognito ON (Clipboard Paused)" : "📋 Incognito OFF (Clipboard Active)")
        saveState()
    }

    function detectClipAction(txt) {
        if (!txt) return ""
        var s = txt.trim()
        // Detectar IPv4 o dominio para acción Ping
        if (/^(?:\d{1,3}\.){3}\d{1,3}$/.test(s) || (/^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(s) && s.indexOf(" ") === -1)) {
            return "PING"
        }
        // Detectar Hash MD5 / SHA1 / SHA256
        if (/^[a-fA-F0-9]{32}$/.test(s) || /^[a-fA-F0-9]{40}$/.test(s) || /^[a-fA-F0-9]{64}$/.test(s)) {
            return "HASH"
        }
        // Detectar cadena Base64
        if (s.length >= 12 && s.length % 4 === 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(s) && (s.indexOf("=") !== -1 || /[0-9]/.test(s))) {
            return "B64"
        }
        return ""
    }

    function runSmartClipAction(txt) {
        var kind = detectClipAction(txt)
        var clean = txt.trim()
        if (kind === "PING") {
            showRingToast("📡 Pinging " + clean + "...")
            smartActionProc.command = ["bash", "-c", "res=$(ping -c 1 -W 1 '" + clean.replace(/'/g, "") + "' 2>/dev/null | grep 'time=' | sed -E 's/.*time=([0-9.]+ ms).*/\\1/'); if [ -n \"$res\" ]; then echo \"⚡ " + clean + " → $res\"; else echo \"❌ Host unreachable: " + clean + "\"; fi"]
            smartActionProc.running = true
        } else if (kind === "B64") {
            smartActionProc.command = ["bash", "-c", "dec=$(echo -n '" + clean.replace(/'/g, "") + "' | base64 -d 2>/dev/null | tr -d '\\0'); if [ -n \"$dec\" ]; then printf '%s' \"$dec\" | wl-copy; echo \"🔓 Decoded & Copied: ${dec:0:28}\"; else echo \"⚠️ Invalid Base64\"; fi"]
            smartActionProc.running = true
        } else if (kind === "HASH") {
            var hType = clean.length === 32 ? "MD5" : (clean.length === 40 ? "SHA-1" : "SHA-256")
            copyTextToClipboard(clean)
            showRingToast("🔐 " + hType + " Hash copied!")
        }
    }

    Process {
        id: smartActionProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.trim() !== "") root.showRingToast(line.trim())
            }
        }
    }

    function showRingToast(msg) {
        ringToastText = msg
        ringToastVisible = true
        rToastT.restart()
    }

    function cycleRingMode() {
        if (ringMode === "battery") ringMode = "cpu"
        else if (ringMode === "cpu") ringMode = "ram"
        else if (ringMode === "ram") ringMode = "todo"
        else ringMode = "battery"
        var L = {
            "battery": "🔋 Ring: Battery Level",
            "cpu": "🔥 Ring: CPU Thermal",
            "ram": "💾 Ring: RAM Usage",
            "todo": "✅ Ring: Daily Tasks"
        }
        showRingToast(L[ringMode])
        saveState()
    }

    function triggerMascotMood(m, d) {
        mascotTemporaryMood = m
        moodResetTimer.interval = d || 4000
        moodResetTimer.restart()
    }

    function saveState() {
        var d = {
            minimalMode: minimalMode,
            mascotInClosed: mascotInClosed,
            ringMode: ringMode,
            batteryChargeLimit: batteryChargeLimit,
            clipboardIncognito: clipboardIncognito,
            shelf: shelfFiles,
            clipboard: clipboardHistory,
            todos: todoList
        }
        saveProc.command = ["bash", "-c", "cat > '" + stateFilePath + "' << 'JSON_EOF'\n" + JSON.stringify(d) + "\nJSON_EOF"]
        saveProc.running = true
    }

    function saveAgendaFile() {
        var out = ""
        for (var j = 0; j < agendaEvents.length; j++) {
            out += agendaEvents[j].time + " | " + agendaEvents[j].title + "\n"
        }
        agendaSaveProc.command = ["bash", "-c", "cat > '" + agendaFilePath + "' << 'AG_EOF'\n" + out + "AG_EOF"]
        agendaSaveProc.running = true
    }

    function loadState() {
        loadProc.running = true
        loadAgenda()
    }

    function loadAgenda() {
        agendaProc.running = true
    }

    Process { id: saveProc }
    Process { id: agendaSaveProc }

    Process {
        id: loadProc
        command: ["cat", stateFilePath]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var o = JSON.parse(data)
                    if (o.minimalMode !== undefined) minimalMode = o.minimalMode
                    if (o.ringMode) ringMode = o.ringMode
                    if (o.batteryChargeLimit) batteryChargeLimit = o.batteryChargeLimit
                    if (o.clipboardIncognito !== undefined) clipboardIncognito = o.clipboardIncognito
                    if (o.shelf) shelfFiles = o.shelf
                    if (o.clipboard) clipboardHistory = o.clipboard
                    if (o.todos && o.todos.length > 0) todoList = o.todos
                } catch(e) {}
            }
        }
    }

    Process {
        id: agendaProc
        command: ["cat", agendaFilePath]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var l = data.split("\n")
                var evs = []
                for (var i = 0; i < l.length; i++) {
                    var t = l[i].trim()
                    if (t === "" || t.startsWith("#")) continue
                    var p = t.split("|")
                    if (p.length >= 2) evs.push({ time: p[0].trim(), title: p.slice(1).join("|").trim(), notified: false })
                    else evs.push({ time: "Today", title: t, notified: false })
                }
                agendaEvents = evs
            }
        }
    }

    function normalizeTimeStr(raw, fallbackNow) {
        var s = (raw || "").trim()
        if (s === "") {
            return fallbackNow ? Qt.formatTime(new Date(), "HH:mm") : ""
        }
        var m = /^(\d{1,2}):(\d{2})$/.exec(s)
        if (m) {
            var hh = Math.min(23, Math.max(0, parseInt(m[1], 10)))
            var mm = Math.min(59, Math.max(0, parseInt(m[2], 10)))
            return String(hh).padStart(2, '0') + ":" + String(mm).padStart(2, '0')
        }
        return s
    }

    function submitTodoOrEvent(titleText, timeText) {
        var cleanTitle = (titleText || "").trim()
        if (cleanTitle === "") return

        if (todoShowAgenda) {
            var tm = normalizeTimeStr(timeText, true)
            var evs = agendaEvents.slice()
            if (todoEditingIndex >= 0 && todoEditingIndex < evs.length) {
                evs[todoEditingIndex] = { time: tm, title: cleanTitle, notified: false }
                showRingToast("📅 Event updated!")
            } else {
                evs.push({ time: tm, title: cleanTitle, notified: false })
                showRingToast("📅 Event scheduled for " + tm)
            }
            agendaEvents = evs
            saveAgendaFile()
        } else {
            var tTime = normalizeTimeStr(timeText, false)
            var cp = todoList.slice()
            if (todoEditingIndex >= 0 && todoEditingIndex < cp.length) {
                var prev = cp[todoEditingIndex]
                cp[todoEditingIndex] = { id: prev.id || Date.now(), text: cleanTitle, time: tTime, done: prev.done, notified: false }
                showRingToast("✓ Task updated!")
            } else {
                cp.unshift({ id: Date.now(), text: cleanTitle, time: tTime, done: false, notified: false })
                showRingToast("✓ Task added!")
            }
            todoList = cp
            saveState()
        }

        cancelTodoInput()
    }

    function cancelTodoInput() {
        todoAddingMode = false
        todoEditingIndex = -1
    }

    function removeAgendaEvent(i) {
        var evs = agendaEvents.slice()
        evs.splice(i, 1)
        agendaEvents = evs
        if (todoEditingIndex === i) cancelTodoInput()
        saveAgendaFile()
    }

    function toggleTodo(i) {
        var cp = todoList.slice()
        if (cp[i]) {
            cp[i].done = !cp[i].done
            if (cp[i].done) triggerMascotMood("happy", 4000)
            todoList = cp
            saveState()
        }
    }

    function removeTodo(i) {
        var cp = todoList.slice()
        cp.splice(i, 1)
        todoList = cp
        if (todoEditingIndex === i) cancelTodoInput()
        saveState()
    }

    Process { id: notifyProc }

    function triggerReminderAlert(kindLabel, titleStr, timeStr) {
        playChime()
        triggerMascotMood("surprised", 8000)
        enterAlertPopup("reminder", kindLabel + " (" + timeStr + ")", titleStr, 1.0, "⏰")
        var safeTitle = titleStr.replace(/'/g, "'\\''")
        var safeKind = kindLabel.replace(/'/g, "'\\''")
        notifyProc.command = ["bash", "-c", "notify-send -u critical '⏰ Vortex " + safeKind + " ('" + timeStr + "')' '" + safeTitle + "' 2>/dev/null || true"]
        notifyProc.running = true
    }

    function checkTodoReminders() {
        var nowHm = Qt.formatTime(new Date(), "HH:mm")
        var changedTodos = false
        var cp = todoList.slice()
        for (var i = 0; i < cp.length; i++) {
            if (!cp[i].done && !cp[i].notified && cp[i].time && cp[i].time === nowHm) {
                cp[i].notified = true
                changedTodos = true
                triggerReminderAlert("Task Reminder", cp[i].text, cp[i].time)
            }
        }
        if (changedTodos) {
            todoList = cp
            saveState()
        }

        var changedAgenda = false
        var evs = agendaEvents.slice()
        for (var j = 0; j < evs.length; j++) {
            if (!evs[j].notified && evs[j].time && evs[j].time === nowHm) {
                evs[j].notified = true
                changedAgenda = true
                triggerReminderAlert("Agenda Event", evs[j].title, evs[j].time)
            }
        }
        if (changedAgenda) {
            agendaEvents = evs
        }
    }

    function setRogProfile(p) {
        rogProfile = p
        var pctl = (p.toLowerCase() === "silent" || p.toLowerCase() === "quiet") ? "power-saver" : (p.toLowerCase() === "performance" ? "performance" : "balanced")
        cmdProc.command = ["bash", "-c", "asusctl profile -P " + p + " 2>/dev/null || powerprofilesctl set " + pctl + " 2>/dev/null"]
        cmdProc.running = true
    }

    function setBrightness(p) {
        brightnessPct = Math.max(5, Math.min(100, Math.round(p)))
        if (!brightnessProc.running) {
            brightnessProc.command = ["brightnessctl", "s", brightnessPct + "%", "-q"]
            brightnessProc.running = true
        } else {
            pendingBrightness = brightnessPct
        }
    }

    Process {
        id: brightnessProc
        onExited: {
            if (root.pendingBrightness >= 0 && root.pendingBrightness !== root.brightnessPct) {
                var nextB = root.pendingBrightness
                root.pendingBrightness = -1
                brightnessProc.command = ["brightnessctl", "s", nextB + "%", "-q"]
                brightnessProc.running = true
            } else {
                root.pendingBrightness = -1
            }
        }
    }

    function pushClipboardItem(txt) {
        if (clipboardIncognito) return
        if (!txt || txt.trim() === "") return
        var c = txt.trim()
        var cp = clipboardHistory.slice()
        for (var i = 0; i < cp.length; i++) {
            if (cp[i].text === c) {
                cp.splice(i, 1)
                break
            }
        }
        cp.unshift({ text: c, time: Qt.formatTime(new Date(), "HH:mm") })
        if (cp.length > 10) cp = cp.slice(0, 10)
        clipboardHistory = cp
        saveState()
    }

    function copyTextToClipboard(txt) {
        cmdProc.command = ["wl-copy", txt]
        cmdProc.running = true
        showRingToast("📋 Copied to clipboard!")
    }

    function clearClipboardHistory() {
        clipboardHistory = []
        saveState()
    }

    Process { id: cmdProc }

    Process {
        id: artProc
        onExited: (c) => {
            if (c === 0) root.localArtUrl = "file://" + Quickshell.env("HOME") + "/.cache/vortex-linux/art.jpg?t=" + Date.now()
        }
    }

    function updateArtUrl(r) {
        if (!r) { lastRawArtUrl = ""; localArtUrl = ""; return }
        if (r === lastRawArtUrl) return
        lastRawArtUrl = r
        if (r.startsWith("file://")) localArtUrl = r
        else if (r.startsWith("http")) {
            artProc.running = false
            artProc.command = ["curl", "-sL", "--max-time", "5", r, "-o", Quickshell.env("HOME") + "/.cache/vortex-linux/art.jpg"]
            artProc.running = true
        } else localArtUrl = ""
    }

    Process {
        id: lyricsProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { lyricsLoading = false; parseLrc(data) }
        }
        onExited: lyricsLoading = false
    }

    function fetchLyrics(t, a) {
        var k = a + " - " + t
        if (k === currentTrackKey) return
        currentTrackKey = k
        lyricsList = []
        currentLyricIndex = -1
        currentLyricLine = ""
        if (!t) return
        lyricsLoading = true
        lyricsProc.running = false
        lyricsProc.command = [Quickshell.env("HOME") + "/.config/quickshell/vortex/scripts/fetch_lyrics.sh", t, a]
        lyricsProc.running = true
    }

    function parseLrc(raw) {
        if (!raw || raw.trim() === "") { lyricsList = []; return }
        var lines = raw.split("\n")
        var p = []
        var re = /\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/
        for (var i = 0; i < lines.length; i++) {
            var m = re.exec(lines[i])
            if (m) {
                var ms = parseInt(m[3], 10)
                var sec = parseInt(m[1], 10) * 60 + parseInt(m[2], 10) + (m[3].length === 3 ? ms / 1000 : ms / 100)
                var txt = m[4].trim()
                if (txt !== "") p.push({ time: sec, text: txt })
            }
        }
        lyricsList = p
    }

    function updateLyricPosition(pos) {
        if (lyricsList.length === 0) { currentLyricIndex = -1; currentLyricLine = ""; return }
        var idx = -1
        for (var i = 0; i < lyricsList.length; i++) {
            if (pos >= lyricsList[i].time) idx = i
            else break
        }
        if (idx !== currentLyricIndex) {
            currentLyricIndex = idx
            currentLyricLine = idx >= 0 ? lyricsList[idx].text : "♪ · · ·"
        }
    }

    Process {
        id: pasteFileProc
        command: ["wl-paste"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var txt = data.trim()
                if (!txt) { root.showRingToast("⚠️ Clipboard is empty!"); return }
                var lines = txt.split("\n")
                var urls = []
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim()
                    if (l.startsWith("file://")) urls.push(l)
                    else if (l.startsWith("/")) urls.push("file://" + l)
                }
                if (urls.length > 0) {
                    root.addShelfUrls(urls)
                    root.showRingToast("📁 File added to Shelf!")
                } else root.showRingToast("⚠️ No file path found")
            }
        }
    }

    function pasteFileToShelf() {
        pasteFileProc.running = false
        pasteFileProc.running = true
    }

    Process {
        id: statProc
        property string pPath: ""
        property string pUri: ""
        property string pName: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var i = data.trim().split("|")
                var cp = shelfFiles.slice()
                cp.push({ name: statProc.pName, path: statProc.pPath, uri: statProc.pUri, isDir: i[0] === "directory", sizeStr: i[0] === "directory" ? "Folder" : (i[1] || "File") })
                shelfFiles = cp
                saveState()
            }
        }
    }

    function addShelfUrls(urls) {
        if (!urls || urls.length === 0) return
        shelfShowClipboard = false
        for (var i = 0; i < urls.length; i++) {
            var u = String(urls[i]).trim()
            var p = decodeURIComponent(u.replace(/^file:\/\//, "")).replace(/\/$/, "").trim()
            var parts = p.split("/")
            var name = parts[parts.length - 1] || p
            var ex = false
            for (var j = 0; j < shelfFiles.length; j++) {
                if (shelfFiles[j].path === p) { ex = true; break }
            }
            if (!ex) {
                statProc.pPath = p
                statProc.pUri = u
                statProc.pName = name
                var sp = p.replace(/'/g, "'\\''")
                statProc.command = ["bash", "-c", "if [ -d '" + sp + "' ]; then echo 'directory|Folder'; else sz=$(du -sh '" + sp + "' 2>/dev/null | cut -f1); echo \"file|${sz}B\"; fi"]
                statProc.running = true
            }
        }
    }

    function removeShelfFile(i) {
        var cp = shelfFiles.slice()
        cp.splice(i, 1)
        shelfFiles = cp
        saveState()
    }

    function clearShelf() {
        if (shelfShowClipboard) clearClipboardHistory()
        else { shelfFiles = []; saveState() }
    }

    Process { id: openProc }
    function openFile(p) {
        openProc.command = ["xdg-open", p]
        openProc.running = true
    }
    function copyFileUriToClipboard(u, p) {
        openProc.command = ["bash", "-c", "wl-copy --type text/uri-list '" + u + "\r\n' 2>/dev/null || wl-copy '" + p + "'"]
        openProc.running = true
        showRingToast("📋 Copied!")
    }

    Process {
        id: weatherProc
        command: ["python3", "-c", "
import urllib.request, json, datetime
url = 'https://api.open-meteo.com/v1/forecast?latitude=18.4861&longitude=-69.9312&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=America%2FSanto_Domingo'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=5) as r:
    d = json.loads(r.read().decode())
c = d['current']
dl = d['daily']
def w_info(code):
    if code in [95, 96, 99]: return ('Thunderstorm', '⛈️')
    if code in [51, 53, 55, 61, 63, 65, 80, 81, 82]: return ('Drizzle' if code < 60 else 'Rain', '🌧️')
    if code in [1, 2, 3, 45, 48]: return ('Cloudy', '☁️')
    return ('Clear', '☀️')
cond, ic = w_info(c['weather_code'])
sr = dl['sunrise'][0].split('T')[1] if dl['sunrise'] else '06:37'
ss = dl['sunset'][0].split('T')[1] if dl['sunset'] else '18:09'
days_es = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom']
months_es = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
fc = []
for i in range(min(7, len(dl['time']))):
    dt = datetime.date.fromisoformat(dl['time'][i])
    dname = 'Today' if i == 0 else days_es[dt.weekday()]
    dstr = f'{months_es[dt.month-1]} {dt.day}'
    _, dic = w_info(dl['weather_code'][i])
    fc.append({'day': dname, 'date': dstr, 'icon': dic, 'min': f\"{round(dl['temperature_2m_min'][i])}°\", 'max': f\"{round(dl['temperature_2m_max'][i])}°\"})
out = {
    'temp': f\"{round(c['temperature_2m'])}°C\",
    'cond': cond,
    'icon': ic,
    'feels': f\"{round(c['apparent_temperature'])}°C\",
    'hum': f\"{round(c['relative_humidity_2m'])}%\",
    'wind': f\"{round(c['wind_speed_10m'])} km/h\",
    'sunrise': sr,
    'sunset': ss,
    'forecast': fc
}
print(json.dumps(out))
"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var o = JSON.parse(data.trim())
                    root.weatherTemp = o.temp
                    root.weatherCondition = o.cond
                    root.weatherIcon = o.icon
                    root.weatherFeelsLike = o.feels
                    root.weatherHumidity = o.hum
                    root.weatherWind = o.wind
                    root.weatherSunrise = o.sunrise
                    root.weatherSunset = o.sunset
                    if (o.forecast && o.forecast.length > 0) root.forecastDays = o.forecast
                } catch(e) {}
            }
        }
    }

    Timer {
        id: weatherRefreshTimer
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Process {
        id: chimeProc
        command: ["pw-play", "/usr/share/sounds/freedesktop/stereo/complete.oga"]
    }

    function playChime() {
        chimeProc.running = false
        chimeProc.running = true
    }

    function peekMedia() {
        activeTab = 1
        mediaPeekSeq++
    }

    function toggleMinimalMode() {
        minimalMode = !minimalMode
        saveState()
    }

    function enterAlertPopup(type, title, detail, val, icon) {
        currentAlertType = type || "info"
        currentAlertTitle = title || type
        currentAlertDetail = detail || ""
        currentAlertValue = val !== undefined ? val : -1
        currentAlertIcon = icon || "⚡"
        alertSeq++
    }

    function onFullscreenChanged(fs) {
        isFullscreen = fs
    }

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "00:00"
        var m = Math.floor(sec / 60)
        var s = Math.floor(sec % 60)
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    Process {
        id: omacleSyncProc
        command: ["python3", "-c", "
import os, json, glob, re

scale = 1.25
rounding = 0.95
paths = (
    glob.glob(os.path.expanduser('~/.config/omacle/**/*.*'), recursive=True) +
    glob.glob(os.path.expanduser('~/.config/caelestia/**/*.*'), recursive=True) +
    glob.glob(os.path.expanduser('~/.local/share/omacle/**/*.*'), recursive=True) +
    glob.glob(os.path.expanduser('~/.local/state/**/*omacle*/*.*'), recursive=True) +
    glob.glob(os.path.expanduser('~/.config/quickshell/**/*config*.json'), recursive=True) +
    glob.glob(os.path.expanduser('~/.config/quickshell/**/*settings*.json'), recursive=True) +
    glob.glob(os.path.expanduser('~/.config/hypr/*.lua'))
)

best_mtime = 0
for p in paths:
    if 'nusa' in p or 'vortex' in p or not os.path.isfile(p):
        continue
    try:
        mtime = os.path.getmtime(p)
        with open(p, 'r', errors='ignore') as f:
            txt = f.read()
        if p.endswith('.json'):
            data = json.loads(txt)
            def find_keys(d):
                global scale, rounding, best_mtime
                if isinstance(d, dict):
                    for k, v in d.items():
                        kl = k.lower()
                        if kl in ['size', 'interfacescale', 'scale', 'uiscale'] and isinstance(v, (int, float)):
                            val = v / 100.0 if v > 10 else float(v)
                            if 0.5 <= val <= 3.0 and mtime >= best_mtime:
                                scale = val
                                best_mtime = mtime
                        elif kl == 'rounding' and isinstance(v, (int, float)):
                            val = v / 100.0 if v > 10 else float(v)
                            if 0.1 <= val <= 2.0:
                                rounding = val
                        else:
                            find_keys(v)
                elif isinstance(d, list):
                    for item in d:
                        find_keys(item)
            find_keys(data)
        else:
            m = re.search(r'(?:interface_?scale|ui_?scale|size)\\s*[:=]\\s*([0-9.]+)', txt, re.I)
            if m and mtime >= best_mtime:
                val = float(m.group(1))
                val = val / 100.0 if val > 10 else val
                if 0.5 <= val <= 3.0:
                    scale = val
                    best_mtime = mtime
    except Exception:
        pass

print(f'{scale:.3f}|{rounding:.3f}')
"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var p = line.trim().split("|")
                if (p.length >= 2) {
                    var s = parseFloat(p[0])
                    var r = parseFloat(p[1])
                    if (!isNaN(s) && s >= 0.5 && s <= 3.0 && Math.abs(root.omacleScale - s) > 0.01) {
                        root.omacleScale = s
                    }
                    if (!isNaN(r) && r >= 0.1 && r <= 2.0 && Math.abs(root.omacleRounding - r) > 0.01) {
                        root.omacleRounding = r
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!omacleSyncProc.running) omacleSyncProc.running = true
    }

    Component.onCompleted: loadState()
}
