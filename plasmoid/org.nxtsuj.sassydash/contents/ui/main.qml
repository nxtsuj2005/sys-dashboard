import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    fullRepresentation: Dashboard {
        Layout.minimumWidth: 960
        Layout.minimumHeight: 600
        Layout.preferredWidth: 1600
        Layout.preferredHeight: 900
    }
}
