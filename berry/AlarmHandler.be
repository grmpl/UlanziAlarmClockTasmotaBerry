import persist

#- Alarmhandler must take care of:
    - Manage buzzers: If ULP-buzzer is available, it will be used, otherwise Tasmota-buzzer
    - ULP-Buzzer: Initialization and call of ULP-buzzer will only be done over Alarmhandler (single point of control)
    - Starting/Stopping buzzers
    - Keeping track of tune-list 
    - Counter of ULP-buzzer being sufficient until Alarm-End
   Interfaces:
    - Simple beep - do a simple beeping, cancelling all running beeping, tbd: What about running alarm??
    - Alarm active: If Alarm inactive - switch it on, if Alarm active, just keep it running
    - Alarm stop: Stop Alarm and set Tune-List back to start
    - Alarm pause!?: Stop Alarm, but do not set tune-list back to start
-# 
class AlarmHandler
    var beeplist # Defines the beeping sequence
    var beepindex #  controls the current beeping sequence
    var ULPBuzzeravailable
    var Sleepcalibration # ticks for 1-second sleep

    def init()
        # Try to initialize ULP-buzzer
        self.ULPBuzzeravailable=true
        try 
            import ULP
        except .. as err
            self.ULPBuzzeravailable=false
            log("Alarmhandler: Could not load ULP-module, error: "+str(err)+" - Make sure Tasmota is compiled with ULP-support",1)
        end    

        if self.ULPBuzzeravailable
            # Initialize ULP-Buzzer
            # first try to get Buzzer-GPIO
            try 
                var rtcgpio = ULP.gpio_init(gpio.pin(gpio.BUZZER),1)
            except .. as err
                self.ULPBuzzeravailable=false
                log("Alarmhandler: Can't assign GPIO to RTC, error: "+str(err)+ " falling back to Tasmota buzzer",1)
            end
            if rtcgpio != 13
                self.ULPBuzzeravailable=false
                log("Alarmhandler: RTCGPIO != 13! RTCGPIO-number of buzzer is hardcoded. Falling back to Tasmota-buzzer",1)
            end

            # Disable ULP-wakeup, as we do not need it yet (code available from ResetAndDisableULP.py)
            #  this is redundant, as current implementation of ULPBuzzer also will prevent starting by setting counter=0.
            var c = bytes().fromb64("dWxwAAwAKAAEAAAABgBgHAYAwC+hAIByBAAAaAAAgHIBAIByAgCAcgMAgHIAAEB0AAAAsAAAAAA=")
            ULP.load(c)
            ULP.run()

            # Determine Sleeptimer-calibration
            # set sleep to 1 second
            ULP.wake_period(1,1000000)
            # Read sleeptime-register        
            var c = bytes().fromb64("dWxwAAwAQAAYAAAAAQGAcgYCgCcEAABoBgLALwQEAGghAYByBwKAJwQAAGgHAsAvBAQAaEEBgHIUAIAnBAAAaBQAwC8EBABoAAAAsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==")
            ULP.load(c)
            ULP.run()
            # Save result
            self.Sleepcalibration = ULP.get_mem(16)+65535*ULP.get_mem(17)
            
            # then load code (available from assembling ULPBuzzer.S)
            #  as long as run is not called, program will not run
            var c = bytes().fromb64("dWxwAAwA4AAQAAAAgAOAcgAAANABAFqCAQCAcKADgHIAAADQAAAGggEABYIAAIhyAwCAcAGABYIAgCuCOABAcEQAQIAABewdAQAAklAAAIAAAewdAAAAklAAAIAfAMByZABAgKADgHIDAABoAAAAsBUAIHKAA4ByAQAAaAMAiHKgA4ByAwAAaAAAALCQA4ByAAAA0AEABYIAAA+CAgCAcDgAQHCgAECAMAAAgB8AwHKUAACAAQCAcoADgHIBAABoAAAAkgAAALCwA4ByMQaAcgEAAGiAA4ByAQCAcgEAAGgAAewdBgBgHAAAALAAAAAAAgAAAACAAAAAAAAA")
            try
               ULP.load(c)
            except .. as err
                self.ULPBuzzeravailable=false
                log("Alarmhandler: Can't load ULP-program, error: "+str(err)+ " falling back to Tasmota buzzer",1)
            end

            #ULP-Buzzer should be ready to run.
        end
        
        # 
        # beeplist is a list of tuples specifying runtime in seconds, ontime, offtime and tune
        #  As Alarmhandler should be called every second, it will just switch to next tune when runtime is reached.
        #   Please note: Old tune will be played until the end - so for long running tunes take care to set runtime correct
        #  Repetition counter will be for all tunes, just set it high enough not to run out until timeout
        #  Ontime and Offtime are times in milliseconds, if 0, nothing will be changed, if <> 0 it will be changed in sync with tune
        #  
        # beeplist for 10 second interval:
        # starting with 3 beeps in 3 seconds
        # self.beeplist=["4,3,27","6,3,17","11,3,7","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2"]
        # self.beepindex = 0
    end

    def beep()
        var buzzerattr

        if self.beepindex < self.beeplist.size()
            #buzzerattr = str(self.beeplist[self.beepindex]) +",1"
            buzzerattr = str(self.beeplist[self.beepindex]) 
            tasmota.cmd("_buzzer "+buzzerattr, true)
            self.beepindex += 1
        # Alarm off
        else
            self.beepindex = 0
            persist.alarmactive=0
            log("AlarmHandler: Timeout Alarm",2)
            tasmota.publish_result("{\"Alarm\":\"Timeout\"}","") # Subtopic doesn't work, therefore empty
        end
    end
end

return AlarmHandler

#-
def beep()
    mah.beep()
    tasmota.set_timer(1000,beep,"beeper")
  end
-#
