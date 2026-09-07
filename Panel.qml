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

  property int totalCount: 0
  property int unreadCount: 0
  property string latestTitle: ""
  property string latestDate: ""
  property var articles: []

  Process {
    id: engineProc
    command: [Qt.resolvedUrl("omacomnews-engine").toString().replace(/^file:\/\//, ""), "--json"]
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

  Component.onDestruction: {
    if (engineProc.running) engineProc.running = false
    if (actionProc.running) actionProc.running = false
  }

  function sendCmd(arg, param) {
    var eng = Qt.resolvedUrl("omacomnews-engine").toString().replace(/^file:\/\//, "")
    if (param) {
      actionProc.command = [eng, arg, param]
    } else {
      actionProc.command = [eng, arg]
    }
    actionProc.running = true
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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.unreadCount > 0 ? ("OMACOM: " + root.unreadCount + " NEW") : "OMACOM: NEWS"
    tooltipText: "Omacom Foundation News Hub\nLatest: " + root.latestTitle + "\nDate: " + root.latestDate + "\nUnread: " + root.unreadCount + "\nEngine: Native Rust"
    onPressed: function(b) { if (root.opened) root.close(); else root.open(); }
  }

  KeyboardPanel {
    bar: root.bar
    id: panel
    anchorItem: button
    owner: root
    implicitWidth: Style.space(560)
    contentHeight: Math.min(Style.space(680), panel.fittedContentHeight(mainCol.implicitHeight + Style.space(24)))

    Flickable {
      anchors.fill: parent
      anchors.margins: Style.space(12)
      contentHeight: mainCol.implicitHeight
      clip: true

      ColumnLayout {
        id: mainCol
        width: parent.width
        spacing: Style.space(12)

        // Header
        RowLayout {
          Layout.fillWidth: true
          ColumnLayout {
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              text: "OMACOM NEWS"
              font.bold: true
              font.pixelSize: Style.font.title
              color: "#f59e0b"
            }
            Text {
              textFormat: Text.PlainText
              text: "OMACOM FOUNDATION DISPATCHES • NATIVE ARCH"
              font.pixelSize: Style.font.caption
              color: "#94a3b8"
            }
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            width: Style.space(96)
            height: Style.space(24)
            radius: Style.space(4)
            color: root.unreadCount > 0 ? "#451a03" : "#1e293b"
            border.color: root.unreadCount > 0 ? "#f59e0b" : "#334155"
            border.width: 1
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.unreadCount > 0 ? (root.unreadCount + " UNREAD") : "ALL READ"
              font.bold: true
              font.pixelSize: Style.font.caption
              color: root.unreadCount > 0 ? "#fbbf24" : "#94a3b8"
            }
          }
        }

        // Summary Statistics Box
        Rectangle {
          Layout.fillWidth: true
          height: Style.space(52)
          radius: Style.space(8)
          color: "#0f172a"
          border.color: "#1e293b"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            ColumnLayout {
              spacing: Style.space(1)
              Text {
                textFormat: Text.PlainText
                text: "FOUNDATION ENDOWMENT"
                font.pixelSize: Style.font.caption
                color: "#64748b"
              }
              Text {
                textFormat: Text.PlainText
                text: "$12.6 MILLION"
                font.bold: true
                font.pixelSize: Style.font.body
                color: "#f8fafc"
              }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
              spacing: Style.space(1)
              Text {
                textFormat: Text.PlainText
                text: "TOTAL DISPATCHES"
                font.pixelSize: Style.font.caption
                color: "#64748b"
              }
              Text {
                textFormat: Text.PlainText
                text: root.totalCount + " POSTS"
                font.bold: true
                font.pixelSize: Style.font.body
                color: "#38bdf8"
              }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
              spacing: Style.space(1)
              Text {
                textFormat: Text.PlainText
                text: "NOTIFY SYSTEM"
                font.pixelSize: Style.font.caption
                color: "#64748b"
              }
              Text {
                textFormat: Text.PlainText
                text: "LIBNOTIFY ACTIVE"
                font.bold: true
                font.pixelSize: Style.font.body
                color: "#4ade80"
              }
            }
          }
        }

        // News Dispatches List Header
        Text {
          textFormat: Text.PlainText
          text: "RECENT FOUNDATION ANNOUNCEMENTS"
          font.bold: true
          font.pixelSize: Style.font.caption
          color: "#94a3b8"
        }

        // Dispatches Cards
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Repeater {
            model: root.articles
            delegate: Rectangle {
              Layout.fillWidth: true
              implicitHeight: cardCol.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: modelData.is_read ? "#0b1329" : "#0f172a"
              border.color: modelData.is_read ? "#1e293b" : "#b45309"
              border.width: 1

              ColumnLayout {
                id: cardCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(4)

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    textFormat: Text.PlainText
                    text: modelData.date.toUpperCase() + " • " + modelData.author.toUpperCase()
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: "#f59e0b"
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    textFormat: Text.PlainText
                    text: modelData.is_read ? "READ" : "NEW"
                    font.pixelSize: Style.font.caption
                    color: modelData.is_read ? "#64748b" : "#fbbf24"
                  }
                }

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: modelData.title.toUpperCase()
                  font.bold: true
                  font.pixelSize: Style.font.body
                  color: "#f8fafc"
                  wrapMode: Text.WordWrap
                }

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: modelData.excerpt
                  font.pixelSize: Style.font.caption
                  color: "#94a3b8"
                  wrapMode: Text.WordWrap
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Button {
                    text: "READ ONLINE"
                    onClicked: root.sendCmd("--read", modelData.url)
                  }

                  Button {
                    text: "SEND NOTIFY"
                    onClicked: root.sendCmd("--notify", modelData.id)
                  }
                }
              }
            }
          }
        }

        // Footer Actions
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Button {
            Layout.fillWidth: true
            text: "NOTIFY LATEST"
            onClicked: root.sendCmd("--notify")
          }

          Button {
            Layout.fillWidth: true
            text: "MARK ALL READ"
            onClicked: root.sendCmd("--mark-read")
          }

          Button {
            Layout.fillWidth: true
            text: "REFRESH"
            onClicked: {
              if (!engineProc.running) engineProc.running = true
            }
          }

          Button {
            Layout.fillWidth: true
            text: "CLOSE"
            onClicked: root.close()
          }
        }
      }
    }
  }
}
