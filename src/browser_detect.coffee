check = (string)->
  navigator.userAgent.indexOf(string) != -1

exports.isOpera = check("OPR")
exports.isChrome = check("Chrome") && !exports.isOpera
exports.isFirefox = check("Firefox") && !exports.isOpera
exports.isMSIE = check("MSIE")
