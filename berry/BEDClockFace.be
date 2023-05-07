import mqtt
import fonts
import string

class BEDClockFace
    var clockfaceManager
    var matrixController
    
    var hasValue
    var value
    
    def init(clockfaceManager)
        print("BEDClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('Glance');
        self.matrixController.clear();
        
        self.hasValue = false
        self.value = 0
        
        mqtt.subscribe("esp8266-geigercounter/GEIGERCTR-920FC2_usv/state", /topic, idx, payload, bindata -> self.handleMqttUpdate(payload))
    end
    
    def deinit() 
        print("BEDClockFace DeInit");
        
        mqtt.unsubscribe("esp8266-geigercounter/GEIGERCTR-920FC2_usv/state")
    end
    
    def handleMqttUpdate(payload)
        self.hasValue = true
        self.value = number(payload) / 0.1
    end
    
    def render()
        self.matrixController.clear()
        var bed_str = ""
        if self.hasValue
            bed_str = string.format("%5.1f", self.value)
        else
            bed_str = " ???"
        end
        
        var x_offset = 2
        var y_offset = 1
        
        self.matrixController.print_char("\xa5", 0 + x_offset, 0, fonts.palette['yellow'], self.clockfaceManager.brightness)
        self.matrixController.print_string(bed_str, 0 + x_offset + 8, 0 + y_offset, fonts.palette['yellow'], self.clockfaceManager.brightness)
    end
    
    def handleActionButton()
        print("Banana")
    end
end

return BEDClockFace