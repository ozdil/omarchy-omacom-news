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
  property string installedVersion: ""
  property string latestRelease: ""
  property bool isSystemUpdated: true
  property string latestTitle: ""
  property string latestDate: ""
  property var articles: []
  property string currentCategory: "ALL" // "ALL", "NEWS", "RELEASE", "FOUNDATION"

  readonly property var filteredArticles: {
    if (!root.articles || root.articles.length === 0) return []
    if (currentCategory === "ALL") return root.articles
    if (currentCategory === "RELEASE") {
      return root.articles.filter(function(a) { return a && a.category === "Release" })
    }
    if (currentCategory === "FOUNDATION") {
      return root.articles.filter(function(a) { return a && a.category === "Foundation" })
    }
    if (currentCategory === "NEWS") {
      return root.articles.filter(function(a) { return a && a.category !== "Release" })
    }
    return root.articles
  }

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
          var raw = String(text || "").slice(0, 1048576)
          var data = JSON.parse(raw)
          root.totalCount = data.total || 0
          root.unreadCount = data.unread || 0
          root.installedVersion = data.installed_version || ""
          root.latestRelease = data.latest_release || ""
          root.isSystemUpdated = data.is_system_updated !== undefined ? data.is_system_updated : true
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
    foreground: root.bar ? root.bar.foreground : Color.foreground
    tooltipText: "OmaNews Hub\n" +
                 (root.installedVersion ? ("Omarchy: " + root.installedVersion + (root.isSystemUpdated ? " (Up to date)\n" : " (Update available)\n")) : "") +
                 (root.latestRelease ? ("Latest Release: " + root.latestRelease + "\n") : "") +
                 (root.unreadCount > 0 ? (root.unreadCount + " unread dispatch" + (root.unreadCount > 1 ? "es" : "") + " / updates") : "All dispatches read")
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
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(620))

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(12)

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

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: "OmaNews"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Item { Layout.fillWidth: true }

              // System Version Badge
              Rectangle {
                implicitWidth: verText.implicitWidth + Style.space(12)
                implicitHeight: verText.implicitHeight + Style.space(6)
                radius: Style.cornerRadius
                color: Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
                border.color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                border.width: 1

                Text {
                  id: verText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: (root.installedVersion ? ("Omarchy " + root.installedVersion) : "Omarchy") + (root.isSystemUpdated ? " • Up to date" : " • Update Available!")
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: (root.unreadCount > 0 ? (root.unreadCount + " NEW DISPATCHES & UPDATES") : "ALL DISPATCHES & RELEASES UP TO DATE").toUpperCase()
              color: root.unreadCount > 0 ? (root.bar ? root.bar.foreground : Color.foreground) : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        // ---------- Filter Tabs Section ----------
        RowLayout {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "ALL", label: "All (" + root.totalCount + ")" },
              { id: "NEWS", label: "News" },
              { id: "RELEASE", label: "Releases" },
              { id: "FOUNDATION", label: "Foundation" }
            ]
            delegate: Button {
              Layout.fillWidth: true
              text: modelData.label
              selected: root.currentCategory === modelData.id
              bordered: true
              foreground: root.bar ? root.bar.foreground : Color.foreground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(5)
              onClicked: root.currentCategory = modelData.id
            }
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // ---------- Articles & Releases Feed List ----------
        Column {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.filteredArticles ? root.filteredArticles.slice(0, 8) : []
            delegate: Rectangle {
              width: parent.width
              implicitHeight: artLayout.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
              border.color: Qt.rgba(
                (root.bar ? root.bar.foreground : Color.foreground).r,
                (root.bar ? root.bar.foreground : Color.foreground).g,
                (root.bar ? root.bar.foreground : Color.foreground).b,
                0.12
              )
              border.width: 1

              readonly property var artData: modelData

              ColumnLayout {
                id: artLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(4)

                // Top: Category Badge, Read status & Date
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Rectangle {
                    implicitWidth: catLabel.implicitWidth + Style.space(10)
                    implicitHeight: catLabel.implicitHeight + Style.space(4)
                    radius: Style.cornerRadius
                    color: "transparent"
                    border.color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    border.width: 1

                    Text {
                      id: catLabel
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: (artData ? artData.category : "").toUpperCase()
                      color: root.bar ? root.bar.foreground : Color.foreground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.tiny || 9
                      font.bold: true
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: artData ? (artData.date + " • " + artData.author) : ""
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                    textFormat: Text.PlainText
                    text: artData && artData.is_read ? "READ" : "● NEW"
                    color: artData && artData.is_read ? Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8) : (root.bar ? root.bar.foreground : Color.foreground)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                // Title
                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: artData ? String(artData.title) : ""
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: artData ? !artData.is_read : false
                  wrapMode: Text.Wrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                }

                // Excerpt snippet
                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: artData ? String(artData.excerpt) : ""
                  color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (artData && artData.url) {
                    Qt.openUrlExternally(artData.url)
                    if (artData.id) root.sendCmd("--mark-read-single", artData.id)
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

            Button {
              Layout.fillWidth: true
              text: "omarchy.org"
              onClicked: Qt.openUrlExternally("https://omarchy.org/news")
            }
          }
        }
      }
    }
  }
}
