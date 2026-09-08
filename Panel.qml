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
    foreground: root.unreadCount > 0 ? "#22c55e" : (root.bar ? root.bar.foreground : Color.foreground)
    tooltipText: "OmaNews Hub\n" +
                 (root.installedVersion ? ("Omarchy: " + root.installedVersion + (root.isSystemUpdated ? " (Güncel)\n" : " (Güncelleme var)\n")) : "") +
                 (root.latestRelease ? ("Son Dağıtım: " + root.latestRelease + "\n") : "") +
                 (root.unreadCount > 0 ? (root.unreadCount + " yeni bülten / güncelleme") : "Tüm haberler okundu")
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
                implicitHeight: verText.implicitHeight + Style.space(4)
                radius: Style.space(4)
                color: root.isSystemUpdated ? "#15803d" : "#b45309"

                Text {
                  id: verText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: (root.installedVersion ? ("Omarchy " + root.installedVersion) : "Omarchy") + (root.isSystemUpdated ? " • Güncel" : " • Yeni Sürüm!")
                  color: "#ffffff"
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: (root.unreadCount > 0 ? (root.unreadCount + " YENİ HABER & GÜNCELLEME") : "TÜM HABERLER VE SÜRÜMLER GÜNCEL").toUpperCase()
              color: root.unreadCount > 0 ? "#22c55e" : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
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
              { id: "ALL", label: "Tümü (" + root.totalCount + ")" },
              { id: "NEWS", label: "Haberler" },
              { id: "RELEASE", label: "Sürümler" },
              { id: "FOUNDATION", label: "Vakıf" }
            ]
            delegate: Rectangle {
              Layout.fillWidth: true
              implicitHeight: Style.space(28)
              radius: Style.space(4)
              color: root.currentCategory === modelData.id
                     ? (root.bar ? root.bar.foreground : Color.foreground)
                     : Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData.label
                color: root.currentCategory === modelData.id
                       ? (root.bar ? root.bar.background : Color.background)
                       : (root.bar ? root.bar.foreground : Color.foreground)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: root.currentCategory === modelData.id
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentCategory = modelData.id
                }
              }
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
              radius: Style.space(6)
              color: Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

              readonly property var artData: modelData

              function categoryColor(cat) {
                if (cat === "Release") return "#16a34a"
                if (cat === "Foundation") return "#d97706"
                if (cat === "Distro") return "#2563eb"
                if (cat === "Community") return "#7c3aed"
                if (cat === "Ecosystem") return "#db2777"
                return "#475569"
              }

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
                    implicitHeight: catLabel.implicitHeight + Style.space(2)
                    radius: Style.space(3)
                    color: categoryColor(artData ? artData.category : "")

                    Text {
                      id: catLabel
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: (artData ? artData.category : "").toUpperCase()
                      color: "#ffffff"
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
                    text: artData && artData.is_read ? "OKUNDU" : "YENİ"
                    color: artData && artData.is_read ? Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.8) : "#22c55e"
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
              text: "Tümünü Okundu Say"
              onClicked: root.sendCmd("--mark-read")
            }

            Button {
              Layout.fillWidth: true
              text: "Yenile"
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
