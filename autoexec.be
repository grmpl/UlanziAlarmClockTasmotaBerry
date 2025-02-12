import ClockfaceManager

var _clockfaceManager = ClockfaceManager() # global definition to be able to access it in case of debugging

def startClock()
  tasmota.add_driver(_clockfaceManager)
end

log("Delay start of ClockfaceManager by 5 seconds",2)
tasmota.set_timer(5000,startClock)
