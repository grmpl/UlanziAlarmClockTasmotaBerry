import json

class BatteryClockFace
    var clockfaceManager
    var matrixController
    var showVoltage
    
    def init(clockfaceManager)
        print("BatteryClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('MatrixDisplay3x5');
        self.matrixController.clear();
        
        self.showVoltage = false
    end
    
    def deinit() 
        print("BatteryClockFace DeInit");
    end
    
    def handleActionButton()
        self.showVoltage = !self.showVoltage
    end
    
    def render()       
        var sensors = json.load(tasmota.read_sensors())
        var value = sensors['ANALOG']['A1']

        var bat_str = "???"

        if self.showVoltage
            bat_str = str(value) + "mV"
        else
            var min = 2000
            var max = 2600
            
            if value < min
                value = min
            end
            if value > max
                value = max
            end
            
            value = int(((value - min) * 100) / (max - min))
            bat_str = 'BAT ' + str(value) + "%"
        end
        
        var x_offset = 4
        var y_offset = 1
        
        self.matrixController.print_string(bat_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness)
    end
end

return BatteryClockFace