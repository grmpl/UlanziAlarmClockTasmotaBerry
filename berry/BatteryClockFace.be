import json

class BatteryClockFace
    var clockfaceManager
    var printer
    
    def init(clockfaceManager)
        print("BatteryClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.printer = clockfaceManager.printer;
        
        self.printer.change_font('MatrixDisplay3x5');
        self.printer.clear();
    end
    
    def deinit() 
        print("BatteryClockFace DeInit");
    end
    
    def render()       
        var sensors = json.load(tasmota.read_sensors())
        var value = sensors['ANALOG']['A1']
        var valueUnit = '%'
        var min = 2000
        var max = 2600
        
        if value < min
            value = min
        end
        if value > max
            value = max
        end
        
        value = int(((value - min) * 100) / (max - min))
        var temp_str = 'BAT ' + str(value) + "%"
        
        var x_offset = 4
        var y_offset = 1
        
        self.printer.print_string(temp_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness)
    end
end

return BatteryClockFace