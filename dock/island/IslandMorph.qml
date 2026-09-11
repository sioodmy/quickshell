import QtQuick

/**
 * Two-slot crossfade container for dynamic island contents.
 *
 * A single Loader cannot morph cleanly: swapping `sourceComponent` destroys the
 * old tree in the same frame the new one is built, so the notch spring briefly
 * chases an implicit size of 0 and the contents pop. Building the tree
 * synchronously also blocks the GUI thread, which stalls that spring for as
 * long as the heaviest island takes to construct.
 *
 * So the incoming tree is incubated asynchronously into the back slot while the
 * front slot keeps painting at its own size, and the slots swap only once the
 * new tree is fully built. `implicitWidth`/`implicitHeight` follow the front
 * slot alone, so the notch never resizes around content that isn't there yet,
 * and there is never a frame without content.
 */
Item {
    id: morph

    /// Identity of the requested content. Changing this starts a morph.
    property string requestedKey: ""

    /// Maps a key to the Component to build, or null for "nothing to show".
    property var resolve: null

    property int fadeInDuration: 180
    property int fadeOutDuration: 120

    /// Key actually on screen. Lags `requestedKey` while the next tree builds.
    readonly property string displayedKey: _displayedKey
    // `Loader.item` is a QObject, so this stays untyped.
    readonly property var displayedItem: _frontIsA ? slotA.item : slotB.item

    /// True while an incoming tree is still incubating.
    readonly property bool morphing: _incomingKey !== ""

    property string _displayedKey: ""
    property string _incomingKey: ""
    property bool _frontIsA: true

    readonly property Loader _frontSlot: _frontIsA ? slotA : slotB
    readonly property Loader _backSlot: _frontIsA ? slotB : slotA

    implicitWidth: displayedItem ? displayedItem.implicitWidth : 0
    implicitHeight: displayedItem ? displayedItem.implicitHeight : 0

    onRequestedKeyChanged: _sync()
    Component.onCompleted: _sync()

    function _sync() {
        if (!resolve || _incomingKey === requestedKey)
            return;

        if (requestedKey === _displayedKey) {
            // Reverted while the next tree was still building — drop it.
            if (_incomingKey !== "") {
                _incomingKey = "";
                _backSlot.sourceComponent = null;
            }
            return;
        }

        _incomingKey = requestedKey;

        var comp = resolve(requestedKey);
        if (!comp) {
            // Nothing to build (collapsed dock): swap on the spot.
            _backSlot.sourceComponent = null;
            _promote();
            return;
        }

        _backSlot.sourceComponent = comp;
        // An already-incubated component reaches Ready before the assignment
        // returns, so onStatusChanged never fires for it.
        if (_backSlot.status === Loader.Ready && _incomingKey !== "")
            _promote();
    }

    function _onSlotReady(slot) {
        if (_incomingKey !== "" && slot === _backSlot)
            _promote();
    }

    function _promote() {
        _displayedKey = _incomingKey;
        _incomingKey = "";
        _frontIsA = !_frontIsA;
        releaseTimer.restart();
        // The request may have moved on again while this tree was building.
        _sync();
    }

    // Frees the outgoing tree once it has finished fading out. Skipped when a
    // newer morph has already claimed the slot for its own incoming content.
    Timer {
        id: releaseTimer
        interval: morph.fadeOutDuration + 40
        onTriggered: {
            if (morph._incomingKey === "")
                morph._backSlot.sourceComponent = null;
        }
    }

    // Durations are passed in rather than read off `morph`, so the inline
    // component does not depend on outer-document ids resolving.
    component Slot: Loader {
        property bool isFront: false
        property int fadeIn: 180
        property int fadeOut: 120

        // Incubate off the critical path so building a heavy island never
        // stalls the notch spring mid-flight.
        asynchronous: true
        anchors.centerIn: parent
        opacity: isFront ? 1 : 0
        visible: opacity > 0.001
        // A slight inset on the way in reads as content emerging from the
        // notch rather than being cross-dissolved in place.
        scale: 0.96 + 0.04 * opacity

        Behavior on opacity {
            NumberAnimation {
                duration: isFront ? fadeIn : fadeOut
                easing.type: Easing.OutCubic
            }
        }
    }

    Slot {
        id: slotA
        isFront: morph._frontIsA
        fadeIn: morph.fadeInDuration
        fadeOut: morph.fadeOutDuration
        onStatusChanged: if (status === Loader.Ready) morph._onSlotReady(slotA)
    }

    Slot {
        id: slotB
        isFront: !morph._frontIsA
        fadeIn: morph.fadeInDuration
        fadeOut: morph.fadeOutDuration
        onStatusChanged: if (status === Loader.Ready) morph._onSlotReady(slotB)
    }
}
