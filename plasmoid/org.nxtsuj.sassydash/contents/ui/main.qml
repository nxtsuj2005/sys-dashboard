import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

// A desktop layout (containment), not a widget: Plasma sizes it to the screen,
// so there is nothing to drag. Panels are kept clear via availableScreenRect.
ContainmentItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Dashboard {
        x: root.availableScreenRect.x
        y: root.availableScreenRect.y
        width: root.availableScreenRect.width > 0 ? root.availableScreenRect.width : root.width
        height: root.availableScreenRect.height > 0 ? root.availableScreenRect.height : root.height
    }
}
