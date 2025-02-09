import BaseClockFace
import persist
import string

class AlarmClockFaceBase: BaseClockFace
    var timerstr
    var timerrepeat
    var alarmstatus #possible values: 16=undefined, 0=alarm inactive, 1=alarm active, 2=alarm running, 4=snooze active
    var EditField
    var EditHour
    var EditMinute
    var EditRepeat
    


    static alarmnumber = 0
    static timexoffset = 8
    static timeyoffset = 1


    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.EditField=0
        self.EditMinute=99
        self.EditHour=99
        self.EditRepeat=99

                
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

    def handleActionButton(value)
        if value != 3 && !self.clockfaceManager.alarmedit
            var enable = tasmota.cmd("_"+self.timerstr,true)[self.timerstr]['Enable']
            self.alarmstatus=self.alarmstatus ^ 1
            tasmota.cmd("_"+self.timerstr+" {\"Enable\":" + str((self.alarmstatus & 1)) + "}",true)
            log("AlarmClockFace: Set timer inactive",2)
            self.clockfaceManager.update_brightness_from_sensor()
            self.clockfaceManager.redraw()
        elif value != 3
            self.EditField = (self.EditField + 1) % 3
            self.clockfaceManager.redraw()

        elif self.clockfaceManager.alarmedit # long press ends editing
            tasmota.cmd("_"+self.timerstr+" {\"Repeat\":" + str(self.EditRepeat) + "}",true)
            tasmota.cmd("_"+self.timerstr+" {\"Time\":\"" + format("%02i:%02i",self.EditHour, self.EditMinute) + "\"}",true)
            self.clockfaceManager.alarmHandler.buzzer_alarmoff(1,50,100,2)
            self.clockfaceManager.alarmedit = false
            self.clockfaceManager.redraw()
        else # long press starts editing
            self.clockfaceManager.alarmHandler.buzzer_alarmoff(1,50,100,2)
            self.clockfaceManager.alarmedit = true
            self.EditField=0
            self.EditHour=99
            self.EditMinute=99
            self.EditRepeat=99
            self.clockfaceManager.redraw()
        end
        
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


        if !self.clockfaceManager.alarmedit 
            self.matrixController.print_string(timerstatus['Time'], self.timexoffset, self.timeyoffset, false, self.clockfaceManager.color, self.clockfaceManager.brightness)
        else # handle alarmedit
            var timelist = string.split(timerstatus['Time'],':')
            if self.EditHour > 23 #not initialized yet
                self.EditHour = number(timelist[0])
            end
            if self.EditMinute > 59
                self.EditMinute = number(timelist[1])
            end
            if self.EditField == 0
                self.matrixController.print_string(format("%02i",self.EditHour), self.timexoffset, self.timeyoffset, false, (self.clockfaceManager.color ^ 0x00ffffff ), self.clockfaceManager.brightness)
                self.matrixController.print_string(':', self.timexoffset+10, self.timeyoffset, false, self.clockfaceManager.color , self.clockfaceManager.brightness)
                self.matrixController.print_string(format("%02i",self.EditMinute), self.timexoffset+15, self.timeyoffset, false, self.clockfaceManager.color , self.clockfaceManager.brightness)
            elif self.EditField == 1
                self.matrixController.print_string(format("%02i",self.EditHour),self.timexoffset, self.timeyoffset, false, self.clockfaceManager.color, self.clockfaceManager.brightness)
                self.matrixController.print_string(':', self.timexoffset+10, self.timeyoffset, false, self.clockfaceManager.color , self.clockfaceManager.brightness)
                self.matrixController.print_string(format("%02i",self.EditMinute), self.timexoffset+15, self.timeyoffset, false, (self.clockfaceManager.color ^ 0x00ffffff ), self.clockfaceManager.brightness)
            else
                self.matrixController.print_string(format("%02i",self.EditHour),self.timexoffset, self.timeyoffset, false, self.clockfaceManager.color, self.clockfaceManager.brightness)
                self.matrixController.print_string(':', self.timexoffset+10, self.timeyoffset, false, self.clockfaceManager.color , self.clockfaceManager.brightness)
                self.matrixController.print_string(format("%02i",self.EditMinute), self.timexoffset+15, self.timeyoffset, false, self.clockfaceManager.color , self.clockfaceManager.brightness)
            end




        end

        
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
        self.drawicon(clockicon,0,0,10)

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
            self.drawicon(snoozeicon,1,0,10)
        elif self.alarmstatus & 2
            log("AlarmClockFace: Draw alarm",4)
            #self.draw_alarm()
            var alarmcolor=0xffff00
            var alarmicon=[
                           [alarmcolor,nil,alarmcolor,nil,alarmcolor,nil,alarmcolor],
                           [nil,alarmcolor,nil,alarmcolor,nil,nil,alarmcolor]
                          ]
            self.drawicon(alarmicon,0,0,10)
        end

        var repeatdisplay
        var repcolor = 0xffbd3e

        if self.clockfaceManager.alarmedit
            if self.EditRepeat > 1 
                self.EditRepeat = self.timerrepeat
            end
            repeatdisplay = self.EditRepeat
            if self.EditField == 2
                repcolor = repcolor ^ 0x00ffffff
            end
        else
            repeatdisplay = self.timerrepeat
        end

        if repeatdisplay == 0
            log("AlarmClockFace: Draw norepeat",4)
            var repicon=[
                        [repcolor],
                        [repcolor],
                        [repcolor]
                        ]
            self.drawicon(repicon,6,5,10)
        elif repeatdisplay == 1
            log("AlarmClockFace: Draw repeat",4)
            var repicon=[
                         [nil,repcolor,nil],
                         [repcolor,nil,repcolor],
                         [nil,repcolor,nil]
                         ]
            self.drawicon(repicon,5,5,10)
        end
    end

    def handleEditPrev()
        if self.EditField == 0
            self.EditHour = (self.EditHour - 1)
            if self.EditHour == -1
                self.EditHour = 23
            end
            # Redraw only hour
            for i:self.timexoffset..self.timexoffset+9
                for j:self.timeyoffset..self.timeyoffset+6
                    self.matrixController.set_matrix_pixel_color(i,j,0,0)
                end
            end
            self.matrixController.print_string(format("%02i",self.EditHour), self.timexoffset, self.timeyoffset, false, (self.clockfaceManager.color ^ 0x00ffffff ), self.clockfaceManager.brightness)
            self.matrixController.draw()
 
        elif self.EditField == 1
            self.EditMinute = (self.EditMinute - 1)
            if self.EditMinute == -1
                self.EditMinute = 59
            end
            # Redraw only minute
            for i:self.timexoffset+15..self.timexoffset+24
                for j:self.timeyoffset..self.timeyoffset+6
                    self.matrixController.set_matrix_pixel_color(i,j,0,0)
                end
            end
            self.matrixController.print_string(format("%02i",self.EditMinute), self.timexoffset+15, self.timeyoffset, false, (self.clockfaceManager.color ^ 0x00ffffff ), self.clockfaceManager.brightness)
            self.matrixController.draw()
 
        else 
            self.EditRepeat = self.EditRepeat + 1 
            if self.EditRepeat == 2
                self.EditRepeat = 0
            end
        self.clockfaceManager.redraw()
        end
        #self.clockfaceManager.redraw()
     

    end

    def handleEditNext()
        if self.EditField == 0
            self.EditHour = (self.EditHour + 1)
            if self.EditHour == 24
                self.EditHour = 0
            end
            # Redraw only hour
            for i:self.timexoffset..self.timexoffset+9
                for j:self.timeyoffset..self.timeyoffset+6
                    self.matrixController.set_matrix_pixel_color(i,j,0,0)
                end
            end
            self.matrixController.print_string(format("%02i",self.EditHour), self.timexoffset, self.timeyoffset, false, (self.clockfaceManager.color ^ 0x00ffffff ), self.clockfaceManager.brightness)
            self.matrixController.draw()
        
        elif self.EditField == 1
            self.EditMinute = (self.EditMinute + 1)
            if self.EditMinute == 60
                self.EditMinute = 0
            end
            # Redraw only minute
            for i:self.timexoffset+15..self.timexoffset+24
                for j:self.timeyoffset..self.timeyoffset+6
                    self.matrixController.set_matrix_pixel_color(i,j,0,0)
                end
            end
            self.matrixController.print_string(format("%02i",self.EditMinute), self.timexoffset+15, self.timeyoffset, false, (self.clockfaceManager.color ^ 0x00ffffff ), self.clockfaceManager.brightness)
            self.matrixController.draw()
        else 
            self.EditRepeat = self.EditRepeat + 1 
            if self.EditRepeat == 2
                self.EditRepeat = 0
            end
        end
        self.clockfaceManager.redraw()
    end


end

return AlarmClockFaceBase