import json
import math
import util

var modes = ['illuminance']

class SensorClockFace
    var clockfaceManager
    var matrixController
    var modeIdx
    
    def init(clockfaceManager)
        print("SensorClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('MatrixDisplay3x5');
        self.matrixController.clear();
        
        self.modeIdx = 0
    end
    
    def deinit() 
        print("SensorClockFace DeInit");
    end
    
    def handleActionButton()
        self.modeIdx = (self.modeIdx + 1) % size(modes)
    end
    
    def render()
        self.matrixController.clear()
        var sensorInfo = json.load(tasmota.read_sensors())

        var x_offset = 2
        var y_offset = 1
        var sensor_str = "???"
        
        var sensor_reading = ""
        var suffix = ""
        
        
        if modes[self.modeIdx] == "illuminance"
            sensor_reading = str(sensorInfo['ANALOG']['Illuminance2'])
            suffix = "lx"
        end
        
        while size(sensor_reading + suffix) < 7
            sensor_reading = " " + sensor_reading
        end
        sensor_str = sensor_reading + suffix
        
        
        self.matrixController.print_string(sensor_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness)
    end
end

return SensorClockFace