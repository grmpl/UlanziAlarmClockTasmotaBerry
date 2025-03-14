import BaseClockFace
import string
import persist

class ClockClockFace: BaseClockFace

    var weather

    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        # will be called in render
        # self.matrixController.clear()
        self.weather = self.clockfaceManager.weather
    end

    def render()
        self.matrixController.clear()
        var rtc = tasmota.rtc()

        var hour_str = tasmota.strftime('%H', rtc['local'])
        var minute_str = tasmota.strftime('%M', rtc['local'])
        var y_offset = 1
        var hx_offset = 0
        var mx_offset = hx_offset+12
        
        var temp
        var temp_neg
        var temp_str
        var temp_color=0x0000ff
        #var temp_color=0xff00a0
        var tx_offset = 25
        var ty_offset = 3
        var tmx_offset
        var weatherresult = self.weather.get_weather()
        if nil == weatherresult
            temp = 99
            temp_str="--"
        else
            #I need a right sided temperature value and a - sign with width 2,
            # otherwise it wouldn't fit. Changing font and using collapse is not
            # an option, as + could not be done in 2 pixels and blank will be collapsed, too.
            # So I have to draw the - sign directly.
            temp = weatherresult['temperature']
            if temp == nil
                temp = 99
            elif temp < 0
                temp = temp * -1
                temp_neg = true
            end

            temp_str = string.format("%2.0f",temp)
        end
                
        # Display Time
        self.matrixController.change_font('Glance');
        self.matrixController.print_string(hour_str, hx_offset, y_offset, false, self.clockfaceManager.color, self.clockfaceManager.brightness)
        self.matrixController.print_string(minute_str, mx_offset, y_offset, false, self.clockfaceManager.color, self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(mx_offset-2, 2, self.clockfaceManager.color, self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(mx_offset-2, 6, self.clockfaceManager.color, self.clockfaceManager.brightness)


        # Display temperature
        self.matrixController.change_font('MatrixDisplay3x5')
        self.matrixController.print_string(temp_str,tx_offset,ty_offset, false, temp_color, self.clockfaceManager.brightness)
        
        if temp < 9.5
            tmx_offset=tx_offset+1
        else 
            tmx_offset=tx_offset-3
        end

        if temp_neg 
            self.matrixController.set_matrix_pixel_color(tmx_offset, ty_offset+2, temp_color, self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(tmx_offset+1, ty_offset+2, temp_color, self.clockfaceManager.brightness)
        end

        # Display alarm
               
        for i:1..4
            var timerstr = "Timer"+str(i)
            var timeract = tasmota.cmd("_"+timerstr,true)[timerstr]['Enable']
            
            if persist.member('snooze') == 1 && ((self.clockfaceManager.snoozerunning*4/self.clockfaceManager.snoozetime)+1 >= i)
                self.matrixController.set_matrix_pixel_color(27+i, 0, 0x0000ff, self.clockfaceManager.brightness)
            elif persist.member('alarmactive') == i
                #Alarm active
                self.matrixController.set_matrix_pixel_color(27+i, 0, 0xffff00, self.clockfaceManager.brightness)
            elif
                timeract == 0
                self.matrixController.set_matrix_pixel_color(27+i, 0, 0xff0000, self.clockfaceManager.brightness)
            elif timeract == 1
                self.matrixController.set_matrix_pixel_color(27+i, 0, 0x00ff00, self.clockfaceManager.brightness)
            else
                self.matrixController.set_matrix_pixel_color(27+i, 0, 0x000000, self.clockfaceManager.brightness)
            end
        end
  
        
    end

end

return ClockClockFace
