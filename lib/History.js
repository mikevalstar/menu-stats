.pragma library

// Fixed-length series helpers. Series are plain arrays, newest last, and
// every operation returns a new array so QML property bindings see a change.

function push(series, value, length) {
  var base = Array.isArray(series) ? series : []
  var keep = Math.max(0, length - 1)
  var next = base.length > keep ? base.slice(base.length - keep) : base.slice()
  next.push(value)
  return next
}

function trim(series, length) {
  var base = Array.isArray(series) ? series : []
  return base.length > length ? base.slice(base.length - length) : base
}

function max(series) {
  var m = 0
  for (var i = 0; i < series.length; i++) if (series[i] > m) m = series[i]
  return m
}

function last(series) {
  return series.length > 0 ? series[series.length - 1] : 0
}
