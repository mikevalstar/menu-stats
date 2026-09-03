import QtQuick
import qs.Commons

// Vertical level bar filled from the bottom.
Item {
  id: root

  property real level: 0
  property color color: Color.foreground
  property real trackOpacity: 0.12

  implicitWidth: Style.space(5)
  implicitHeight: Style.space(14)

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.trackOpacity)
  }

  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: Math.max(1, parent.height * Math.max(0, Math.min(1, root.level)))
    color: root.color
  }
}
