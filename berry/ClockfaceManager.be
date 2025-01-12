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
import Alarm1ClockFace
import Alarm2ClockFace
import Alarm3ClockFace
import Alarm4ClockFace



var clockFaces = [
    ClockClockFace,
    DateClockFace,
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
    var snoozerunning

    static snoozetime=300 # 5 minutes


    def init()
        log("ClockfaceManager Init",3);
        self.matrixController = MatrixController()
        self.alarmHandler = AlarmHandler()

        self.brightness = 50;
        self.color = fonts.palette['red']

        self.matrixController.print_string("Hello :)", 3, 2, true, self.color, self.brightness)
        self.matrixController.draw()

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
            self.alarmHandler.StopBuzzer() 
            persist.alarmactive=0
            persist.save()
            log("ClockfaceManager: Alarm switched off by Web-Button",2) 
        end
    end


    # React on Button action
    # Button-action: 10=Single, 11=Double, 12=Triple, 3=Hold, 15:Clean (Release)

    def on_button_prev(value, trigger, msg)
        # print(value)
        # print(trigger)
        # print(msg)
        # If Alarm is active and no Snooze, activate Snooze, do nothing
        if persist.member('alarmactive') > 0 && persist.member('snooze') == 0
            log("Snooze activated by button_prev",2)
            self.activateSnooze()
            #self.redraw() # it's ok to wait for the next redraw
        else

            self.currentClockFaceIdx = (self.currentClockFaceIdx + (size(clockFaces) - 1)) % size(clockFaces)
            self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)

            #self.redraw()
        end
    end

    def on_button_action(value, trigger, msg)
               
        # If Alarm is active handle button different
        var alarmset = persist.member('alarmactive')
        if alarmset > 0 && value == 3 #Hold will switch off Alarm on all faces
            log("ClockfaceManager: Alarm switched off",2)
            self.alarmHandler.StopBuzzerWithBeep()
            persist.alarmactive=0
            #self.redraw()
        elif value == 15 # Clear (release of Hold) will never be handled! 
            # do nothing, otherwise we would have to check if it was an hold because alarm was active, or it was a regular hold
        elif  alarmset > 0 && persist.member('snooze') == 0 #if Alarm on, always do Snooze on
            log("ClockfaceManager: Snooze activated by button_action",2)
            self.activateSnooze()
            #self.redraw() # it's ok to wait for the next redraw
        else
            var handleActionMethod = introspect.get(self.currentClockFace, "handleActionButton");
            if handleActionMethod != nil
                self.currentClockFace.handleActionButton()
            end
        end
    end

    def on_button_next(value, trigger, msg)
        # print(value)
        # print(trigger)
        # print(msg)
        # If Alarm is active and no Snooze, activate Snooze
        if persist.member('alarmactive') > 0 && persist.member('snooze') == 0
            log("ClockfaceManager: Snooze activated by button_next",2)
            self.activateSnooze()
            #self.redraw() # it's ok to wait for the next redraw
        else
            self.currentClockFaceIdx = (self.currentClockFaceIdx + 1) % size(clockFaces)
            self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)

            self.redraw()
        end
    end


    # This will be called automatically every 1s by the tasmota framework
    def every_second()


        # First do the redraw, then check for Alarm, as Alarm-buzzing is very time-critical
        self.update_brightness_from_sensor()
        self.redraw()

        # Check for Alarm
        var alarmset = persist.member('alarmactive')
        # Alarm set and no Snooze, 
        if alarmset > 0 && persist.member('snooze') == 0 
            log("ClockfaceManager: Alarm active, beeping",3)
            self.alarmHandler.Beep() # Beeping will be done in second-intervals, as the redraw every second will disturb the timing of beeping
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
                self.alarmHandler.beepindex = 0
            end
        # Alarm off, but still Snooze active
        elif alarmset == 0 && persist.member('snooze') > 0
            log("ClockfaceManager: Alarm off, but Snooze still on",3)
            persist.snooze = 0
            self.snoozerunning = 0
            persist.save()
        end



    end

    def activateSnooze()
        persist.snooze=1
        persist.save()
        self.snoozerunning = self.snoozetime
        self.alarmHandler.StopBuzzer()
        self.alarmHandler.beepindex = 0
    end    
    
    # This will redraw current face
    def redraw()
        #var start = tasmota.millis()

        self.currentClockFace.render() # Dauert 200msec auf der Hauptseite, 100msec auf der Datumseite, 90msec auf der einfachen Datumseite, 110msec auf der Alarmseite - muss optimiert werden
        self.matrixController.draw()

        #print("Redraw took", tasmota.millis() - start, "ms")
    end

    # For updating brightness
    def update_brightness_from_sensor()
        var sensors = json.load(tasmota.read_sensors()) # kostet 50msec! - auf init verlagern
        var illuminance = sensors['ANALOG']['Illuminance1']

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
