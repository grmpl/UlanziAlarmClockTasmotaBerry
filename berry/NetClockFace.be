import json
import math
import util

var pageSize = 8;
var pageDisplayTime = 2;

var modes = ['rssi', 'ip', 'mac']

class NetClockFace
    var clockfaceManager
    var matrixController
    var modeIdx
    var page
    var displayTimeCounter
    
    def init(clockfaceManager)
        print("NetClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('MatrixDisplay3x5');
        self.matrixController.clear();
        
        self.modeIdx = 0
        self.page = 0
        self.displayTimeCounter = 0
    end
    
    def deinit() 
        print("NetClockFace DeInit");
    end
    
    def handleActionButton()
        self.modeIdx = (self.modeIdx + 1) % size(modes)
        self.page = 0
        self.displayTimeCounter = 0
    end
    
    def render()       
        var wifiInfo = tasmota.wifi()

        var x_offset = 1
        var y_offset = 1
        var wifi_str = "???"
        
        if wifiInfo["up"]
            if modes[self.modeIdx] == "q"
                var wifiQuality = str(wifiInfo["quality"])
                
                while size(wifiQuality) < 3
                    wifiQuality = " " + wifiQuality
                end
                
                wifi_str = " WF " + wifiQuality + "%"
            end
            if modes[self.modeIdx] == "ip"
                wifi_str = wifiInfo["ip"]
            end
            if modes[self.modeIdx] == "rssi"
                wifi_str = " " + str(wifiInfo["rssi"]) + " dBm"
            end
            if modes[self.modeIdx] == "mac"
                wifi_str = wifiInfo["mac"]
            end
        else
            wifi_str = "  DOWN  " # padding to overwrite old characters
        end
        
        if size(wifi_str) > pageSize
            var splitStr = util.splitStringToChunks(wifi_str, pageSize)
            wifi_str = splitStr[self.page]
            
            while size(wifi_str) <= pageSize # for good measure
                wifi_str += " " # pad with spaces to overwrite the previous characters
            end
            
            self.displayTimeCounter = (self.displayTimeCounter + 1) % (pageDisplayTime + 1)
            
            if self.displayTimeCounter == pageDisplayTime
                self.page = (self.page + 1) % size(splitStr)
            end
        else
            self.page = 0
            self.displayTimeCounter = 0
        end
        
        self.matrixController.print_string(wifi_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness)
    end
end

return NetClockFace