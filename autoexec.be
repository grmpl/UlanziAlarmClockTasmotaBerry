import ClockfaceManager

def startClock()
  var _clockfaceManager = ClockfaceManager()
  tasmota.add_driver(_clockfaceManager)
end

log("Delay start of ClockfaceManager by 5 seconds",2)
tasmota.set_timer(5000,startClock)
