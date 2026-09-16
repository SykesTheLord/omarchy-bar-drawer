import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "DrawerModel.js" as Model

// A bar button that holds other bar widgets.
//
// Children are instantiated from the host bar's widget registry and injected
// exactly the way Bar.qml's ModuleSlot does it: built-in widgets get the Bar
// root, installed widgets get their own scoped facade from pluginBarApiFor().
// That keeps services, tooltips, popout coordination and click targets
// working for widgets that were never written with a drawer in mind.
//
// A third-party widget only receives a facade, so the Bar root is found by
// scanning this bar window for a built-in widget that was handed it.
BarWidget {
  id: root
  moduleName: "io.github.sykesthelord.bar-drawer"

  property var host: null
  property int hostScanAttempts: 0
  property string region: "right"

  readonly property string mode: setting("mode", "dropdown") === "inline" ? "inline" : "dropdown"
  readonly property bool hoverTrigger: setting("trigger", "click") === "hover"
  readonly property int columns: Math.max(0, Math.floor(Number(setting("columns", 0)) || 0))
  readonly property string position: bar ? String(bar.position || "top") : "top"
  readonly property string customIcon: String(setting("icon", ""))
  readonly property string icon: customIcon !== "" ? customIcon : Model.defaultIcon(position)
  readonly property string label: String(setting("label", ""))
  readonly property var shellConfig: host && host.shell ? host.shell.shellConfig : null

  // itemModel only changes when the ids do, so a settings write for one
  // child does not rebuild every widget in the drawer.
  property var itemModel: []
  property var itemEntries: []
  property var childSlots: []

  property bool expanded: false
  readonly property bool opened: expanded
  property bool popoutSwitchClosing: false

  // Inline reveals toward the bar centre: before the button in the right
  // section (bottom on a vertical bar), after it everywhere else.
  readonly property bool revealBefore: region === "right"
  readonly property Item toggleButton: label === "" ? iconButton : labelButton
  readonly property bool childPopoutOpen: {
    var active = host ? host.activePopout : null
    return !!active && active !== root && ownsPopout(active)
  }

  implicitWidth: vertical
    ? barSize
    : toggleButton.implicitWidth + (mode === "inline" ? inlineReveal.width : 0)
  implicitHeight: vertical
    ? toggleButton.implicitHeight + (mode === "inline" ? inlineReveal.height : 0)
    : barSize

  function open() {
    if (expanded) return
    expanded = true
    if (bar) bar.requestPopout(root)
  }

  function close() {
    if (!expanded) return
    closeChildPopout()
    expanded = false
    hoverCloseTimer.stop()
    if (bar) bar.releasePopout(root)
  }

  function toggle() { expanded ? close() : open() }

  // Bar.requestPopout() calls this on the current owner before handing the
  // popout to someone else. That someone may be one of our own children, so
  // the decision waits for activePopout to settle (see reconcilePopout).
  function closeForPopoutSwitch() { }

  function reconcilePopout() {
    if (!expanded || !host) return
    var active = host.activePopout
    if (active === root) return
    if (active === null) {
      // A child closed its panel. Take the popout back so the next widget
      // that opens elsewhere on the bar closes this drawer.
      Qt.callLater(reclaimPopout)
      return
    }
    if (ownsPopout(active)) return
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  function reclaimPopout() {
    if (expanded && host && host.activePopout === null && bar) bar.requestPopout(root)
  }

  function ownsPopout(target) {
    if (!target) return false
    var anchor = null
    try { anchor = target.anchorItem } catch (e) { anchor = null }
    for (var i = 0; i < childSlots.length; i++) {
      var slot = childSlots[i]
      if (!slot) continue
      if (slot.activeItem === target) return true
      if (anchor && Model.isDescendant(anchor, slot)) return true
    }
    return false
  }

  function closeChildPopout() {
    var active = host ? host.activePopout : null
    if (active && active !== root && ownsPopout(active) && typeof active.close === "function")
      active.close()
  }

  function registerChild(slot) {
    if (childSlots.indexOf(slot) === -1) childSlots = childSlots.concat([slot])
  }

  function unregisterChild(slot) {
    childSlots = childSlots.filter(function(item) { return item !== slot })
  }

  function syncItems() {
    var entries = Model.normalizeItems(setting("items", []), moduleName)
    itemEntries = entries
    var ids = entries.map(function(entry) { return entry.id })
    if (ids.join("\n") !== itemModel.join("\n")) itemModel = ids
  }

  function resolveHost() {
    var found = Model.isHostBar(root.bar) ? root.bar : null
    if (!found) {
      var win = root.QsWindow.window
      found = win ? Model.findHostBar(win.contentItem) : null
    }
    if (found !== host) host = found
    if (!found && hostScanAttempts < 40) {
      hostScanAttempts++
      hostRetry.restart()
    }
  }

  function detectRegion() {
    var node = root.parent
    for (var guard = 0; node && guard < 16; guard++, node = node.parent) {
      if (node.region !== undefined && typeof node.region === "string" && node.region !== "") {
        region = node.region
        return
      }
    }
  }

  // The bar hit-tests click targets last-first by mapping coordinates, and
  // that mapping ignores which window an item lives in. Keeping the toggle
  // after the shelf's children means a click on the toggle can never be
  // claimed by a child that happens to sit at the same local position.
  function raiseToggleClickTarget() {
    Qt.callLater(function() {
      iconButton.syncClickRegistration()
      labelButton.syncClickRegistration()
    })
  }

  function pointerInside() {
    return rootHover.hovered || (mode === "dropdown" && shelf.containsMouse)
  }

  function syncHover() {
    if (!hoverTrigger) return
    if (pointerInside()) {
      hoverCloseTimer.stop()
      open()
    } else if (expanded) {
      hoverCloseTimer.restart()
    }
  }

  function handlePress(button) {
    if (button === Qt.MiddleButton) return
    toggle()
  }

  onSettingsChanged: syncItems()
  onBarChanged: {
    hostScanAttempts = 0
    Qt.callLater(resolveHost)
  }
  onChildPopoutOpenChanged: if (!childPopoutOpen && hoverTrigger && expanded) hoverCloseTimer.restart()
  onModeChanged: close()

  Component.onCompleted: {
    detectRegion()
    syncItems()
    Qt.callLater(resolveHost)
  }
  Component.onDestruction: if (bar && expanded) bar.releasePopout(root)

  Connections {
    target: root.host
    ignoreUnknownSignals: true
    function onActivePopoutChanged() { root.reconcilePopout() }
  }

  Connections {
    target: shelf
    function onContainsMouseChanged() { root.syncHover() }
  }

  Timer {
    id: hostRetry
    interval: 250
    onTriggered: root.resolveHost()
  }

  Timer {
    id: hoverCloseTimer
    interval: 350
    onTriggered: if (!root.pointerInside() && !root.childPopoutOpen) root.close()
  }

  HoverHandler {
    id: rootHover
    enabled: root.hoverTrigger
    onHoveredChanged: root.syncHover()
  }

  BarIconButton {
    id: iconButton
    visible: root.label === ""
    bar: root.bar
    x: !root.vertical && root.mode === "inline" && root.revealBefore ? inlineReveal.width : 0
    y: root.vertical && root.mode === "inline" && root.revealBefore ? inlineReveal.height : 0
    width: implicitWidth
    height: implicitHeight
    text: root.icon
    textRotation: root.customIcon === "" && root.expanded ? 180 : 0
    dimmed: root.host === null
    tooltipText: root.host === null
      ? "Drawer needs at least one built-in Omarchy widget on this bar"
      : (String(root.setting("tooltip", ""))
        || root.itemModel.length + (root.itemModel.length === 1 ? " widget" : " widgets"))
    onPressed: function(button) { root.handlePress(button) }
  }

  WidgetButton {
    id: labelButton
    visible: root.label !== ""
    bar: root.bar
    x: iconButton.x
    y: iconButton.y
    width: implicitWidth
    height: implicitHeight
    text: root.icon + "  " + root.label
    horizontalMargin: 7.5
    dimmed: iconButton.dimmed
    tooltipText: iconButton.tooltipText
    onPressed: function(button) { root.handlePress(button) }
  }

  // ---------------------------------------------------------------- inline

  Item {
    id: inlineReveal

    property real progress: root.mode === "inline" && root.expanded ? 1 : 0
    readonly property Item grid: inlineLoader.item
    readonly property real fullExtent: grid ? (root.vertical ? grid.implicitHeight : grid.implicitWidth) : 0

    Behavior on progress {
      NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    visible: root.mode === "inline" && progress > 0
    clip: true
    x: !root.vertical && !root.revealBefore ? root.toggleButton.implicitWidth : 0
    y: root.vertical && !root.revealBefore ? root.toggleButton.implicitHeight : 0
    width: root.vertical ? root.barSize : Math.round(fullExtent * progress)
    height: root.vertical ? Math.round(fullExtent * progress) : root.barSize

    Loader {
      id: inlineLoader
      active: root.mode === "inline"
      sourceComponent: childGridComponent
      // Pin the content to the edge next to the button so it slides out
      // from behind it instead of being uncovered from the far side.
      x: !root.vertical && root.revealBefore && item ? inlineReveal.width - item.implicitWidth : 0
      y: root.vertical && root.revealBefore && item ? inlineReveal.height - item.implicitHeight : 0
    }
  }

  // -------------------------------------------------------------- dropdown

  Shelf {
    id: shelf
    host: root.host
    anchorItem: root.toggleButton
    open: root.mode === "dropdown" && root.expanded
    suspendDismiss: root.childPopoutOpen
    clickDismiss: !root.hoverTrigger
    contentWidth: shelfLoader.item ? shelfLoader.item.implicitWidth : 0
    contentHeight: shelfLoader.item ? shelfLoader.item.implicitHeight : 0
    onDismissed: root.close()

    Loader {
      id: shelfLoader
      active: root.mode === "dropdown"
      sourceComponent: childGridComponent
    }
  }

  // -------------------------------------------------------------- children

  Component {
    id: childGridComponent

    Grid {
      readonly property int count: root.itemModel.length
      readonly property int perLine: root.mode === "dropdown" && root.columns > 0
        ? root.columns : Math.max(1, count)

      flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
      columns: root.vertical ? -1 : perLine
      rows: root.vertical ? perLine : -1
      spacing: root.mode === "dropdown" ? Style.spacing.xs : 0

      Text {
        visible: parent.count === 0 && root.mode === "dropdown"
        text: "Empty drawer — omarchy-bar-drawer add <widget-id>"
        color: Color.muted
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        padding: Style.spacing.sm
      }

      Repeater {
        model: root.itemModel
        delegate: DrawerChild { }
      }
    }
  }

  component DrawerChild: Item {
    id: child

    required property var modelData
    required property int index

    readonly property string childId: String(modelData)
    readonly property var registryEntry: {
      var registry = root.host ? root.host.barWidgetRegistry : null
      var widgets = registry ? registry.widgets : null
      return widgets && widgets[childId] ? widgets[childId] : null
    }
    readonly property bool firstParty: !!registryEntry && !!registryEntry.metadata
      && registryEntry.metadata.firstParty === true
    readonly property var childSettings: Model.childSettings(root.itemEntries[index], childId, root.shellConfig)
    readonly property Item activeItem: loader.item
    readonly property bool missing: root.host !== null && registryEntry === null
    property string injectedSettingsJson: ""

    implicitWidth: missing
      ? placeholder.implicitWidth
      : (activeItem && activeItem.visible ? (root.vertical ? root.barSize : activeItem.implicitWidth) : 0)
    implicitHeight: missing
      ? placeholder.implicitHeight
      : (activeItem && activeItem.visible ? activeItem.implicitHeight : 0)
    width: implicitWidth
    height: implicitHeight

    function inject(force) {
      var target = loader.item
      if (!target || !root.host) return
      if ("bar" in target) {
        var nextBar = firstParty ? root.host : root.host.pluginBarApiFor(childId, childId, true)
        if (target.bar !== nextBar) target.bar = nextBar
      }
      if ("moduleName" in target && target.moduleName !== childId) target.moduleName = childId
      if ("settings" in target) {
        var json = JSON.stringify(childSettings)
        if (force || json !== injectedSettingsJson) {
          injectedSettingsJson = json
          target.settings = childSettings
        }
      }
      root.raiseToggleClickTarget()
    }

    onChildSettingsChanged: inject(false)
    Component.onCompleted: root.registerChild(child)
    Component.onDestruction: if (root) root.unregisterChild(child)

    // The bar prunes facades that no bar slot references, and a drawer child
    // is not a bar slot. Re-inject whenever the facade map changes so a
    // pruned facade is replaced instead of left dangling.
    Connections {
      target: root.host
      ignoreUnknownSignals: true
      function onPluginBarApisChanged() { if (!child.firstParty) child.inject(false) }
    }

    Loader {
      id: loader
      anchors.fill: parent
      active: child.registryEntry !== null
      sourceComponent: child.registryEntry ? child.registryEntry.component : null
      onLoaded: {
        child.inject(true)
        Qt.callLater(function() { if (child) child.inject(false) })
      }
    }

    Text {
      id: placeholder
      visible: child.missing
      anchors.centerIn: parent
      text: "⚠ " + child.childId
      color: Color.muted
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      padding: Style.spacing.sm

      HoverHandler {
        onHoveredChanged: {
          if (!root.bar) return
          if (hovered) root.bar.showTooltip(placeholder, child.childId
            + " is not a loaded bar widget. Installed plugins need a { \"id\": \"" + child.childId
            + "\" } entry in plugins[] of shell.json.")
          else root.bar.hideTooltip(placeholder)
        }
      }
    }
  }
}
