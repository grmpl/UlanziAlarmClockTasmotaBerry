import mqtt
import fonts
import string

class SolarClockFace
    var clockfaceManager
    var matrixController
    
    var hasValue
    var value
    
    def init(clockfaceManager)
        print("SolarClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('Glance');
        self.matrixController.clear();
        
        self.hasValue = false
        self.value = 0
        
        mqtt.subscribe("ulanzi/sensor/solar_power", /topic, idx, payload, bindata -> self.handleMqttUpdate(payload))
    end
    
    def deinit() 
        print("SolarClockFace DeInit");
        
        mqtt.unsubscribe("ulanzi/sensor/solar_power")
    end
    
    def handleMqttUpdate(payload)
        self.hasValue = true
        self.value = number(payload)
    end
    
    def render()
        self.matrixController.clear()
        var solar_str = ""
        if self.hasValue
            solar_str = string.format("%4i W", self.value)
        else
            solar_str = "???? W"
        end
        
        var x_offset = 0
        var y_offset = 1
        
        print(solar_str)
        
        self.matrixController.print_string(solar_str, x_offset, y_offset, false, fonts.palette['blue'], self.clockfaceManager.brightness)
    end
    
end

return SolarClockFace