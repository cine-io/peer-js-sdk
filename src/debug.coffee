if process.env.NODE_ENV == 'development'
  module.exports = (value)->
    return (messages...)->
      console.log(value, messages...)
else
  module.exports = ->
    return ->
