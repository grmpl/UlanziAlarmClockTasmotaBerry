import BaseClockFace
import persist

class AlarmClockFaceBase: BaseClockFace
    var timerstr
    var timerrepeat
    var alarmstatus #possible values: 16=undefined, 0=alarm inactive, 1=alarm active, 2=alarm running, 4=snooze active


    static alarmnumber = 0


    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
                
        self.timerstr = "Timer" + str(self.alarmnumber)
        # Check if timer is active
        var timerstatus = tasmota.cmd("_"+self.timerstr,true)[self.timerstr]
        self.timerrepeat= timerstatus['Repeat']


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
        
        if timerstatus['Enable'] == 1
            self.alarmstatus = self.alarmstatus | 1
        elif timerstatus['Enable'] == 0
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
        self.timerrepeat= timerstatus['Repeat']

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
        #self.draw_clock()
        var clockicon
        var clockcolor
        var clockbackgroundcolor
        if self.alarmstatus & 1
            clockcolor=0x00ff00
        else
            clockcolor=0xff0000
        end
        clockbackgroundcolor=0xffffff
        clockicon = [
                     [nil,nil,clockcolor,clockcolor,clockcolor,nil,nil],
                     [nil,clockcolor,clockbackgroundcolor,clockcolor,clockbackgroundcolor,clockcolor,nil],
                     [clockcolor,clockbackgroundcolor,clockbackgroundcolor,clockcolor,clockbackgroundcolor,clockbackgroundcolor,clockcolor],
                     [clockcolor,clockbackgroundcolor,clockbackgroundcolor,clockcolor,clockcolor,clockcolor,clockcolor],
                     [clockcolor,clockbackgroundcolor,clockbackgroundcolor,clockbackgroundcolor,clockbackgroundcolor,clockbackgroundcolor,clockcolor],
                     [nil,clockcolor,clockbackgroundcolor,clockbackgroundcolor,clockbackgroundcolor,clockcolor,nil],
                     [nil,nil,clockcolor,clockcolor,clockcolor,nil,nil]
                    ]
        self.drawicon(clockicon,0,0)

        if self.alarmstatus & 4
            log("AlarmClockFace: Draw snooze",4)
            # self.draw_snooze()
            var snoozecolor=0x0000ff
            var snoozeicon=[
                        [snoozecolor,snoozecolor,snoozecolor,snoozecolor],
                        [nil,nil,snoozecolor,nil],
                        [nil,snoozecolor,nil,nil],
                        [snoozecolor,snoozecolor,snoozecolor,snoozecolor]
                       ]
            self.drawicon(snoozeicon,1,0)
        elif self.alarmstatus & 2
            log("AlarmClockFace: Draw alarm",4)
            #self.draw_alarm()
            var alarmcolor=0xffff00
            var alarmicon=[
                           [alarmcolor,nil,alarmcolor,nil,alarmcolor,nil,alarmcolor],
                           [nil,alarmcolor,nil,alarmcolor,nil,nil,alarmcolor]
                          ]
            self.drawicon(alarmicon,0,0)
        end

        if self.timerrepeat == 0
            log("AlarmClockFace: Draw norepeat",4)
            var repcolor=0xffbd3e
            var repicon=[
                         [repcolor],
                         [repcolor],
                         [repcolor]
                         ]
            self.drawicon(repicon,6,5)
        elif self.timerrepeat == 1
            log("AlarmClockFace: Draw repeat",4)
            var repcolor=0xffbd3e
            var repicon=[
                         [nil,repcolor,nil],
                         [repcolor,nil,repcolor],
                         [nil,repcolor,nil]
                         ]
            self.drawicon(repicon,5,5)
        end



        

    end

end

return AlarmClockFaceBase