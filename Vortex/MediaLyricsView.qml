import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import Vortex

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================
    property var activePlayer: null
    property bool showLyrics: false
    property bool splitLyricsMode: false
    property var lyricsLines: [] // [{time: float, text: string}]
    property int currentLineIndex: -1
    property string currentTrackHash: ""
    property bool lyricsLoading: false
    property string lyricsError: ""

    // Cached lyrics path
    property string lyricsCacheDir: Quickshell.env("HOME") + "/.cache/vortex-linux/lyrics/"

    // =========================================================================
    // Timer for position updates (only when playing)
    // =========================================================================
    Timer {
        id: positionUpdateTimer
        interval: 500
        running: root.activePlayer && root.activePlayer.playbackState === 1 && (StateStore.notchState === "EXPANDED" || StateStore.splitLyricsEnabled)
        repeat: true
        onTriggered: {
            if (root.activePlayer) {
                updateCurrentLine()
            }
        }
    }

    // =========================================================================
    // MPRIS Player Selection
    // =========================================================================
    function selectActivePlayer() {
        var players = Mpris.players.values
        if (!players || players.length === 0) {
            root.activePlayer = null
            return
        }
        // Priority: playing > paused > first
        // MPRIS playbackState enum: 0=Stopped, 1=Playing, 2=Paused
        var playing = null
        var paused = null
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (p.playbackState === 1) { // Playing
                playing = p
                break
            } else if (p.playbackState === 2 && !paused) { // Paused
                paused = p
            }
        }
        root.activePlayer = playing || paused || players[0]
    }

    // Initial selection and react to player changes
    Component.onCompleted: {
        selectActivePlayer()
        // Ensure cache directory exists
        var proc = Qt.createComponent("Process")
        if (proc.status === Component.Ready) {
            var obj = proc.createObject(root, { command: ["mkdir", "-p", lyricsCacheDir] })
            obj.running = true
        }
    }

    Timer {
        id: mprisPollTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            selectActivePlayer()
        }
    }

    Connections {
        target: root
        function onActivePlayerChanged() {
            if (root.activePlayer) {
                loadLyricsForCurrentTrack()
            } else {
                root.lyricsLines = []
                root.currentLineIndex = -1
            }
        }
    }

    // =========================================================================
    // Lyrics Loading (LRCLIB)
    // =========================================================================
    function loadLyricsForCurrentTrack() {
        if (!root.activePlayer) return

        var title = root.activePlayer.trackTitle || ""
        var artist = root.activePlayer.trackArtist || ""
        var duration = root.activePlayer.length || 0 // in seconds

        if (!title || !artist) {
            root.lyricsLines = []
            root.currentLineIndex = -1
            return
        }

        // Generate cache key
        var cacheKey = title.toLowerCase().replace(/[^a-z0-9]/g, "_") + "_" + artist.toLowerCase().replace(/[^a-z0-9]/g, "_")
        var cacheFile = lyricsCacheDir + cacheKey + ".lrc"
        root.currentTrackHash = cacheKey

        // Try cache first
        var proc = Qt.createComponent("Process")
        if (proc.status === Component.Ready) {
            var obj = proc.createObject(root, { command: ["cat", cacheFile] })
            obj.onFinished = function(exitCode) {
                if (exitCode === 0) {
                    var content = obj.readAllStandardOutput()
                    root.parseLyrics(content)
                } else {
                    // Not in cache, fetch from LRCLIB
                    fetchLyricsFromLRCLIB(title, artist, duration, cacheFile)
                }
            }
            obj.running = true
        }
    }

    function fetchLyricsFromLRCLIB(title, artist, duration, cacheFile) {
        root.lyricsLoading = true
        root.lyricsError = ""

        var encodedTitle = encodeURIComponent(title)
        var encodedArtist = encodeURIComponent(artist)
        var url = "https://lrclib.net/api/get?track_name=" + encodedTitle + "&artist_name=" + encodedArtist + "&duration=" + Math.round(duration)

        var proc = Qt.createComponent("Process")
        if (proc.status === Component.Ready) {
            var obj = proc.createObject(root, { command: ["curl", "-s", "-f", "--max-time", "10", url] })
            obj.onFinished = function(exitCode) {
                root.lyricsLoading = false
                if (exitCode === 0) {
                    var response = obj.readAllStandardOutput()
                    try {
                        var data = JSON.parse(response)
                        if (data.syncedLyrics) {
                            // Save to cache
                            var saveProc = Qt.createComponent("Process")
                            if (saveProc.status === Component.Ready) {
                                var saveObj = saveProc.createObject(root, { command: ["tee", cacheFile] })
                                saveObj.write(data.syncedLyrics)
                                saveObj.close()
                            }
                            root.parseLyrics(data.syncedLyrics)
                        } else {
                            // Try search fallback
                            searchLyricsFallback(title, artist, cacheFile)
                        }
                    } catch (e) {
                        root.lyricsError = "Parse error"
                    }
                } else {
                    searchLyricsFallback(title, artist, cacheFile)
                }
            }
            obj.running = true
        }
    }

    function searchLyricsFallback(title, artist, cacheFile) {
        var query = encodeURIComponent(title + " " + artist)
        var url = "https://lrclib.net/api/search?q=" + query

        var proc = Qt.createComponent("Process")
        if (proc.status === Component.Ready) {
            var obj = proc.createObject(root, { command: ["curl", "-s", "-f", "--max-time", "10", url] })
            obj.onFinished = function(exitCode) {
                if (exitCode === 0) {
                    var response = obj.readAllStandardOutput()
                    try {
                        var results = JSON.parse(response)
                        if (results && results.length > 0) {
                            for (var i = 0; i < results.length; i++) {
                                if (results[i].syncedLyrics) {
                                    var saveProc = Qt.createComponent("Process")
                                    if (saveProc.status === Component.Ready) {
                                        var saveObj = saveProc.createObject(root, { command: ["tee", cacheFile] })
                                        saveObj.write(results[i].syncedLyrics)
                                        saveObj.close()
                                    }
                                    root.parseLyrics(results[i].syncedLyrics)
                                    return
                                }
                            }
                        }
                        root.lyricsError = "No synced lyrics found"
                    } catch (e) {
                        root.lyricsError = "Search parse error"
                    }
                } else {
                    root.lyricsError = "Search failed"
                }
            }
            obj.running = true
        }
    }

    function parseLyrics(lrcText) {
        var lines = lrcText.split("\n")
        var parsed = []
        var timeRegex = /\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)/

        for (var i = 0; i < lines.length; i++) {
            var match = lines[i].match(timeRegex)
            if (match) {
                var minutes = parseInt(match[1])
                var seconds = parseInt(match[2])
                var centis = parseInt(match[3].padEnd(3, '0').slice(0, 3)) // normalize to milliseconds
                var text = match[4].trim()
                var totalSeconds = minutes * 60 + seconds + centis / 1000
                if (text) {
                    parsed.push({ time: totalSeconds, text: text })
                }
            }
        }
        // Sort by time
        parsed.sort(function(a, b) { return a.time - b.time })
        root.lyricsLines = parsed
        root.currentLineIndex = -1
    }

    function updateCurrentLine() {
        if (!root.activePlayer || root.lyricsLines.length === 0) return
        var pos = root.activePlayer.position // in seconds
        var newIndex = -1
        for (var i = 0; i < root.lyricsLines.length; i++) {
            if (root.lyricsLines[i].time <= pos) {
                newIndex = i
            } else {
                break
            }
        }
        if (newIndex !== root.currentLineIndex) {
            root.currentLineIndex = newIndex
            // Auto-scroll in ListView handled by highlightFollowsCurrentItem
        }
    }

    function formatTime(seconds) {
        if (seconds < 0) seconds = 0
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2)
    }

    function formatRemaining(seconds) {
        if (!root.activePlayer) return "--:--"
        var rem = root.activePlayer.length - seconds
        if (rem < 0) rem = 0
        return "-" + formatTime(rem)
    }

    function onSeekPressed(x) {
        if (!root.activePlayer || !root.activePlayer.canSeek) return
        var progress = x / seekBar.width
        var newPos = progress * root.activePlayer.length
        root.activePlayer.position = newPos
    }

    // =========================================================================
    // UI
    // =========================================================================
    anchors.fill: parent

    // Main content - shows either controls or lyrics view
    Loader {
        id: viewLoader
        anchors.fill: parent
        sourceComponent: root.showLyrics ? lyricsView : controlsView
    }

    // =========================================================================
    // Controls View (default expanded view)
    // =========================================================================
    Component {
        id: controlsView
        Item {
            anchors.fill: parent
            Column {
                anchors.fill: parent
                spacing: 12

                // Track info + artwork
                Row {
                    spacing: 16
                    // Artwork
                    Rectangle {
                        id: artworkBg
                        width: 80
                        height: 80
                        radius: 8
                        color: "#313244"
                        Image {
                            id: artworkImg
                            anchors.fill: parent
                            source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            // Fallback
                            Rectangle {
                                anchors.centerIn: parent
                                visible: !artworkImg.source || artworkImg.status === Image.Error
                                width: 40
                                height: 40
                                radius: 20
                                color: "#89b4fa"
                                opacity: 0.3
                            }
                        }
                    }
                    // Track metadata
                    Column {
                        spacing: 4
                        Text {
                            id: trackTitleText
                            text: root.activePlayer ? root.activePlayer.trackTitle : "No track"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: "#cdd6f4"
                            elide: Text.ElideRight
                            width: 300
                        }
                        Text {
                            text: root.activePlayer ? root.activePlayer.trackArtist : "No player"
                            font.pixelSize: 13
                            color: "#a6adc8"
                        }
                        // Playback status indicator
                        Text {
                            text: root.activePlayer ? (root.activePlayer.playbackState === 1 ? "▶ Playing" : root.activePlayer.playbackState === 2 ? "⏸ Paused" : "⏹ Stopped") : "No player"
                            font.pixelSize: 11
                            color: root.activePlayer && root.activePlayer.playbackState === 1 ? "#a6e3a1" : "#f9e2af"
                        }
                    }
                }

                // Progress bar
                Column {
                    spacing: 4
                    Row {
                        spacing: 8
                        Text {
                            id: currentTimeText
                            text: formatTime(root.activePlayer ? root.activePlayer.position : 0)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: "#6c7086"
                        }
                        Rectangle {
                            id: seekBar
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: "#313244"
                            Rectangle {
                                id: seekProgress
                                height: 6
                                width: root.activePlayer && root.activePlayer.length > 0 ? (root.activePlayer.position / root.activePlayer.length) * seekBar.width : 0
                                radius: 3
                                color: "#89b4fa"
                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onPressed: onSeekPressed(mouseX)
                                onPositionChanged: onSeekPressed(mouseX)
                            }
                        }
                        Text {
                            id: remainingTimeText
                            text: formatRemaining(root.activePlayer ? root.activePlayer.position : 0)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: "#6c7086"
                        }
                    }
                }

                // Controls row
                Row {
                    spacing: 20
                    // Previous
                    Button {
                        id: prevBtn
                        contentItem: Text { text: "⏮"; font.pixelSize: 20 }
                        enabled: root.activePlayer && root.activePlayer.canGoPrevious
                        onClicked: root.activePlayer && root.activePlayer.previous()
                    }
                    // Play/Pause
                    Button {
                        id: playPauseBtn
                        contentItem: Text {
                            text: root.activePlayer && root.activePlayer.playbackState === 1 ? "⏸" : "▶"
                            font.pixelSize: 24
                        }
                        enabled: root.activePlayer && (root.activePlayer.canPlay || root.activePlayer.canPause)
                        onClicked: root.activePlayer && root.activePlayer.togglePlaying()
                    }
                    // Next
                    Button {
                        id: nextBtn
                        contentItem: Text { text: "⏭"; font.pixelSize: 20 }
                        enabled: root.activePlayer && root.activePlayer.canGoNext
                        onClicked: root.activePlayer && root.activePlayer.next()
                    }
                    // Lyrics toggle
                    Button {
                        id: lyricsToggleBtn
                        contentItem: Text { text: "📝"; font.pixelSize: 18 }
                        checkable: true
                        checked: root.showLyrics
                        onClicked: root.showLyrics = !root.showLyrics
                    }
                    // Split lyrics toggle
                    Button {
                        id: splitLyricsBtn
                        contentItem: Text { text: "⧉"; font.pixelSize: 18 }
                        checkable: true
                        checked: StateStore.splitLyricsEnabled
                        onClicked: StateStore.splitLyricsEnabled = !StateStore.splitLyricsEnabled
                    }
                }
            }
        }
    }

    // =========================================================================
    // Lyrics View (full-screen lyrics in expanded notch)
    // =========================================================================
    Component {
        id: lyricsView
        Item {
            anchors.fill: parent
            Column {
                anchors.fill: parent
                spacing: 8

                // Compact header with track info and back button
                Row {
                    spacing: 12
                    Button {
                        contentItem: Text { text: "←"; font.pixelSize: 18 }
                        onClicked: root.showLyrics = false
                    }
                    Rectangle {
                        width: 48
                        height: 48
                        radius: 6
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    Column {
                        Text {
                            text: root.activePlayer ? root.activePlayer.trackTitle : "No track"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: "#cdd6f4"
                            elide: Text.ElideRight
                            width: 300
                        }
                        Text {
                            text: root.activePlayer ? root.activePlayer.trackArtist : "No player"
                            font.pixelSize: 11
                            color: "#a6adc8"
                        }
                    }
                    Item { Layout.fillWidth: true } // spacer
                    Button {
                        contentItem: Text { text: "⧉"; font.pixelSize: 16 }
                        checkable: true
                        checked: StateStore.splitLyricsEnabled
                        onClicked: StateStore.splitLyricsEnabled = !StateStore.splitLyricsEnabled
                    }
                }

                // Lyrics list
                ListView {
                    id: lyricsList
                    anchors.fill: parent
                    model: root.lyricsLines
                    clip: true
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 300
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: height / 2 - 24
                    preferredHighlightEnd: height / 2 + 24

                    delegate: Item {
                        width: ListView.view.width
                        height: 40
                        Text {
                            id: lyricText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            text: modelData.text
                            font.pixelSize: root.currentLineIndex === index ? 16 : 14
                            font.weight: root.currentLineIndex === index ? Font.Bold : Font.Normal
                            color: root.currentLineIndex === index ? "#cdd6f4" : "#6c7086"
                            opacity: root.currentLineIndex === index ? 1.0 : 0.45
                            elide: Text.ElideRight
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on font.pixelSize { NumberAnimation { duration: 200 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canSeek) {
                                    root.activePlayer.position = modelData.time
                                    root.currentLineIndex = index
                                }
                            }
                        }
                    }

                    // Empty state
                    footer: Item {
                        height: 100
                        Text {
                            anchors.centerIn: parent
                            text: root.lyricsLoading ? "Loading lyrics..." :
                                  root.lyricsError ? root.lyricsError :
                                  "No synced lyrics available for this track"
                            color: "#6c7086"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width - 32
                        }
                    }
                }
            }
        }
    }
}