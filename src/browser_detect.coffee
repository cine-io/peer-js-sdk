check = (string)->
  navigator.userAgent.indexOf(string) != -1

exports.isChrome = check("Chrome")
exports.isOpera = check("Opera")
exports.isFirefox = check("Firefox")
exports.isMSIE = check("MSIE")
