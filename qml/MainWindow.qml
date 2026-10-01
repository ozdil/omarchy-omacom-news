import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "theme"

Item {
    id: root

    property int totalCount: 0
    property int unreadCount: 0
    property string installedVersion: ""
    property string latestRelease: ""
    property bool isSystemUpdated: true
    property var articles: []
    property string currentCategory: "ALL" // "ALL", "NEWS", "RELEASE", "FOUNDATION"
    property string searchQuery: ""

    readonly property string enginePath: {
        var base = Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "");
        var parent = base.replace(/\/qml\/?$/, "");
        return parent + "/omacomnews-engine";
    }

    readonly property var displayArticles: {
        if (!root.articles || root.articles.length === 0) return [];
        var list = [];
        var query = root.searchQuery.toLowerCase().trim();

        for (var i = 0; i < root.articles.length; i++) {
            var a = root.articles[i];
            if (!a) continue;

            if (root.currentCategory === "RELEASE" && a.category !== "Release") continue;
            if (root.currentCategory === "FOUNDATION" && a.category !== "Foundation") continue;
            if (root.currentCategory === "DISTRO" && a.category !== "Distro") continue;
            if (root.currentCategory === "ECOSYSTEM" && (a.category !== "Ecosystem" && a.category !== "Community")) continue;
            if (root.currentCategory === "NEWS" && a.category === "Release") continue;

            if (query.length > 0) {
                var titleMatch = (a.title || "").toLowerCase().indexOf(query) !== -1;
                var excerptMatch = (a.excerpt || "").toLowerCase().indexOf(query) !== -1;
                var authorMatch = (a.author || "").toLowerCase().indexOf(query) !== -1;
                if (!titleMatch && !excerptMatch && !authorMatch) continue;
            }

            list.push(a);
        }
        return list;
    }

    function refresh() {
        if (!engineProc.running) {
            engineProc.running = true;
        }
    }

    function markRead(id) {
        actionProc.command = [root.enginePath, "--mark-read-single", id];
        actionProc.running = true;
    }

    function markAllRead() {
        actionProc.command = [root.enginePath, "--mark-all-read"];
        actionProc.running = true;
    }

    function openUrl(url) {
        if (!url) return;
        var u = String(url).trim().toLowerCase();
        if (u.indexOf("http://") === 0 || u.indexOf("https://") === 0) {
            Qt.openUrlExternally(url);
        }
    }

    Process {
        id: engineProc
        command: [root.enginePath, "--json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var raw = String(text || "").slice(0, 1048576);
                    var data = JSON.parse(raw || "{}");
                    root.totalCount = Number(data.total) || 0;
                    root.unreadCount = Number(data.unread) || 0;
                    root.installedVersion = data.installed_version || "";
                    root.latestRelease = data.latest_release || "";
                    root.isSystemUpdated = data.is_system_updated !== undefined ? data.is_system_updated : true;
                    root.articles = data.articles || [];
                } catch(e) {
                    console.warn("Failed to parse omacomnews json:", e);
                }
            }
        }
    }

    Process {
        id: actionProc
        onExited: root.refresh()
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // Header Bar
        Rectangle {
            Layout.fillWidth: true
            height: 68
            radius: Theme.radiusMd
            color: Theme.bgSurface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: Theme.iconNews
                    font.family: Theme.iconFont
                    font.pixelSize: 24
                    color: Theme.accent
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "OMANEWS COMMUNITY DISPATCH"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.textMain
                    }
                    Text {
                        text: "Omarchy Core Dispatches, Releases & Ecosystem Feeds"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textMuted
                    }
                }

                Item { Layout.fillWidth: true }

                // System Version Pill
                Rectangle {
                    height: 32
                    implicitWidth: verRow.implicitWidth + 20
                    radius: Theme.radiusSm
                    color: Theme.bgCard
                    border.color: Theme.border
                    border.width: 1

                    RowLayout {
                        id: verRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "Omarchy " + (root.installedVersion || "4.0.4-1")
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            color: Theme.textMain
                        }
                        Rectangle { width: 1; height: 14; color: Theme.border }
                        Text {
                            text: root.isSystemUpdated ? "Up to date" : ("New: " + root.latestRelease)
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            font.bold: true
                            color: root.isSystemUpdated ? Theme.accentSuccess : Theme.accentWarning
                        }
                    }
                }

                // Mark All Read Button
                Rectangle {
                    height: 34
                    implicitWidth: markAllRow.implicitWidth + 20
                    radius: Theme.radiusSm
                    color: markAllArea.containsMouse ? Theme.bgCardHover : Theme.bgCard
                    border.color: Theme.border
                    border.width: 1

                    RowLayout {
                        id: markAllRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: Theme.iconCheckAll
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: Theme.textMain
                        }
                        Text {
                            text: "Mark All Read"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textMain
                        }
                    }

                    MouseArea {
                        id: markAllArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.markAllRead()
                    }
                }

                // Refresh Button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.radiusSm
                    color: refreshArea.containsMouse ? Theme.bgCardHover : Theme.bgCard
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconRefresh
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: Theme.textMain
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }
            }
        }

        // Filter and Search Toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Filter Tabs
            Rectangle {
                height: 34
                implicitWidth: catTabRow.implicitWidth + 8
                radius: Theme.radiusSm
                color: Theme.bgSurface
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    id: catTabRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "ALL", name: "All Dispatches" },
                            { id: "NEWS", name: "News" },
                            { id: "RELEASE", name: "Releases" },
                            { id: "FOUNDATION", name: "Foundation" },
                            { id: "DISTRO", name: "Distro" },
                            { id: "ECOSYSTEM", name: "Ecosystem" }
                        ]

                        delegate: Rectangle {
                            height: 26
                            implicitWidth: tabLabel.implicitWidth + 16
                            radius: Theme.radiusSm
                            color: root.currentCategory === modelData.id ? Theme.bgCardHover : "transparent"

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: root.currentCategory === modelData.id
                                color: root.currentCategory === modelData.id ? Theme.textMain : Theme.textMuted
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentCategory = modelData.id
                            }
                        }
                    }
                }
            }

            // Search Bar
            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: Theme.radiusSm
                color: Theme.bgSurface
                border.color: searchInput.activeFocus ? Theme.borderLight : Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: Theme.iconSearch
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textMain
                        clip: true
                        onTextChanged: root.searchQuery = text

                        Text {
                            anchors.fill: parent
                            text: "Search news dispatches, release notes, authors..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textDim
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }
                }
            }
        }

        // Articles List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMd
            color: Theme.bgSurface
            border.color: Theme.border
            border.width: 1
            clip: true

            ListView {
                id: newsListView
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                model: root.displayArticles

                delegate: Rectangle {
                    width: newsListView.width
                    implicitHeight: articleCol.implicitHeight + 24
                    radius: Theme.radiusSm
                    color: modelData.is_read ? Theme.bgCard : Theme.bgCardHover
                    border.color: modelData.is_read ? Theme.border : Theme.borderLight
                    border.width: 1

                    ColumnLayout {
                        id: articleCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Category Badge
                            Rectangle {
                                height: 20
                                implicitWidth: catBadgeText.implicitWidth + 12
                                radius: 3
                                color: Theme.bgDark
                                border.color: Theme.border
                                border.width: 1

                                Text {
                                    id: catBadgeText
                                    anchors.centerIn: parent
                                    text: modelData.category || "News"
                                    font.family: Theme.monoFont
                                    font.pixelSize: 10
                                    color: Theme.accent
                                }
                            }

                            // Title
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: !modelData.is_read
                                color: Theme.textMain
                                elide: Text.ElideRight
                            }

                            // Author and Date
                            Text {
                                text: (modelData.author ? (modelData.author + " • ") : "") + (modelData.date || "")
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }

                            // Mark Read Action
                            Rectangle {
                                width: 28
                                height: 28
                                radius: Theme.radiusSm
                                visible: !modelData.is_read
                                color: markBtnArea.containsMouse ? Theme.bgCardHover : Theme.bgDark
                                border.color: Theme.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.iconCheck
                                    font.family: Theme.iconFont
                                    font.pixelSize: 11
                                    color: Theme.accentSuccess
                                }

                                MouseArea {
                                    id: markBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.markRead(modelData.id)
                                }
                            }

                            // Open in Browser Action
                            Rectangle {
                                width: 28
                                height: 28
                                radius: Theme.radiusSm
                                color: openBtnArea.containsMouse ? Theme.bgCardHover : Theme.bgDark
                                border.color: Theme.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.iconExternal
                                    font.family: Theme.iconFont
                                    font.pixelSize: 11
                                    color: Theme.textMain
                                }

                                MouseArea {
                                    id: openBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.markRead(modelData.id);
                                        root.openUrl(modelData.url);
                                    }
                                }
                            }
                        }

                        // Excerpt Text
                        Text {
                            Layout.fillWidth: true
                            text: modelData.excerpt || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.displayArticles.length === 0
                    text: "No articles match the current filter or search criteria."
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textMuted
                }
            }
        }
    }
}
