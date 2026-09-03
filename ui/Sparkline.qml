import QtQuick
import qs.Commons

// History graph. `series` holds one or two arrays, newest last, always
// `capacity` long. Plain mode fills the first series and draws the second
// as a line on top. Mirrored mode splits the height at the middle: the
// first series grows up from the centre, the second grows down, each on
// its own scale, the way iStat draws download over upload.
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
  property bool framed: false
  property bool mirrored: false

  readonly property real effectiveMax: seriesMax(0)
  readonly property real effectiveMax2: seriesMax(1)

  onSeriesChanged: requestPaint()
  onCapacityChanged: requestPaint()
  onColorChanged: requestPaint()
  onMaxValueChanged: requestPaint()
  onFramedChanged: requestPaint()
  onMirroredChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function arrayMax(arr): real {
    var m = minScale
    for (var i = 0; i < arr.length; i++) if (arr[i] > m) m = arr[i]
    return m
  }

  // Scale for one series: the fixed maximum when given, else the largest
  // sample. In plain mode both series share one scale so they compare.
  function seriesMax(index): real {
    if (maxValue > 0) return maxValue
    if (!series || series.length === 0) return minScale
    if (mirrored) return arrayMax(series[index] || [])
    var m = minScale
    for (var s = 0; s < series.length; s++) m = Math.max(m, arrayMax(series[s] || []))
    return m
  }

  // Path along `arr` from `baseline`, growing in `direction` (-1 up, +1
  // down) over `span` pixels.
  function trace(ctx, arr, max, stepX, baseline, direction, span) {
    var inset = lineWidth / 2
    var usable = Math.max(1, span - inset)
    ctx.beginPath()
    for (var i = 0; i < arr.length; i++) {
      var x = width - (arr.length - 1 - i) * stepX
      var y = baseline + direction * (inset + Math.max(0, Math.min(1, arr[i] / max)) * usable)
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
  }

  function drawSeries(ctx, arr, max, stepX, baseline, direction, span, stroke, fill) {
    if (arr.length < 2) return
    if (fill) {
      trace(ctx, arr, max, stepX, baseline, direction, span)
      var startX = width - (arr.length - 1) * stepX
      ctx.lineTo(width, baseline)
      ctx.lineTo(startX, baseline)
      ctx.closePath()
      ctx.fillStyle = Qt.rgba(stroke.r, stroke.g, stroke.b, fillOpacity)
      ctx.fill()
    }
    trace(ctx, arr, max, stepX, baseline, direction, span)
    ctx.strokeStyle = stroke
    ctx.lineWidth = lineWidth
    ctx.lineJoin = "round"
    ctx.stroke()
  }

  function drawFrame(ctx, mid) {
    ctx.lineWidth = 1
    ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.10)
    for (var g = 1; g < 4; g++) {
      var gy = Math.round(height * g / 4) + 0.5
      ctx.beginPath()
      ctx.moveTo(0, gy)
      ctx.lineTo(width, gy)
      ctx.stroke()
    }
    if (mirrored) {
      ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.35)
      ctx.beginPath()
      ctx.moveTo(0, Math.round(mid) + 0.5)
      ctx.lineTo(width, Math.round(mid) + 0.5)
      ctx.stroke()
    }
    ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.22)
    ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    if (width <= 0 || height <= 0) return
    var mid = height / 2
    if (framed) drawFrame(ctx, mid)
    if (!series || series.length === 0) return
    var stepX = width / Math.max(1, capacity - 1)

    if (mirrored && series.length >= 2) {
      drawSeries(ctx, series[0] || [], seriesMax(0), stepX, mid, -1, mid, color, true)
      drawSeries(ctx, series[1] || [], seriesMax(1), stepX, mid, 1, height - mid, color, true)
      return
    }

    var max = seriesMax(0)
    for (var s = series.length - 1; s >= 0; s--) {
      drawSeries(ctx, series[s] || [], max, stepX, height, -1, height, s === 0 ? color : secondaryColor, s === 0 && fillOpacity > 0)
    }
  }
}
