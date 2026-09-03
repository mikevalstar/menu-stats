import QtQuick
import qs.Commons

// Label on the left, value on the right. One line of a metric page.
Item {
  id: root

  property string label: ""
  property string value: ""
  // A header row introduces a group of rows, in the section-header style.
  property bool header: false
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight) + (header ? Style.spacing.sm : 0)

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.right: valueText.left
    anchors.rightMargin: Style.spacing.md
    anchors.bottom: parent.bottom
    textFormat: Text.PlainText
    text: root.header ? root.label.toUpperCase() : root.label
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: root.header ? Style.font.caption : Style.font.body
    font.bold: root.header
    font.letterSpacing: root.header ? 1.2 : 0
    elide: Text.ElideRight
  }

  Text {
    id: valueText
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    visible: !root.header
    textFormat: Text.PlainText
    text: root.value
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }
}
