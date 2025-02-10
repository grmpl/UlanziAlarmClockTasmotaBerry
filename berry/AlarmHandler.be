import persist
import ULP # no try/except possible here, so if Tasmota is not compiled for ULP, no fallback to Tasmota-buzzer is possible.

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
-# 
class AlarmHandler
    # must be set after assembling ULP-code
    static var PrepareTime=900
    static var TimerID="timerbeeplist"
    static var CounterAddress=68
    static var TuneAddress=69
    static var ReturnvalueAddress=71
    static var WatchdogAddress=72
    static var ULPBuzzer="dWxwAAwAEAEUAAAAQASAcgAAANABAGyCAQCAcIAEgHJzPoByAwAAaGAEgHIAAADQAQAFggAAhHIDAIBwAUAFggBAO4I4AEBwXABAgAAF7B0IAEhyVABAgAMAAJJ4AACAAQAAkngAAIAAAewdCABIcnAAQIACAACSeAAAgAAAAJJ4AACAHwDAcowAQIBgBIByAwAAaAAAALADAIRyYASAcgMAAGgVACByQASAcgEAAGgAAACwUASAcgAAANABAAWCAAATggGABYIAgA+CAgCAcDgAQHDQAECAOAAAgB8AwHLEAACAEwCAclwAAIBwBIByMQaAcgEAAGhABIByAQCAcgEAAGhgBIByAwCEcgMAAGgAAewdBgBgHAAAALAAAAAAAgAAAABAAAAAAAAAAAAAAA=="

    # For preventing ULP to run - does not change RTC-GPIO and does not switch GPIO off!
    static var ResetAndDisableULP="dWxwAAwAKAAEAAAABgBgHAYAwC+hAIByBAAAaAAAgHIBAIByAgCAcgMAgHIAAEB0AAAAsAAAAAA="
    # For stopping a running ULPBuzzer - switches GPIO off, disables sleeptimer, resets registers, does not change RTCGPIO!
    static var StopULPBuzzer="dWxwAAwALAAEAAAAAAHsHQYAYBwGAMAvsQCAcgQAAGgAAIByAQCAcgIAgHIDAIByAABAdAAAALAAAAAA"
    # Giving RTCGPIO back, resetting ULP registers and prevent from running
    static var ResetRTCGPIO="dWxwAAwAPAAIAAAAAAHsHSgBzBkGAGAcBgDAL/EAgHIEAABoKAGwLQEBgHIEAABoAACAcgEAgHICAIByAwCAcgAAQHQAAACwAAAAAAAAAAA="

    var BeepList # Defines the beeping sequence
    var BeepIndex #  controls the current beeping sequence
    var ULPBuzzeravailable
    var AlarmRunning
    var LastWatchdog
    var OverallCount
    var TargetTime
    


    def init()
        self.AlarmRunning=false
        # Try to initialize ULP-buzzer
        self.ULPBuzzeravailable = true
        # Initialize ULP-Buzzer
        # first try to get Buzzer-GPIO
        var rtcgpio
        try 
            rtcgpio = ULP.gpio_init(gpio.pin(gpio.BUZZER),1)
        except .. as err
            self.ULPBuzzeravailable=false
            log("Alarmhandler: Can't assign GPIO to RTC, error: "+str(err)+ " falling back to Tasmota buzzer",1)
        end
        if rtcgpio != 13
            self.ULPBuzzeravailable=false
            log("Alarmhandler: RTCGPIO != 13! RTCGPIO-number of buzzer is hardcoded. Falling back to Tasmota-buzzer",1)
            # When using another device, ULPBuzzer.S must be modified
        end

        if self.ULPBuzzeravailable

            # Stop any running buzzer possibly left over from previous runs
            var c = bytes().fromb64(self.StopULPBuzzer)
            ULP.load(c)
            ULP.run()

            # then load code (available from assembling ULPBuzzer.S)
            #  redundant, as all starting methods will do this again. As long as run is not called, program will not run
            c = bytes().fromb64(self.ULPBuzzer)
            try
               ULP.load(c)
            except .. as err
                self.ULPBuzzeravailable=false
                log("Alarmhandler: Can't load ULP-program, error: "+str(err)+ " falling back to Tasmota buzzer",1)
            end
            ULP.set_mem(self.WatchdogAddress,0)

            #ULP-Buzzer should be ready to run.
        end
        
        # 
        # BeepList is a list of tuples specifying count, ontime, offtime and tune (input parameters for ULP-Buzzer)
        # Alarmhandler will set counter to sum of all tuples, start with first tuple and set timer to 900msec before end of tuple 
        #  after timer has run out, unused timers will be set, next tuple will be saved in ULP-memory with timerset set to new timers
        #  ULPBuzzer will play the current tune to end and then use the new tune
        # 900msec was choosen to be sure to make the change even with long delays. Ideally all tunes should play >1sec. If there is a 
        #  shorter tune used, repetitions could be ended before count is reached - be aware of it.
        # Alarmhandler must take care to switch the timers
        # If we miss the change, previous tune will be run again. This would be bad for long running tunes, but we do not loose 
        #  the alarm, as ULP-buzzer will just be counting on.
        # Ontime and Offtime are times in milliseconds, pausing can be done with 0-tune and corresponding offtime
        #  
        self.BeepList=[[1,20,300,0x4000],[1,20,200,0x5000],[3,99,1000,0x0000],[5,100,100,0x4000],[5,100,100,0x5000],[5,100,100,0x5400],[10,100,100,0x5500],[10,100,100,0x5540],[10,100,100,0x5550],[30,100,100,0x5554]]
        # a short beep with 20 seconds, followed by 4.2 seconds pause, a double beep, followed by 4.2 seconds pause, 5 longer double beeps with 1.2 sec pause,
        # 5 triple beeps with 1 sec pause, 10 quadruple beeps with 0.8msec pause, ...
        self.BeepIndex=0
        self.OverallCount=0
        for beeptuple:self.BeepList[0..]
            self.OverallCount+=beeptuple[0]
        end



    end

    def deinit()
        if self.ULPBuzzeravailable
            # Give RTCGPIO back
            var c = bytes().fromb64(self.ResetRTCGPIO)
            ULP.load(c)
            ULP.run()
        end
    end

    def buzzer_alarmoff(count,ontime,offtime,tune) # single beep, will stop alarm!
        if self.ULPBuzzeravailable
            self.stopalarmandbuzzer()
            var c = bytes().fromb64(self.ULPBuzzer)
            ULP.load(c)
            ULP.set_mem(self.CounterAddress,count)
            ULP.set_mem(self.TuneAddress, tune & 0x7FFF)
            ULP.wake_period(0,ontime*1000)
            ULP.wake_period(1,ontime*1000)
            ULP.run()
        else
            tasmota.cmd("_buzzer "+str(count)+","+str(ontime)+","+str(offtime)+","+str(tune))
        end
    end
    
    def alarm() # switch on alarm and keep it running
        # if not started yet, start ULP-Buzzer with BeepIndex=0
        # If already started check for watchdog, if watchdog is not reset, call ULP-Buzzer with [60,100,100,0x2AAA]
        if self.AlarmRunning
            if tasmota.time_reached(self.LastWatchdog+5000) # check every 5 seconds
                if ULP.get_mem(self.WatchdogAddress) != 999
                    ULP.set_mem(self.CounterAddress,60)
                    ULP.set_mem(self.TuneAddress,0x2AAA)
                    ULP.wake_period(0,100000)
                    ULP.wake_period(1,100000)
                    ULP.run()
                else 
                    ULP.set_mem(self.WatchdogAddress,0)
                    self.LastWatchdog=tasmota.millis()
                end
            end
        else
            # Initialize alarm
            self.BeepIndex=0
            var c = bytes().fromb64(self.ULPBuzzer)
            ULP.load(c)
            ULP.set_mem(self.WatchdogAddress,0)
            self.LastWatchdog=tasmota.millis()
            ULP.set_mem(self.CounterAddress,self.OverallCount+10)
            ULP.wake_period(0,self.BeepList[self.BeepIndex][2]*1000)
            ULP.wake_period(1,self.BeepList[self.BeepIndex][1]*1000)
            ULP.set_mem(self.TuneAddress,self.BeepList[self.BeepIndex][3] & 0x7fff)
            ULP.run()
            self.AlarmRunning=true

            var nextstarttime = self.calcruntime(self.BeepIndex)-self.PrepareTime
            if nextstarttime < 10
                nextstarttime = 10
            end
            self.TargetTime = tasmota.millis() + nextstarttime
            log("AlarmHandler: alarm started, runBeepList set timer at "+str(tasmota.millis())+" with targettime "+str(self.TargetTime),3)
            tasmota.set_timer(nextstarttime,/->self.runBeepList(),self.TimerID)
        end
            

    end

    def runBeepList()
        log("AlarmHandler: runBeepList called at "+str(tasmota.millis())+" with BeepIndex "+str(self.BeepIndex),3)
        
        # We are prepartime before end of current BeepList-tune, PrepareTime was inserted in alarm()
        # ULPBuzzer should play next tune after current tune has finished
        self.BeepIndex += 1
        # check if end would be reached, if no, set time, set tune and calculate next time
        if self.BeepIndex < self.BeepList.size()
            # set timerset and tune
            if (ULP.get_mem(self.TuneAddress) & 0x8000) == 0 # currently timersetbit=0 - timerset 1
                ULP.wake_period(2,self.BeepList[self.BeepIndex][2]*1000) # next use timerset 2
                ULP.wake_period(3,self.BeepList[self.BeepIndex][1]*1000)
                ULP.set_mem(self.TuneAddress,self.BeepList[self.BeepIndex][3] | 0x8000) # set timersetbit=1
            else # currently timersetbit=1 - timerset 2
                ULP.wake_period(0,self.BeepList[self.BeepIndex][2]*1000) # next use timerset 1
                ULP.wake_period(1,self.BeepList[self.BeepIndex][1]*1000)
                ULP.set_mem(self.TuneAddress,self.BeepList[self.BeepIndex][3] & 0x7fff) # set timersetbit=0
            end
            var acttime = tasmota.millis()
            var timedelta = acttime - self.TargetTime # difference should be overflow and sign-proof
            # nextstarttime would be just runtime in the future, as we should be already PrepareTime before the end
            #  but there could have been a delay and multiple delays would sum up, so we have to subtract delay 
            var nextstarttime = self.calcruntime(self.BeepIndex) - timedelta 
            if nextstarttime < (self.PrepareTime - timedelta + 10) # ensure next start is in next tune
                nextstarttime = self.PrepareTime - timedelta + 10 
            end
            self.TargetTime = acttime + nextstarttime
            # To get even more in sync with ULP we would have to synchronize to RTC-Clock
            #  This would mean: 
            #   - get Calibration Value for RTC-Clock at init (saved with Q13.19-format in RTC_CNTL_STORE1_REG)
            #   - before start of alarm read RTC-Clock (RTC_CNTL_TIME0_REG) and tasmota.millis() to get a common sync
            #      as overflow of RTC-Clock is happening a lot more than millis-timer, timesync should not be too long in the past
            #   - ULPBuzzer writes RTC-Clock at every tune change
            #   - runBeepList compares current time in milliseconds since sync with tune start time in ticks since last sync and 
            #       determines the time-position within tune from that.
            #   - all must be checked against problems concerning overflow and sign
            #  This is complicated and would need a lot of changes.
        
            log("AlarmHandler: runBeepList set timer at "+str(tasmota.millis())+" with Targettime: "+str(self.TargetTime),3)
            tasmota.set_timer(nextstarttime,/->self.runBeepList(),self.TimerID)
        else # End reached
            # wait for end of tune and then stop it
            tasmota.set_timer(self.PrepareTime,/->self.endalarm(),self.TimerID)
        end
    end

    def endalarm()
        persist.alarmactive=0
        persist.save()
        log("AlarmHandler: Timeout Alarm",2)
        tasmota.publish_result("{\"Alarm\":\"Timeout\"}","") # Subtopic doesn't work, therefore empty
        self.stopalarmandbuzzer()
    end


    def calcruntime(index)
        var bit=0
        var bitpointer=0x4000
        var runtime = 0
        # find first 1-bit, stop at last bit
        while (bitpointer & self.BeepList[index][3] == 0) && bitpointer != 1
            bitpointer = bitpointer >> 1
        end

        # sum up on*ontime, off*offtime
        while bitpointer != 0
            runtime = runtime + ( bitpointer & self.BeepList[index][3] ) / bitpointer * self.BeepList[index][1] 
                    - (( bitpointer & self.BeepList[index][3] ) / bitpointer - 1) * self.BeepList[index][2] 
            bitpointer = bitpointer >> 1 
        end
        # multiply by count
        runtime = runtime * self.BeepList[index][0]
        return runtime

    end

    def stopalarmandbuzzer()
        # Will stop alarm, but does not set alarmactive to 0
        # stop running BeepList and set BeepIndex back to 0:
        # STOP TIMER first!!!
        tasmota.remove_timer(self.TimerID)
        self.AlarmRunning=false
        self.BeepIndex=0

        

        var c = bytes().fromb64(self.StopULPBuzzer)
        ULP.load(c)
        ULP.run()
    end

end

return AlarmHandler

