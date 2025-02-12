import fonts
import json
import math
import introspect
import persist
import webserver

import MatrixController
import AlarmHandler

import ClockClockFace
import DateClockFace
#import IconClockFace
import WeatherClockFace
import Alarm1ClockFace
import Alarm2ClockFace
import Alarm3ClockFace
import Alarm4ClockFace
import EnergysaveClockFace



var clockFaces = [
    ClockClockFace,
    DateClockFace,
#    IconClockFace,
    WeatherClockFace, 
    Alarm1ClockFace,
    Alarm2ClockFace,
    Alarm3ClockFace,
    Alarm4ClockFace
];

class ClockfaceManager
    var matrixController
    var alarmHandler
    var brightness
    var color
    var currentClockFace
    var currentClockFaceIdx
    var snoozerunning # indicates snooze being active for indication on all faces
    var alarmedit # indicates edit-mode on alarm faces to redirect button actions
    var lastredraw # introduced to avoid unnecessary redraws in short time
    var buttonholddone # necessary to ignore clear-values of button after hold-action was done
    var energysaveoverride # override energy saving mode with button action
    var debounceulowerbrightness
    var debounceuenergysaveface

    static snoozetime=360 # 6 minutes
    static buttonholdtimerID="buttonhold"


    def init()
        log("ClockfaceManager Init",3);
        self.matrixController = MatrixController()
        self.alarmHandler = AlarmHandler()
        self.lastredraw=0
        self.buttonholddone=false
        self.energysaveoverride=tasmota.millis()
        self.debounceuenergysaveface = 0
        self.debounceulowerbrightness = 0

        self.brightness = 50;
        self.color = fonts.palette['red']

        self.matrixController.print_string("Hello :)", 3, 2, true, self.color, self.brightness)
        self.matrixController.draw()

        self.alarmedit = false

        self.currentClockFaceIdx = 0
        self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)

        tasmota.add_rule("Button1#State", / value, trigger, msg -> self.on_button_prev(value, trigger, msg))
        tasmota.add_rule("Button2#State", / value, trigger, msg -> self.on_button_action(value, trigger, msg))
        tasmota.add_rule("Button3#State", / value, trigger, msg -> self.on_button_next(value, trigger, msg))

        # Reset Snooze after reinit
        self.snoozerunning = 0
        persist.snooze = 0


        # Check for AlarmActive and initialize if necessary
        if persist.member('alarmactive') == nil
            persist.alarmactive = 0
        end
        persist.save()


        
        # And create a custom Tasmota-Command
        tasmota.add_cmd("AlarmActivate",/ccmd cidx cpayload cpayload_json -> self.cmdAlarmActivate(ccmd,cidx,cpayload,cpayload_json))
        
         
    end

    # Define a custom command
    def cmdAlarmActivate(cmd,idx,payload,payload_json)
        # persist Alarmnumber 
        var num=int(payload)
        persist.alarmactive=num
        persist.save()
        if persist.member("alarmactive") == num
            tasmota.resp_cmnd("{\"alarmactive\":" + str(num) + "}" )
        else
            log("cmdAlarmActivate: Could not save persist.alarmactive with value " + str(num),1)
            tasmota.resp_cmnd_failed()
        end
    end

    # Define a new Web-Button
    def web_add_main_button()
        webserver.content_send("<p></p><button onclick='la(\"&alarmoff=1\");'>Alarm Off</button>")
    end

    # And react on Web-Button-Click
    def web_sensor()
       #print(webserver.arg_size(), webserver.arg_name(0),webserver.arg(0),webserver.arg_name(1),webserver.arg(1),webserver.arg_name(2),webserver.arg(2))
        if webserver.has_arg("alarmoff")
           persist.alarmactive=0
           self.alarmHandler.buzzer_alarmoff(1,50,100,2)
           persist.save()
           log("ClockfaceManager: Alarm switched off by Web-Button",2) 
        end
    end


    # React on Button action, 
    # Button-action if setoption13=0: 10=Single, 11=Double, 12=Triple, 3=Hold, 15:Clear (Release)
    # Button-action if setoption13=1: 10=Single, 15:Clean (Release)

    def on_button_prev(value, trigger, msg)
        self.energysaveoverride=tasmota.millis()
        # If Alarm is active and no Snooze, activate Snooze, do nothing
        var so13 = tasmota.get_option(13)
        if persist.member('alarmactive') > 0 && persist.member('snooze') == 0
            log("Snooze activated by button_prev",2)
            self.alarmHandler.buzzer_alarmoff(1,50,100,2)
            persist.snooze=1
            persist.save()
            self.snoozerunning = self.snoozetime
            self.redraw()
        elif self.alarmedit && ( introspect.get(self.currentClockFace, "handleEditPrev") != nil ) # during alarmedit handling is done by AlarmClockface
                self.currentClockFace.handleEditPrev(value)
        elif ( so13 == 1 && value == 10 ) || (so13 == 0 && value > 9) # with setoption13=1 use only single-action, not clear-action, with setoption13=0 use clear after hold and all other actions
            self.currentClockFaceIdx = (self.currentClockFaceIdx + (size(clockFaces) - 1)) % size(clockFaces)
            self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)
            self.redraw()
        # else ignore Clean with setoption13=1, ignore Hold with setoption13=0
        end
    end

    def on_button_action(value, trigger, msg)
        self.energysaveoverride=tasmota.millis()
        # if energysaveClockface active, reactivate current clockface
        if classof(self.currentClockFace) == EnergysaveClockFace
            self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)
            self.redraw()
        end
               
        # If Alarm is active handle button different
        var alarmset = persist.member('alarmactive')
        var so13 = tasmota.get_option(13)
        var holdtime = ( tasmota.get_option(32) * 100 ) # setoption32 defines hold time in factors of 100msec
        if self.buttonholddone && value == 15 # Clear after action for hold is completely ignored.
            self.buttonholddone=false
        elif ( alarmset > 0 ) && ( ( so13 == 0 ) && ( value == 3 ) ) #with setoption13=0 react on hold if alarm is active
            log("ClockfaceManager: Alarm switched off by button",2)
            self.stopalarm()
        elif ( alarmset > 0 ) && ( so13 == 1 ) && ( value  == 10 ) # with setoption13=1 every single-action will trigger hold function in future
            tasmota.set_timer(holdtime,/->self.stopalarm(),self.buttonholdtimerID)
        elif ( alarmset > 0 ) && ( persist.member('snooze') == 0 ) #if alarm active and no snooze yet, every other action will activate snooze, this includes clear with setoption13=1 if hold-action was not performed yet
            log("ClockfaceManager: Snooze activated by button_action",2)
            if so13 == 1 #Remove holdtimer if it is still set (i.e. if hold time was not reached); there is no possibility to check for timer
                tasmota.remove_timer(self.buttonholdtimerID)
            end
            self.alarmHandler.buzzer_alarmoff(1,50,100,2)
            persist.snooze=1
            persist.save()
            self.snoozerunning = self.snoozetime
            self.redraw()
        else # if no alarm is active, we hand it completely over to clockface; if alarm is running and snooze already active, it will not be completely handed over: single action will be lost with setoption13=1
            if so13 == 1 #If there is a hold timer still running, remove it before handing over to clockface
                tasmota.remove_timer(self.buttonholdtimerID)
            end
            var handleActionMethod = introspect.get(self.currentClockFace, "handleActionButton");
            if handleActionMethod != nil
                self.currentClockFace.handleActionButton(value)
            end
        end
    end

    def on_button_next(value, trigger, msg)
        self.energysaveoverride=tasmota.millis()
        # If Alarm is active and no Snooze, activate Snooze
        var so13 = tasmota.get_option(13)
        if persist.member('alarmactive') > 0 && persist.member('snooze') == 0
            log("ClockfaceManager: Snooze activated by button_next",2)
            self.alarmHandler.buzzer_alarmoff(1,50,100,2)
            persist.snooze=1
            persist.save()
            self.snoozerunning = self.snoozetime
            self.redraw()
        elif self.alarmedit && ( introspect.get(self.currentClockFace, "handleEditNext") != nil )
                self.currentClockFace.handleEditNext(value)
        elif ( so13 == 1 && value == 10 ) || (so13 == 0 && value > 9) # with setoption13=1 use only Single, with setoption13=0 use Clean on hold and all other values
            self.currentClockFaceIdx = (self.currentClockFaceIdx + 1) % size(clockFaces)
            self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)

            self.redraw()
        # else do nothing - ignore Clean with setoption13=1, ignore Hold with setoption13=0
        end
    end


    # This will be called automatically every 1s by the tasmota framework
    def every_second()
        # Check for Alarm
        var alarmset = persist.member('alarmactive')
        # Alarm set and no Snooze, 
        #  Alarmhandler must take care of buzzing tunes, we will just remind him every second to be active
        if alarmset > 0 && persist.member('snooze') == 0 
            log("ClockfaceManager: Alarm active, beeping",3)
            self.alarmHandler.alarm()
        # Alarm set and Snooze on
        elif alarmset > 0 && persist.member('snooze') > 0
            # Snooze decrement
            if self.snoozerunning > 1
                log("ClockfaceManager: Snooze active, decrementing",3)
                self.snoozerunning = self.snoozerunning - 1
            # Snooze at 1 or 0
            else
                log("ClockfaceManager: End of Snooze",3)
                persist.snooze = 0
                persist.save()
                self.snoozerunning = 0
                self.alarmHandler.BeepIndex = 0 # start from beginning
                self.alarmHandler.alarm()
            end
        # Alarm off, but still Snooze active
        elif alarmset == 0 && persist.member('snooze') > 0
            log("ClockfaceManager: Alarm off, but Snooze still on",3)
            persist.snooze = 0
            self.snoozerunning = 0
            persist.save()
        end

        if !self.alarmedit && tasmota.time_reached(self.lastredraw+500) # Only update if no alarmedit and 500msec since last redraw
            self.update_brightness_from_sensor()
            self.redraw()
        end


    end

    def stopalarm()
        self.alarmHandler.buzzer_alarmoff(1,200,100,2)
        persist.alarmactive=0 
        persist.save()
        self.redraw()
        self.buttonholddone=true
    end

    # This will redraw current face
    def redraw()

        self.currentClockFace.render()
        self.matrixController.draw()
        self.lastredraw=tasmota.millis()

    end

    # For updating brightness and setting energy saving modes
    def update_brightness_from_sensor()
        var waitoverride = 60000 # 1 Minute override after button press
        var ulowerbrightness = 2810 # voltage level to lower brightness
        var uenergysaveface = 2790 # voltage level to switch to EnergysaveClockFace
        var sensors = json.load(tasmota.read_sensors()) # takes time to read, but sensor values are always needed - either for luminance or voltage
        var illuminance = sensors['ANALOG']['Illuminance1']
        var voltage = sensors['ANALOG']['A2']
        if tasmota.time_reached( self.energysaveoverride + waitoverride ) # override over
            if voltage < uenergysaveface # display a "screensaver"-Clockface to reduce LED wearout
                self.debounceuenergysaveface += 1
                if self.debounceuenergysaveface == 10
                    self.currentClockFace=EnergysaveClockFace(self)
                    return # don't do anything more
                elif self.debounceuenergysaveface > 10
                    return
                end
            else
                self.debounceuenergysaveface = 0 # energy toggled, reset debounce-counter
            end
            if voltage < ulowerbrightness # lower brightness to save energy
                self.debounceulowerbrightness += 1
                if self.debounceuenergysaveface > 10
                    self.brightness = 10 # brightness fixed to 10
                    return # don't do anything more
                end
            else 
                self.debounceulowerbrightness = 0 # energy toggled, reset debounce-counter
            end
        end
        # will only be called if no energysaving state is reached            
        var brightness = int(10 * math.log(illuminance));
        if brightness < 10
            brightness = 10;
        end
        if brightness > 90
            brightness = 90;
        end
        # print("Brightness: ", self.brightness, ", Illuminance: ", illuminance);

        self.brightness = brightness;
    end

    # Some cleanups for gracefull shutdown
    def save_before_restart()
        # This function may be called on other occasions than just before a restart
        # => We need to make sure that it is in fact a restart
        if tasmota.global.restart_flag == 1 || tasmota.global.restart_flag == 2
            self.currentClockFace = nil;
            self.matrixController.change_font('MatrixDisplay3x5');
            self.matrixController.clear();

            self.matrixController.print_string("Reboot...", 0, 2, true, self.color, self.brightness)
            self.matrixController.draw();
            print("This is just to add some delay");
            print("   ")
            print("According to all known laws of aviation, there is no way a bee should be able to fly.")
            print("Its wings are too small to get its fat little body off the ground.")
            print("The bee, of course, flies anyway, because bees don't care what humans think is impossible")
        end
    end
end

return ClockfaceManager
