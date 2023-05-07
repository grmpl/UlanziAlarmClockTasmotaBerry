import fonts
import json
import math
import introspect

import MatrixController

import BasicClockFace
import SecondsClockFace
import BEDClockFace
import BatteryClockFace
import NetClockFace

var clockFaces = [
    BasicClockFace,
    SecondsClockFace,
    BEDClockFace,
    BatteryClockFace,
    NetClockFace
];

class ClockfaceManager
    var matrixController
    var brightness
    var color
    var currentClockFace
    var currentClockFaceIdx
    
    
    def init() 
        print("ClockfaceManager Init");
        self.matrixController = MatrixController();
        
        self.brightness = 50;
        self.color = fonts.palette['red']
        
        self.currentClockFaceIdx = 0
        self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)
        
        tasmota.add_rule("Button1#State", / value, trigger, msg -> self.on_button_prev(value, trigger, msg))
        tasmota.add_rule("Button2#State", / value, trigger, msg -> self.on_button_action(value, trigger, msg))
        tasmota.add_rule("Button3#State", / value, trigger, msg -> self.on_button_next(value, trigger, msg))
    end
    
    def on_button_prev(value, trigger, msg)
        # print(value)
        # print(trigger)
        # print(msg)
        
        self.currentClockFaceIdx = (self.currentClockFaceIdx + (size(clockFaces) - 1)) % size(clockFaces)
        self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)
        
        self.redraw()
    end

    def on_button_action(value, trigger, msg)
        var handleActionMethod = introspect.get(self.currentClockFace, "handleActionButton");
        
        if handleActionMethod != nil
            self.currentClockFace.handleActionButton()
        end
    end

    def on_button_next(value, trigger, msg)
        # print(value)
        # print(trigger)
        # print(msg)

        self.currentClockFaceIdx = (self.currentClockFaceIdx + 1) % size(clockFaces)
        self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)
        
        self.redraw()
    end
    
    
    # This will be called automatically every 1s by the tasmota framework
    def every_second()
        self.update_brightness_from_sensor();
        
        self.redraw()
    end
    
    def redraw()
        #var start = tasmota.millis()
        
        self.currentClockFace.render()
        self.matrixController.draw()
        
        #print("Redraw took", tasmota.millis() - start, "ms")
    end
    
    def update_brightness_from_sensor()
        var sensors = json.load(tasmota.read_sensors());
        var illuminance = sensors['ANALOG']['Illuminance2'];
        
        var brightness = int(10 * math.log(illuminance));
        if brightness < 10
            brightness = 10;
        end
        if brightness > 90
            brightness = 90;
        end
        # print("Brightness: ", self.brightness, ", Illuminance: ", illuminance);
        
        self.brightness = brightness;
    end
    
end

return ClockfaceManager