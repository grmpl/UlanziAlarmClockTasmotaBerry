class SecondsClockFace
    var clockfaceManager
    var matrixController
    
    def init(clockfaceManager)
        print("SecondsClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('MatrixDisplay3x5');
        self.matrixController.clear();
    end
    
    def deinit() 
        print("SecondsClockFace DeInit");

    end
    
    def render()       
        var rtc = tasmota.rtc()
        # print("RTC: ", rtc)
        var time_str = tasmota.strftime('%H:%M:%S', rtc['local'])
        var x_offset = 2
        var y_offset = 1
        self.matrixController.print_string(time_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness)
    end
end

return SecondsClockFace