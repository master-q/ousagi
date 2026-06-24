import QtQuick

Window {
    id: root
    visible: true
    width: 1024
    height: 768
    title: "Pusagi (QML)"
    color: "black"

    // ── State ─────────────────────────────────────────────
    property int    currentPage:        0
    property double elapsedSec:         0.0
    property bool   presRunning:        false
    property var    lastTickMs:         0
    property real   displayedTimerProg: 0.0
    property real   displayedPageProg:  0.0

    function toggleTimer() {
        if (presRunning) {
            elapsedSec += (Date.now() - lastTickMs) / 1000.0
            presRunning = false
        } else {
            lastTickMs = Date.now()
            presRunning = true
        }
    }

    // Single 16ms tick: updates elapsed time + lerps both progress markers.
    // Always running so the rabbit animates even while the timer is paused.
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            if (root.presRunning) {
                var now = Date.now()
                root.elapsedSec += (now - root.lastTickMs) / 1000.0
                root.lastTickMs = now
            }
            var tp = Math.min(root.elapsedSec / totalTimeSec, 1.0)
            var pp = pageCount > 1 ? root.currentPage / (pageCount - 1) : 0.0
            root.displayedTimerProg += (tp - root.displayedTimerProg) * 0.1
            root.displayedPageProg  += (pp - root.displayedPageProg)  * 0.1
        }
    }

    // ── PDF rendering ─────────────────────────────────────
    Image {
        anchors.fill: parent
        source: "image://pdf/" + root.currentPage
        sourceSize.width: width
        sourceSize.height: height
        cache: false
        fillMode: Image.Pad
    }

    // ── Progress bar overlay ──────────────────────────────
    Rectangle {
        id: bar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 32
        color: "#4D000000"

        Text {
            text: root.presRunning ? "🐢" : "🐢💤"
            font.family: "Noto Color Emoji"
            font.pointSize: 18
            color: "#33CC33"
            y: (bar.height - height) / 2
            x: root.displayedTimerProg * Math.max(bar.width - width, 0)
        }

        Text {
            text: "🐇"
            font.family: "Noto Color Emoji"
            font.pointSize: 18
            color: "#E64C4C"
            y: (bar.height - height) / 2
            x: root.displayedPageProg * Math.max(bar.width - width, 0)
        }
    }

    // ── Keyboard shortcuts ────────────────────────────────
    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
    Shortcut { sequence: "Space";  onActivated: root.toggleTimer() }
    Shortcut {
        sequence: "Right"
        onActivated: root.currentPage = Math.min(root.currentPage + 1, pageCount - 1)
    }
    Shortcut {
        sequence: "Left"
        onActivated: root.currentPage = Math.max(root.currentPage - 1, 0)
    }
    Shortcut { sequence: "Home"; onActivated: root.currentPage = 0 }
    Shortcut { sequence: "End";  onActivated: root.currentPage = pageCount - 1 }
}
