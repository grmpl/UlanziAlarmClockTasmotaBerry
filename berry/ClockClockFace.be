import BaseClockFace
import IconHandler
import string
import persist
import mqtt

class ClockClockFace: BaseClockFace

    var weather
    var shutter
    var iconHandlerL
    var iconHandlerR
    var shuttericonclose
    var shuttericonopen
    var shutterMove


    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        # will be called in render
        # self.matrixController.clear()
        self.weather = self.clockfaceManager.weather
        self.shutter = false
        self.shuttericonclose = "shutterclose.miff"
        self.shuttericonopen = "shutteropen.miff"
        self.shutterMove = false
    end

    def close()
        # Usually clockface will only be ended on main clockface with prev/next button
        #   But clockface could end in subface mode, too, for example when energysaveClockface is started
        #   so Iconhandler musst be cleaned up with close-method
        if self.iconHandlerL != nil
            self.iconHandlerL.stopiconlist()
            self.iconHandlerL = nil
        end
        if self.iconHandlerR != nil
            self.iconHandlerR.stopiconlist()
            self.iconHandlerR = nil
        end
    end
    
    def handleActionButton(value)
        var so13 = tasmota.get_option(13)
        log("handleActionButton: value="+str(value)+" so13="+str(so13)+" shutter:"+str(self.shutter),2)
        if ( so13 == 1 && value == 15 ) || (so13 == 0) # for setoption13=1 react on clear only, otherwise there will be only one button action
            self.shutter = !self.shutter
            # if button was pressed on normal face, stopp shutter and initialize IconHandler
            if self.shutter
                mqtt.publish("cmnd/rollschlaf/shutterstop","") # stop any shutter movement
                self.shutterMove = false # and remember that shutter has stopped
                self.iconHandlerL = IconHandler() # get an iconhandler for drawing left icon
                self.iconHandlerR = IconHandler() # get an iconhandler for drawing right icon
                self.clockfaceManager.subfaceshown = true # will redirect prev and next button to this clockface
            else
                self.clockfaceManager.subfaceshown = false
                self.iconHandlerL.stopiconlist()
                self.iconHandlerR.stopiconlist()
                self.matrixController.clear(true) # must clear foreground, as this will not be done by render
                self.iconHandlerL = nil
                self.iconHandlerR = nil
            end
        end
    end

    def handleEditPrev(value)
        # should only be called when alarmedit is true
        # action depends on setoption13
        var so13 = tasmota.get_option(13)
        log("handleEditPrev: value="+str(value)+" so13="+str(so13),2)
        if ( so13 == 1 && value == 15 ) || (so13 == 0) # for setoption13=1 react on clear only
            # if shutter is moving, stop it, if it is stopped, open it
            if self.shutterMove
                mqtt.publish("cmnd/rollschlaf/shutterstop","") # open shutter on button press
                self.shutterMove = false
            else
                mqtt.publish("cmnd/rollschlaf/shutterclose","") # open shutter on button press
                self.shutterMove = true
            end
        end

    end

    def handleEditNext(value)
        # should only be called when alarmedit is true
        # action depends on setoption13
        var so13 = tasmota.get_option(13)
        log("handleEditNext: value="+str(value)+" so13="+str(so13),2)
        if ( so13 == 1 && value == 15 ) || (so13 == 0) # for setoption13=1 react on clear only
            # if shutter is moving, stop it, if it is stopped, close it
            if self.shutterMove
                mqtt.publish("cmnd/rollschlaf/shutterstop","") # close shutter on button press
                self.shutterMove = false
            else
                mqtt.publish("cmnd/rollschlaf/shutteropen","") # close shutter on button press
                self.shutterMove = true
            end
        end
    end

    def render()
        self.matrixController.clear()
        if self.shutter
             self.renderShutter()
        else
             self.renderClock()
        end
    end

    def renderShutter()
        if !self.iconHandlerL.IconlistRunning 
            self.iconHandlerL.stopiconlist()
            self.iconHandlerL.starticonlist([self.shuttericonclose],0,0,40,self.clockfaceManager) 
        end
        if !self.iconHandlerR.IconlistRunning 
            self.iconHandlerR.stopiconlist()
            self.iconHandlerR.starticonlist([self.shuttericonopen],24,0,40,self.clockfaceManager) 
        end
        #self.matrixController.change_font('MatrixDisplay3x5')
        #self.matrixController.print_string("SHUTTER", 11, 0, false, self.clockfaceManager.color, self.clockfaceManager.brightness)
    end

    def renderClock()
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
               
        # Reduced to 3 alarm times for i:1..4
        for i:1..3
            var timerstr = "Timer"+str(i)
            var timeract = tasmota.cmd("_"+timerstr,true)[timerstr]['Enable']
            
            if persist.member('snooze') == 1 && ((self.clockfaceManager.snoozerunning*3/self.clockfaceManager.snoozetime)+1 >= i)
                self.matrixController.set_matrix_pixel_color(28+i, 0, 0x0000ff, self.clockfaceManager.brightness)
            elif persist.member('alarmactive') == i
                #Alarm active
                self.matrixController.set_matrix_pixel_color(28+i, 0, 0xffff00, self.clockfaceManager.brightness)
            elif
                timeract == 0
                self.matrixController.set_matrix_pixel_color(28+i, 0, 0xff0000, self.clockfaceManager.brightness)
            elif timeract == 1
                self.matrixController.set_matrix_pixel_color(28+i, 0, 0x00ff00, self.clockfaceManager.brightness)
            else
                self.matrixController.set_matrix_pixel_color(28+i, 0, 0x000000, self.clockfaceManager.brightness)
            end
        end
  
        
    end

end

return ClockClockFace
