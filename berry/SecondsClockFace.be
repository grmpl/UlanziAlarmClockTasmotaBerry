class SecondsClockFace
    var clockfaceManager
    var printer
    
    def init(clockfaceManager)
        print("SecondsClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.printer = clockfaceManager.printer;
        
        self.printer.change_font('MatrixDisplay3x5');
        self.printer.clear();
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
        self.printer.print_string(time_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness)
    end
end

return SecondsClockFace