import string

class DateClockFace
    var clockfaceManager
    var matrixController
    var showYear
    
    def init(clockfaceManager)
        print("DateClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('Glance');
        self.matrixController.clear();
        
        self.showYear = false
    end
    
    def deinit() 
        print("DateClockFace DeInit");
    end
    
    def handleActionButton()
        self.showYear = !self.showYear
    end
    
    def render()
        self.matrixController.clear()
        var rtc = tasmota.rtc()
        
        var time_data = tasmota.time_dump(rtc['local'])
        var x_offset = 5
        var y_offset = 0
        
        var date_str = ""
        if self.showYear != true
            date_str = string.format("%02i.%02i", time_data['day'], time_data['month'])
        else
            date_str = str(time_data["year"])
            x_offset += 2
        end
        
        self.matrixController.print_string(date_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness) 
    end
end

return DateClockFace