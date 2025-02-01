import persist
import ULP # try except does not work here, so error must be catched when importing AlarmHandler

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
    # must be set after assembling ULP-code
    static var preparetime=800
    static var CounterAddress=68
    static var TuneAddress=69
    static var ReturnvalueAddress=71
    static var WatchdogAddress=72
    static var ULPBuzzer="dWxwAAwAEAEUAAAAQASAcgAAANABAGyCAQCAcIAEgHJzPoByAwAAaGAEgHIAAADQAQAFggAAhHIDAIBwAUAFggBAO4I4AEBwXABAgAAF7B0IAEhyVABAgAMAAJJ4AACAAQAAkngAAIAAAewdCABIcnAAQIACAACSeAAAgAAAAJJ4AACAHwDAcowAQIBgBIByAwAAaAAAALADAIRyYASAcgMAAGgVACByQASAcgEAAGgAAACwUASAcgAAANABAAWCAAATggGABYIAgA+CAgCAcDgAQHDQAECAOAAAgB8AwHLEAACAEwCAclwAAIBwBIByMQaAcgEAAGhABIByAQCAcgEAAGgDQIByYASAcgcAAGgAAewdBgBgHAAAALAAAAAAAgAAAABAAAAAAAAAAAAAAA=="

    # For preventing ULP to run - does not change RTC-GPIO and does not switch GPIO off!
    static var ResetAndDisableULP="dWxwAAwAKAAEAAAABgBgHAYAwC+hAIByBAAAaAAAgHIBAIByAgCAcgMAgHIAAEB0AAAAsAAAAAA="
    # For stopping a running ULPBuzzer - switches GPIO off, disables sleeptimer, resets registers, does not change RTCGPIO!
    static var StopULPBuzzer="dWxwAAwALAAEAAAAAAHsHQYAYBwGAMAvsQCAcgQAAGgAAIByAQCAcgIAgHIDAIByAABAdAAAALAAAAAA"
    # Giving RTCGPIO back, resetting ULP registers and prevent from running
    static var ResetRTCGPIO="dWxwAAwAPAAIAAAAAAHsHSgBzBkGAGAcBgDAL/EAgHIEAABoKAGwLQEBgHIEAABoAACAcgEAgHICAIByAwCAcgAAQHQAAACwAAAAAAAAAAA="

    var beeplist # Defines the beeping sequence
    var beepindex #  controls the current beeping sequence
    var ULPBuzzeravailable
    var AlarmRunning
    var lastWatchdog
    var OverallCount
    


    def init()
        self.AlarmRunning=false
        # Try to initialize ULP-buzzer
        
        if self.ULPBuzzeravailable
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
        end

        if self.ULPBuzzeravailable

            # Disable ULP-wakeup, as we do not need it yet (code available from ResetAndDisableULP.py)
            #  this is redundant, as current implementation of ULPBuzzer also will prevent starting by setting counter=0.
            var c = bytes().fromb64(self.ResetAndDisableULP)
            ULP.load(c)
            ULP.run()

            # then load code (available from assembling ULPBuzzer.S)
            #  as long as run is not called, program will not run
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
        # beeplist is a list of tuples specifying count, ontime, offtime and tune (input parameters for ULP-Buzzer)
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
        # beeplist for 10 second interval:
        # starting with 3 beeps in 3 seconds
        # self.beeplist=["4,3,27","6,3,17","11,3,7","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2"]
        # self.beepindex = 0
        self.beeplist=[[1,20,300,0x4000],[1,20,100,0x5000],[2,99,1000,0x0000],[5,100,100,0x5000],[5,100,100,0x5400],[10,100,100,0x5500],[10,100,100,0x5540],[10,100,100,0x5550],[30,100,100,0x5554]]
        # a short beep with 20 seconds, followed by 4.2 seconds pause, a double beep, followed by 3.2 seconds pause, 5 longer double beeps with 1.2 sec pause,
        # 5 triple beeps with 1 sec pause, 10 quadruple beeps with 0.8msec pause, ...
        self.beepindex=0
        self.OverallCount=0
        for beeptuple:self.beeplist[0..]
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
            self.stopalarm()
            ULP.load(self.ULPBuzzer)
            ULP.set_mem(self.CounterAddress,count)
            ULP.set_mem(self.TuneAddress, tune & 0x7FFF)
            ULP.wake_period(0,ontime)
            ULP.wake_period(1,ontime)
            ULP.run()
        else
            tasmota.cmd("_buzzer "+str(count)+","+str(ontime)+","+str(offtime)+","+str(tune))
        end
    end
    
    def alarm() # switch on alarm and keep it running
        # if not started yet, start ULP-Buzzer with beepindex=0
        # If already started check for watchdog, if watchdog is not reset, call ULP-Buzzer with [60,100,100,0x2AAA]
        if self.AlarmRunning
            if tasmota.time_reached(self.lastWatchdog+5000) # check every 5 seconds
                if ULP.get_mem(self.WatchdogAddress) != 999
                    ULP.set_mem(self.CounterAddress,60)
                    ULP.set_mem(self.TuneAddress,0x2AAA)
                    ULP.wake_period(0,100)
                    ULP.wake_period(1,100)
                    ULP.run()
                else 
                    ULP.set_mem(self.WatchdogAddress,0)
                    self.lastWatchdog=tasmota.millis()
                end
            end
        else
            # Initialize alarm
            self.beepindex=0
            ULP.set_mem(self.CounterAddress,self.OverallCount+10)
            ULP.wake_period(0,self.beeplist[self.beepindex][2])
            ULP.wake_period(1,self.beeplist[self.beepindex][1])
            ULP.set_mem(self.TuneAddress,self.beeplist[self.beepindex][3] & 0x7fff)
            ULP.run()
            self.AlarmRunning=true

            var nextstarttime = self.calcruntime(self.beepindex)-self.preparetime
            if nextstarttime < 10
                nextstarttime = 10
            end
            tasmota.set_timer(nextstarttime,/->self.runbeeplist())
        end
            

    end

    def runbeeplist()
        # get actual timerset from ULP, set wake_period for other set and set new tune with this set 
        if (ULP.get_mem(self.TuneAddress) & 0x8000) == 0
            ULP.wake_period(0,self.beeplist[self.beepindex][2])
            ULP.wake_period(1,self.beeplist[self.beepindex][1])
            ULP.set_mem(self.TuneAddress,self.beeplist[self.beepindex][3] & 0x7fff)
        else
            ULP.wake_period(2,self.beeplist[self.beepindex][2])
            ULP.wake_period(3,self.beeplist[self.beepindex][1])
            ULP.set_mem(self.TuneAddress,self.beeplist[self.beepindex][3] | 0x8000)
        end

        # now ULPBuzzer should play next tune after current tune has finished
        # prepare for next change
        self.beepindex += 1
        # check if end is reached
        if self.beepindex < self.beeplist.size()
            var nextstarttime = self.calcruntime(self.beepindex)-self.preparetime
            if nextstarttime < 10
                nextstarttime = 10
            end
        
            tasmota.set_timer(nextstarttime,/->self.runbeeplist())
        else
            self.AlarmRunning=false
            self.beepindex=0
            persist.alarmactive=0
            log("AlarmHandler: Timeout Alarm",2)
            tasmota.publish_result("{\"Alarm\":\"Timeout\"}","") # Subtopic doesn't work, therefore empty
            tasmota.set_timer(self.preparetime,/->self.stopalarmandbuzzer())
        end
    end

    def calcruntime(index)
        var bit=0
        var bitpointer=0x4000
        var runtime = 0
        # find first 1-bit, stop at last bit
        while (bitpointer & self.beeplist[index][3] == 0) && bitpointer != 1
            bitpointer = bitpointer >> 1
        end

        # sum up on*ontime, off*offtime
        while bitpointer != 0
            runtime = runtime + ( bitpointer & self.beeplist[index][3] ) / bitpointer * self.beeplist[index][1] 
                    - (( bitpointer & self.beeplist[index][3] ) / bitpointer - 1) * self.beeplist[index][2] 
            bitpointer = bitpointer >> 1 
        end
        # multiply by count
        runtime = runtime * self.beeplist[index][0]
        return runtime

    end

    def stopalarmandbuzzer()
        # stop running beeplist and set beepindex back to 0:
        # remove timer
        self.beepindex=0
        

        ULP.load(self.StopULPBuzzer)
        ULP.run()
    end

end

return AlarmHandler

