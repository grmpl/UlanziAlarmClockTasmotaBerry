var render_loop_cron_id = "basic_clock_face_render";

class BasicClockFace
    var clockfaceManager
    var matrixController
    
    def init(clockfaceManager)
        print("BasicClockFace Init");
        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
        
        self.matrixController.change_font('Glance');
        self.matrixController.clear();
        

    end
    
    def deinit() 
        print("BasicClockFace DeInit");

    end
    
    def render()       
        var rtc = tasmota.rtc()
        
        var time_str = tasmota.strftime('%H:%M', rtc['local'])
        var x_offset = 5
        var y_offset = 0
        self.matrixController.print_string(time_str, 0 + x_offset, 0 + y_offset, self.clockfaceManager.color, self.clockfaceManager.brightness)
        
        var current_seconds = tasmota.time_dump(rtc['local'])['sec']
        var seconds_brightness = self.clockfaceManager.brightness >> 1
        
        if current_seconds >= 12
            self.matrixController.set_matrix_pixel_color(0, 0, self.clockfaceManager.color, seconds_brightness)
        else
            self.matrixController.set_matrix_pixel_color(0, 0, 0x000000, self.clockfaceManager.brightness)
        end
        if current_seconds >= 24
            self.matrixController.set_matrix_pixel_color(31, 0, self.clockfaceManager.color, seconds_brightness)
        else
            self.matrixController.set_matrix_pixel_color(31, 0, 0x000000, self.clockfaceManager.brightness)
        end
        if current_seconds >= 36
            self.matrixController.set_matrix_pixel_color(31, 7, self.clockfaceManager.color, seconds_brightness)
        else
            self.matrixController.set_matrix_pixel_color(31, 7, 0x000000, self.clockfaceManager.brightness)
        end
        if current_seconds >= 48
            self.matrixController.set_matrix_pixel_color(0, 7, self.clockfaceManager.color, seconds_brightness)
        else
            self.matrixController.set_matrix_pixel_color(0, 7, 0x000000, self.clockfaceManager.brightness)
        end
    end
    
end

return BasicClockFace