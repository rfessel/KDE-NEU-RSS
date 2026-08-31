/*
    SPDX-FileCopyrightText: 2026 Rafael
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQml

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

import "js/feeds.js" as FeedParser

PlasmoidItem {
    id: root

    property var allItems: []
    property var feedGroups: []
    property var feedFailures: []
    property var pendingUrls: []
    property int pendingItems: 0
    property double hangDeadline: 0
    property bool loading: false
    readonly property int headlineLines: Number(Plasmoid.configuration.headlineLines) || 2
    readonly property int newsColumns: Math.max(1, Math.min(4, Number(Plasmoid.configuration.columns) || 1))
    readonly property int refreshMinutesValue: (function() {
        var v = Number(Plasmoid.configuration.refreshMinutes);
        if (typeof Plasmoid.configuration.refreshMinutes === "undefined" || v === null || isNaN(v)) {
            return 10; // padrão; 0 = só manual
        }
        return v;
    })()
    readonly property var slicedAll: root.allItems.slice(0, Number(Plasmoid.configuration.maxItems) || 50)
    property var colViews: []
    property bool _yBusy: false
    property double gridContentY: 0
    property ListView masterCol: null
    property ListView _lastMaster: null
    property bool gridActive: false

    signal gridScrollDirty()

    onMasterColChanged: {
        root.updateGridScrollVisibility();
        if (root._lastMaster) {
            try {
                root._lastMaster.contentHeightChanged.disconnect(root.gridScrollDirty);
                root._lastMaster.heightChanged.disconnect(root.gridScrollDirty);
            } catch (e) {
            }
        }
        root._lastMaster = root.masterCol;
        if (root.masterCol) {
            root.masterCol.contentHeightChanged.connect(root.gridScrollDirty);
            root.masterCol.heightChanged.connect(root.gridScrollDirty);
        }
        root.updateGridScrollVisibility();
        root.gridScrollDirty();
    }

    onSlicedAllChanged: root.gridScrollDirty()

    function columnItems(idx) {
        var out = [];
        if (idx < 0 || idx >= root.newsColumns) {
            return out;
        }
        for (var i = idx; i < root.slicedAll.length; i += root.newsColumns) {
            out.push(root.slicedAll[i]);
        }
        return out;
    }

    onNewsColumnsChanged: {
        root.colViews = [];
        root.masterCol = null;
        root._yBusy = false;
        root.gridContentY = 0;
        root.updateGridScrollVisibility();
        root.gridScrollDirty();
    }

    function updateGridScrollVisibility() {
        root.gridActive = root.newsColumns > 1 && root.masterCol !== null;
    }

    function capFirst(str) {
        if (!str) return "";
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    function capWords(str) {
        return String(str).split(" ").map(root.capFirst).join(" ");
    }

    readonly property double gridScrollSize: {
        var m = root.masterCol;
        if (!m || root.newsColumns <= 1) {
            return 1.0;
        }
        if (m.contentHeight > m.height && m.height > 0) {
            return Math.min(1.0, m.height / m.contentHeight);
        }
        return 1.0;
    }

    readonly property double gridScrollPosition: {
        var m = root.masterCol;
        if (!m || root.newsColumns <= 1) {
            return 0.0;
        }
        var range = m.contentHeight - m.height;
        if (range <= 0) {
            return 0.0;
        }
        return Math.min(1.0 - root.gridScrollSize, Math.max(0.0, m.contentY / range));
    }

    function syncY(list, y) {
        if (root._yBusy) {
            return;
        }
        root._yBusy = true;
        root.gridContentY = Math.max(0, y);
        for (var i = 0; i < root.colViews.length; i++) {
            if (root.colViews[i] && root.colViews[i] !== list) {
                root.colViews[i].contentY = root.gridContentY;
            }
        }
        root._yBusy = false;
        root.gridScrollDirty();
    }
    readonly property string chosenIcon: (function() {
        var c = Plasmoid.configuration.customIcon;
        if (c && c.trim() !== "") {
            return c;
        }
        return Plasmoid.configuration.iconName || "view-pim-news";
    })()
    readonly property string iconResolvedName: root.iconIsFile(root.chosenIcon) ? "" : root.chosenIcon
    readonly property string iconResolvedSource: root.iconIsFile(root.chosenIcon) ? root.chosenIcon : ""

    function iconIsFile(value) {
        return value.indexOf("/") === 0 || value.indexOf("file://") === 0;
    }

    function applyIcon(name) {
        var n = (name || "").trim();
        if (!n || n === Plasmoid.configuration.iconName) {
            return;
        }
        Plasmoid.configuration.customIcon = "";
        Plasmoid.configuration.iconName = n;
        Plasmoid.icon = n;
    }

    function applyCustomIcon(url) {
        if (!url) {
            return;
        }
        Plasmoid.configuration.customIcon = url;
        Plasmoid.icon = url;
    }

    onChosenIconChanged: Plasmoid.icon = root.chosenIcon
    property string errorText: ""
    property string lastUpdated: ""

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 20

    // ---------------------------------------------------------------- plugins

    compactRepresentation: PlasmaComponents3.ToolButton {
        id: compactButton
        display: PlasmaComponents3.AbstractButton.IconOnly
        icon.name: root.iconResolvedName
        icon.source: root.iconResolvedSource
        text: Plasmoid.title
        Accessible.name: text
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        onClicked: root.expanded = !root.expanded
    }

    // ------------------------------------------------------------------ lógica

    function currentFeeds() {
        var f = Plasmoid.configuration.feeds;
        if (typeof f === "undefined" || f === null) {
            return [];
        }
        return f;
    }

    function feedCapFor(index) {
        var caps = Plasmoid.configuration.feedLimits;
        if (typeof caps === "undefined" || caps === null) {
            return 0;
        }
        var v = parseInt(String(caps[index]), 10);
        return isNaN(v) || v <= 0 ? 0 : v;
    }

    function sliceItems() {
        var limit = Number(Plasmoid.configuration.maxItems) || 50;
        var sliced = root.allItems.slice(0, limit);
        newsModel.clear();
        for (var i = 0; i < sliced.length; i++) {
            newsModel.append(sliced[i]);
        }
    }

    function feedErrorText(url, code) {
        var why;
        if (code === -2) {
            why = i18n("tempo esgotado");
        } else if (code === -1) {
            why = i18n("falha de conexão");
        } else if (code === 0) {
            why = i18n("resposta inválida (não é RSS) ou servidor inacessível");
        } else {
            why = i18n("HTTP %1", code);
        }
        return i18n("%1 — %2", url, why);
    }

    function finalizeLoad() {
        root.allItems = FeedParser.applyLimits(root.feedGroups, Number(Plasmoid.configuration.maxItems) || 0);
        root.errorText = root.feedFailures.join("\n");
        root.lastUpdated = Qt.formatTime(new Date(), "HH:mm:ss");
        root.loading = false;
        loadWatchdog.stop();
        hangTimer.stop();
        sliceItems();
    }

    function finishOne(url) {
        if (root.loading === false) {
            return; // já finalizado pelo watchdog
        }
        if (root.pendingItems <= 0) {
            return;
        }
        var pos = root.pendingUrls.indexOf(url);
        if (pos !== -1) {
            root.pendingUrls.splice(pos, 1);
        }
        root.pendingItems--;
        if (root.allItems.length === 0 && root.feedGroups.length > 0) {
            // Sem conteúdo ainda: mostra progressivamente ao chegar cada feed,
            // em vez de esperar todos (ou um lento) para aparecer.
            root.allItems = FeedParser.applyLimits(root.feedGroups, Number(Plasmoid.configuration.maxItems) || 0);
            root.errorText = root.feedFailures.join("\n");
            sliceItems();
        }
        if (root.pendingItems <= 0) {
            root.pendingItems = 0;
            finalizeLoad();
        }
    }

    function forceStuck() {
        if (!root.loading) {
            return;
        }
        var stuck = root.pendingUrls.slice();
        for (var i = 0; i < stuck.length; i++) {
            root.feedFailures.push(root.feedErrorText(stuck[i], -2));
            root.feedGroups.push({ items: [], cap: 0 });
            finishOne(stuck[i]);
        }
    }

    function loadAll() {
        var feeds = currentFeeds();
        if (feeds.length === 0) {
            root.allItems = [];
            root.loading = false;
            root.errorText = "";
            newsModel.clear();
            return;
        }

        root.loading = true;
        root.errorText = "";
        root.feedGroups = [];
        root.feedFailures = [];
        root.pendingUrls = feeds.slice();
        root.pendingItems = feeds.length;
        root.hangDeadline = Date.now() + 10000;
        loadWatchdog.restart();
        hangTimer.running = true;

        for (var f = 0; f < feeds.length; f++) {
            (function(url, idx) { // mantém o escopo da iteração
                try {
                    FeedParser.loadFeed(url,
                        function(items) {
                            console.log("[rssnoticias] feed OK:", url, "->", items.length, "itens");
                            root.feedGroups.push({ items: items, cap: root.feedCapFor(idx) });
                            finishOne(url);
                        },
                        function(code) {
                            console.warn("[rssnoticias] feed FALHOU:", url, "código", code);
                            root.feedFailures.push(root.feedErrorText(url, code));
                            root.feedGroups.push({ items: [], cap: 0 });
                            finishOne(url);
                        }
                    );
                } catch (e) {
                    console.warn("[rssnoticias] exceção ao carregar:", url, String(e));
                    root.feedFailures.push(i18n("Falha em %1 (%2)", url, String(e)));
                    root.feedGroups.push({ items: [], cap: 0 });
                    finishOne(url);
                }
            })(feeds[f], f);
        }
    }

    function openConfig() {
        // Plasma 6: o Applet expõe a ação "configure" (guia oficial de desenvolvedores).
        if (typeof plasmoid !== "undefined" && plasmoid.action && plasmoid.action("configure")) {
            plasmoid.action("configure").trigger();
        } else if (typeof Plasmoid.requestConfiguration === "function") {
            // Fallback para versões que ainda expõem este método.
            Plasmoid.requestConfiguration();
        }
    }

    Component.onCompleted: {
        Plasmoid.icon = root.chosenIcon;
        loadAll();
    }

    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            if (key === "feeds") {
                root.loadAll();
            } else if (key === "maxItems") {
                root.sliceItems();
            }
        }
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.loadAll(); // atualiza quando o popup do painel é aberto
        }
    }

    Timer {
        id: refreshTimer
        objectName: "refreshTimer"
        interval: root.refreshMinutesValue > 0 ? root.refreshMinutesValue * 60000 : 0
        repeat: true
        running: root.refreshMinutesValue > 0 && root.currentFeeds().length > 0
        onTriggered: root.loadAll()
    }

    onRefreshMinutesValueChanged: {
        // Reinicia a contagem ao trocar o intervalo nas configurações.
        if (refreshTimer.running) {
            refreshTimer.restart();
        } else {
            refreshTimer.start();
        }
    }

    // Segurança: se algo travar durante o carregamento, não fica no spinner para sempre.
    Timer {
        id: loadWatchdog
        interval: 30 * 1000
        repeat: false
        onTriggered: {
            root.forceStuck();
        }
    }

    Timer {
        id: hangTimer
        interval: 400
        repeat: true
        running: false
        onTriggered: {
            if (!root.loading) {
                running = false;
                return;
            }
            if (Date.now() >= root.hangDeadline) {
                root.forceStuck();
            }
        }
    }

    Timer {
        id: clockTimer
        interval: 60000
        repeat: true
        running: true
    }

    // ------------------------------------------------------------------- dados

    ListModel {
        id: newsModel
    }

    Component {
        id: newsCardDelegate

        Rectangle {
            id: card
            required property var model

            readonly property bool hovered: cardMouse.containsMouse
            readonly property bool _hasParent: parent !== null

            width: (_hasParent ? parent.width : 0) - 2 * Kirigami.Units.largeSpacing
            anchors.horizontalCenter: _hasParent ? parent.horizontalCenter : undefined
            height: contentText.implicitHeight + 16
            radius: Kirigami.Units.roundIconSize / 4
            color: card.hovered
                   ? Qt.alpha(PlasmaCore.Theme.highlightColor, 0.12)
                   : PlasmaCore.Theme.backgroundColor
            border.width: 1
            border.color: Qt.alpha(PlasmaCore.Theme.textColor, 0.08)

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Rectangle {
                id: thumbBox
                visible: card.model.image !== ""
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                width: 84
                height: 96
                radius: 6
                color: PlasmaCore.Theme.viewBackgroundColor
                clip: true

                Image {
                    anchors.fill: parent
                    source: card.model.image
                    fillMode: Image.PreserveAspectCrop
                    onStatusChanged: {
                        if (status === Image.Error) {
                            thumbBox.visible = false;
                        }
                    }
                }
            }

            Column {
                id: contentText
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.right: thumbBox.visible ? thumbBox.left : parent.right
                anchors.rightMargin: 8
                spacing: 2

                PlasmaComponents3.Label {
                    width: contentText.width
                    text: card.model.title
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                    color: PlasmaCore.Theme.textColor
                }

                PlasmaComponents3.Label {
                    width: contentText.width
                    anchors.topMargin: 2
                    visible: card.model.summary !== "" && root.headlineLines > 0
                    text: card.model.summary
                    wrapMode: Text.Wrap
                    maximumLineCount: root.headlineLines
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: Qt.alpha(PlasmaCore.Theme.textColor, 0.72)
                }

                Row {
                    width: contentText.width
                    anchors.topMargin: 2
                    spacing: 4

                    PlasmaComponents3.Label {
                        width: Math.min(contentText.width * 0.6, 220)
                        text: card.model.source
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: Qt.alpha(PlasmaCore.Theme.textColor, 0.65)
                    }
                    PlasmaComponents3.Label {
                        visible: card.model.time > 0 && card.model.source !== ""
                        text: "•"
                        font.pixelSize: 11
                        color: Qt.alpha(PlasmaCore.Theme.textColor, 0.45)
                    }
                    PlasmaComponents3.Label {
                        text: FeedParser.relativeTime(card.model.time)
                        font.pixelSize: 11
                        color: Qt.alpha(PlasmaCore.Theme.textColor, 0.45)
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(card.model.link)
                onPressed: card.opacity = 0.8
                onReleased: card.opacity = 1
            }
        }
    }

    // ----------------------------------------------------------------------- UI

    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // ---------------- Cabeçalho (estilo Windows 11)
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                display: PlasmaComponents3.AbstractButton.IconOnly
                icon.name: root.iconResolvedName
        icon.source: root.iconResolvedSource
                hoverEnabled: false
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignVCenter
                Accessible.name: "RSS"
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                readonly property string greeting: (function() {
                    var h = new Date().getHours();
                    var raw = "Boa noite";
                    if (h >= 5 && h < 12) raw = "Bom dia";
                    else if (h >= 12 && h < 18) raw = "Boa tarde";
                    return typeof i18n === "function" ? i18n(raw) : raw;
                })()

                KCoreAddons.KUser {
                    id: kuserInfo
                    objectName: "kuserInfo"
                }

                PlasmaExtras.Heading {
                    level: 3
                    objectName: "greetingHeading"
                    text: root.capWords(parent.greeting) + ", " + root.capFirst(kuserInfo.loginName)
                    Layout.fillWidth: true
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: new Date().toLocaleString(Qt.locale(), "dddd, dd MMMM")
                    opacity: 0.6
                    font.pixelSize: 11
                }
            }

            Item {
                Layout.fillWidth: true
            }

            PlasmaComponents3.ToolButton {
                id: refreshButton
                icon.name: root.loading ? "" : "view-refresh"
                Accessible.name: i18n("Atualizar notícias")
                onClicked: root.loadAll()

                Kirigami.Icon {
                    id: refreshSpinnerIcon
                    objectName: "refreshSpinnerIcon"
                    anchors.fill: parent
                    source: "view-refresh"
                    visible: root.loading
                    opacity: 0.88
                    transformOrigin: Item.Center

                    RotationAnimator {
                        id: refreshSpinnerAnimator
                        target: refreshSpinnerIcon
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                        running: refreshSpinnerIcon.visible
                    }
                }
            }
        }

        // ---------------- Corpo: lista de notícias em N colunas
        Item {
            id: bodyItem
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            readonly property double colW: root.newsColumns > 0
                    ? Math.max(0, bodyItem.width / root.newsColumns) : 0
            readonly property double colH: Math.max(0, bodyItem.height
                    - Kirigami.Units.smallSpacing - Kirigami.Units.largeSpacing)

            Repeater {
                model: root.newsColumns

                delegate: ListView {
                    id: colList
                    required property int index

                    x: index * bodyItem.colW
                    y: Kirigami.Units.smallSpacing
                    width: bodyItem.colW
                    height: bodyItem.colH
                    clip: true
                    model: root.columnItems(index)
                    spacing: Kirigami.Units.smallSpacing
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                        policy: root.newsColumns > 1
                                ? PlasmaComponents3.ScrollBar.AlwaysOff
                                : PlasmaComponents3.ScrollBar.AsNeeded
                    }

                    delegate: newsCardDelegate

                    footer: Item {
                        width: colList.width
                        height: Kirigami.Units.largeSpacing * 2
                    }

                    onContentYChanged: root.syncY(colList, contentY)

                    Component.onCompleted: {
                        while (root.colViews.length < root.newsColumns) {
                            root.colViews.push(null);
                        }
                        root.colViews[index] = colList;
                        if (index === 0) {
                            root.masterCol = colList;
                        }
                    }
                }
            }

            // Barra de rolagem única para todas as colunas
            Item {
                id: gridScrollWrap
                objectName: "gridScrollWrap"
                visible: root.gridActive
                anchors.top: parent.top
                anchors.topMargin: Kirigami.Units.smallSpacing
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Kirigami.Units.largeSpacing
                anchors.right: parent.right
                width: gridScroll.implicitWidth

                PlasmaComponents3.ScrollBar {
                    id: gridScroll
                    objectName: "gridScrollBar"
                    anchors.fill: parent
                    orientation: Qt.Vertical
                    interactive: true
                    size: 1.0
                    position: 0.0

                    Connections {
                        target: root
                        function onGridScrollDirty() {
                            gridScroll.size = root.gridScrollSize;
                            gridScroll.position = root.gridScrollPosition;
                        }
                    }

                    onPositionChanged: {
                        if (gridScroll.pressed && root.masterCol) {
                            var range = root.masterCol.contentHeight - root.masterCol.height;
                            if (range > 0) {
                                root.syncY(root.masterCol, gridScroll.position * range);
                            }
                        }
                    }
                }
            }

            // Carregando… (só aparece quando não há nada para mostrar)
            QQC2.BusyIndicator {
                anchors.centerIn: parent
                visible: root.loading && root.slicedAll.length === 0
                running: visible
            }

            // Estado vazio
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                visible: !root.loading && root.slicedAll.length === 0

                icon.name: root.iconResolvedName
        icon.source: root.iconResolvedSource
                text: root.currentFeeds().length === 0
                      ? i18n("Nenhum feed configurado")
                      : (root.errorText === ""
                         ? i18n("Nenhuma notícia encontrada")
                         : i18n("Nenhuma notícia carregada. Veja os detalhes abaixo."))

                helpfulAction: Kirigami.Action {
                    text: root.currentFeeds().length === 0 ? i18n("Adicionar feed…") : i18n("Tentar novamente")
                    icon.name: root.currentFeeds().length === 0 ? "list-add-symbolic" : "view-refresh"
                    onTriggered: root.currentFeeds().length === 0 ? root.openConfig() : root.loadAll()
                }
            }
        }

        // ---------------- Rodapé
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.InlineMessage {
                id: errorMessage
                Layout.fillWidth: true
                visible: root.errorText !== ""
                type: Kirigami.MessageType.Warning
                text: i18n("Alguns feeds não carregaram:") + "\n" + root.errorText
                showCloseButton: true
                onVisibleChanged: if (!visible) root.errorText = ""
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.lastUpdated === ""
                      ? ""
                      : i18n("Atualizado às %1", root.lastUpdated)
                opacity: 0.55
                font.pixelSize: 10
            }
        }
    }
}