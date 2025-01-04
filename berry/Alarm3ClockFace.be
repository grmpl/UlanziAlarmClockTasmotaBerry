import BaseClockFace
import persist

class Alarm3ClockFace: BaseClockFace
    var timerstr
    var alarmstatus #possible values: 16=undefined, 0=alarm inactive, 1=alarm active, 2=alarm running, 4=snooze active

    static alarmnumber = 3


    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
                
        self.timerstr = "Timer" + str(self.alarmnumber)
        # Check if timer is active
        var timerstatus = tasmota.cmd("_"+self.timerstr,true)[self.timerstr]['Enable']


        # Init set the bits correctly
        if persist.member('snooze') == 1
            self.alarmstatus = 4
        else
            self.alarmstatus = 0
        end

        if persist.member('alarmactive') == self.alarmnumber
            self.alarmstatus = self.alarmstatus | 2
        else 
            self.alarmstatus = self.alarmstatus & 13
        end
        
        if timerstatus == 1
            self.alarmstatus = self.alarmstatus | 1
        elif timerstatus == 0
            self.alarmstatus = self.alarmstatus & 14
        else 
            self.alarmstatus = self.alarmstatus | 8
        end

    end

    def handleActionButton()
        var enable = tasmota.cmd("_"+self.timerstr,true)[self.timerstr]['Enable']
        self.alarmstatus=self.alarmstatus ^ 1
        tasmota.cmd("_"+self.timerstr+" {\"Enable\":" + str((self.alarmstatus & 1)) + "}",true)
        log("AlarmClockFace: Set timer inactive",2)
        self.clockfaceManager.update_brightness_from_sensor()
        self.clockfaceManager.redraw()
    end

    def render()
        self.matrixController.clear()
        self.matrixController.change_font('Glance')

        var timerstatus = tasmota.cmd("_"+self.timerstr,true)[self.timerstr]

        if persist.member('snooze') == 1
            self.alarmstatus = self.alarmstatus | 4
        else
            self.alarmstatus = self.alarmstatus & 11 
        end

        if persist.member('alarmactive') == self.alarmnumber
            self.alarmstatus = self.alarmstatus | 2
        else 
            self.alarmstatus = self.alarmstatus & 13
        end
        
        if timerstatus['Enable'] == 1
            self.alarmstatus = self.alarmstatus | 1
        elif timerstatus['Enable'] == 0
            self.alarmstatus = self.alarmstatus & 14
        else 
            self.alarmstatus = self.alarmstatus | 8
        end


        var x_offset=8
        var y_offset=1
        
        self.matrixController.print_string(timerstatus['Time'], x_offset, y_offset, false, self.clockfaceManager.color, self.clockfaceManager.brightness)
        # Draw indicator which timer we see
        for i:1..4
            var icolor=self.clockfaceManager.color
            if i==self.alarmnumber
                icolor=icolor ^ 0xffffff
            end

            self.matrixController.set_matrix_pixel_color(17+i, 0, icolor,self.clockfaceManager.brightness)
        end

        
        
        log("AlarmClockFace: Draw clock",4)
        self.draw_clock()

        if self.alarmstatus & 4
            log("AlarmClockFace: Draw snooze",4)
            self.draw_snooze()
        elif self.alarmstatus & 2
            log("AlarmClockFace: Draw alarm",4)
            self.draw_alarm()
        end

        

    end

    def draw_clock()
        var x_offset=0
        var y_offset=1
        var clockcolor

        if self.alarmstatus & 1
            clockcolor=0x00ff00
        else
            clockcolor=0xff0000
        end
        

        self.matrixController.set_matrix_pixel_color(x_offset+2, y_offset, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+4, y_offset, clockcolor,self.clockfaceManager.brightness)

        self.matrixController.set_matrix_pixel_color(x_offset+1, y_offset+1, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset+1, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+5, y_offset+1, clockcolor,self.clockfaceManager.brightness)

        self.matrixController.set_matrix_pixel_color(x_offset, y_offset+2, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset+2, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+6, y_offset+2, clockcolor,self.clockfaceManager.brightness)

        self.matrixController.set_matrix_pixel_color(x_offset, y_offset+3, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset+3, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+4, y_offset+3, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+5, y_offset+3, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+6, y_offset+3, clockcolor,self.clockfaceManager.brightness)

        self.matrixController.set_matrix_pixel_color(x_offset, y_offset+4, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+6, y_offset+4, clockcolor,self.clockfaceManager.brightness)
        
        self.matrixController.set_matrix_pixel_color(x_offset+1, y_offset+5, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+5, y_offset+5, clockcolor,self.clockfaceManager.brightness)

        self.matrixController.set_matrix_pixel_color(x_offset+2, y_offset+6, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset+6, clockcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+4, y_offset+6, clockcolor,self.clockfaceManager.brightness)

    end

    def draw_alarm()
        var x_offset=0
        var y_offset=0
        var alarmcolor = 0xffff00
        self.matrixController.set_matrix_pixel_color(x_offset, y_offset, alarmcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+1, y_offset+1, alarmcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+2, y_offset+0, alarmcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset+1, alarmcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+4, y_offset+0, alarmcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+6, y_offset+1, alarmcolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+7, y_offset+0, alarmcolor,self.clockfaceManager.brightness)

    end

    def draw_snooze()
        var x_offset=1
        var y_offset=0
        var snoozecolor = 0x0000ff
        self.matrixController.set_matrix_pixel_color(x_offset, y_offset, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+1, y_offset, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+2, y_offset, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset+1, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+2, y_offset+2, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+1, y_offset+3, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset, y_offset+4, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+1, y_offset+4, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+2, y_offset+4, snoozecolor,self.clockfaceManager.brightness)
        self.matrixController.set_matrix_pixel_color(x_offset+3, y_offset+4, snoozecolor,self.clockfaceManager.brightness)
    end
    
end

return Alarm3ClockFace