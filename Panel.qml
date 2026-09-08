import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ozdil.omacom-news"
  ipcTarget: "ozdil.omacom-news"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property int totalCount: 0
  property int unreadCount: 0
  property string latestTitle: ""
  property string latestDate: ""
  property var articles: []

  function resolveEnginePath() {
    return Qt.resolvedUrl("omacomnews-engine").toString().replace(/^file:\/\//, "")
  }

  function sendCmd(arg, param) {
    var eng = root.resolveEnginePath()
    if (param) {
      actionProc.command = [eng, arg, param]
    } else {
      actionProc.command = [eng, arg]
    }
    actionProc.running = true
  }

  IpcHandler {
    target: "ozdil.omacom-news"
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
  }

  Process {
    id: engineProc
    command: [root.resolveEnginePath(), "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var raw = String(text || "").slice(0, 65536)
          var data = JSON.parse(raw)
          root.totalCount = data.total || 0
          root.unreadCount = data.unread || 0
          root.latestTitle = data.latest_title || ""
          root.latestDate = data.latest_date || ""
          root.articles = data.articles || []
        } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    onExited: function(exitCode) {
      engineProc.running = true
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!engineProc.running) engineProc.running = true
    }
  }

  Component.onCompleted: {
    if (!engineProc.running) engineProc.running = true
  }
  Component.onDestruction: {
    if (engineProc.running) engineProc.running = false
    if (actionProc.running) actionProc.running = false
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    foreground: root.unreadCount > 0 ? "#22c55e" : (root.bar ? root.bar.foreground : Color.foreground)
    tooltipText: "Omacom News Hub" + (root.unreadCount > 0 ? ("\n" + root.unreadCount + " unread dispatch" + (root.unreadCount > 1 ? "es" : "")) : "\nAll dispatches read")
    onPressed: function(b) {
      root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        // ---------- Hero: Newspaper icon · title/status ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: ""
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Omacom News"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: (root.unreadCount > 0 ? (root.unreadCount + " UNREAD DISPATCHES") : "ALL DISPATCHES READ").toUpperCase()
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        // ---------- Latest Dispatches Section ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "FOUNDATION DISPATCHES"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.articles ? root.articles.slice(0, 6) : []
              delegate: Rectangle {
                width: parent.width
                height: Style.space(52)
                radius: Style.space(4)
                color: Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

                readonly property var artData: modelData

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(2)

                  Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: artData ? String(artData.title) : ""
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: artData ? !artData.is_read : false
                    elide: Text.ElideRight
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Text {
                      textFormat: Text.PlainText
                      text: artData ? (String(artData.date) + " • " + String(artData.author)) : ""
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                      textFormat: Text.PlainText
                      text: artData && artData.is_read ? "READ" : "NEW"
                      color: artData && artData.is_read ? Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6) : (root.bar ? root.bar.foreground : Color.foreground)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (artData && artData.url) root.sendCmd("--read", artData.url)
                  }
                }
              }
            }
          }
        }

        // ---------- Actions Section ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "ACTIONS"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Button {
              Layout.fillWidth: true
              text: "Mark All Read"
              onClicked: root.sendCmd("--mark-read")
            }

            Button {
              Layout.fillWidth: true
              text: "Refresh"
              onClicked: {
                if (!engineProc.running) engineProc.running = true
              }
            }
          }
        }
      }
    }
  }
}
