import QtQuick
import qs.Commons

// History graph. `series` holds one or two arrays, newest last. The first
// is drawn filled, the second as a line on top in the secondary colour.
// `capacity` is how many samples span the full width, so a short history
// grows in from the right edge instead of stretching.
Canvas {
  id: root

  property var series: []
  property int capacity: 60
  property real maxValue: 0
  property real minScale: 1
  property color color: Color.foreground
  property color secondaryColor: Qt.darker(color, 1.7)
  property real fillOpacity: 0.28
  property real lineWidth: 1
  // Page graphs draw a faint frame and quarter gridlines; bar items do not.
  property bool framed: false
  readonly property real effectiveMax: scaleMax()

  onSeriesChanged: requestPaint()
  onFramedChanged: requestPaint()
  onCapacityChanged: requestPaint()
  onColorChanged: requestPaint()
  onMaxValueChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function scaleMax(): real {
    if (maxValue > 0) return maxValue
    var m = minScale
    for (var s = 0; s < series.length; s++) {
      var arr = series[s] || []
      for (var i = 0; i < arr.length; i++) if (arr[i] > m) m = arr[i]
    }
    return m
  }

  function trace(ctx, arr, max, stepX) {
    var inset = lineWidth / 2
    var span = Math.max(1, height - lineWidth)
    ctx.beginPath()
    for (var i = 0; i < arr.length; i++) {
      var x = width - (arr.length - 1 - i) * stepX
      var y = height - inset - Math.max(0, Math.min(1, arr[i] / max)) * span
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    if (width <= 0 || height <= 0) return
    if (framed) {
      ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.10)
      ctx.lineWidth = 1
      for (var g = 1; g < 4; g++) {
        var gy = Math.round(height * g / 4) + 0.5
        ctx.beginPath()
        ctx.moveTo(0, gy)
        ctx.lineTo(width, gy)
        ctx.stroke()
      }
      ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.22)
      ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
    }
    if (!series || series.length === 0) return
    var max = scaleMax()
    var stepX = width / Math.max(1, capacity - 1)
    for (var s = series.length - 1; s >= 0; s--) {
      var arr = series[s] || []
      if (arr.length < 2) continue
      var stroke = s === 0 ? color : secondaryColor
      if (s === 0 && fillOpacity > 0) {
        trace(ctx, arr, max, stepX)
        var startX = width - (arr.length - 1) * stepX
        ctx.lineTo(width, height)
        ctx.lineTo(startX, height)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(stroke.r, stroke.g, stroke.b, fillOpacity)
        ctx.fill()
      }
      trace(ctx, arr, max, stepX)
      ctx.strokeStyle = stroke
      ctx.lineWidth = lineWidth
      ctx.lineJoin = "round"
      ctx.stroke()
    }
  }
}
