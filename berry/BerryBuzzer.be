# The buzzer-function in Tasmota doesn't have a precise timing. Beeping is irregulary even without much load.
#  There is a measure to reduce irregularity by reducing sleep during beeping, but for me it is still not precise enough.
#  (Maybe this measure is designed for normal energy saving and not for dynamic sleep.)
# An alternative would be to use a relay with blinktime instead of a buzzer. But this has various disadvantages:
#  - blinktime can do only regular intervals, so different on and off is not possible
#  - minimum blinktime is 200 msec
#  - you get all the elements (Webgui, commands) for a relay, which you don't need
# This is an attempt to realize a regular beeping by a berry fastloop-driver.
#   With no load, I got very regular beeping. With ClockfaceManager running, it's disturbed by secondly refresh, which 
#   takes almost 300msec to finish. If you run beeper-sequence in 1sec-intervals with sequence taking <700msec, beeping will be very regular. 
class BerryBuzzer
    var starttime
    var started
    var realstart
    var counter
    var maxcounter
    var interval
    var offtime
    var awake
    var buzzergpio
    var endcause #1=counter, 2=maxtime, 3=cancel, 4=error

    #debugging only
    #var lasttimeon
    #var lasttimeoff
    var debuglist



    def init()
        self.starttime=0
        self.started=false
        self.realstart=0
        self.counter=0
        self.maxcounter=20 # On and off are counted, duration will be maxcounter/2*interval
        self.interval=200
        self.offtime=100
        self.awake=0
        self.buzzergpio=gpio.pin(gpio.BUZZER) # there could be only one buzzer, if two are configured, the first will be taken
        self.endcause=4 # should be overwritten by 1,2 or 3 



        #debugging only
        self.debuglist=[]


        #Install BuzzerDriver
        def bzdriverinstance()
            self.BuzzerDriver()
        end

        tasmota.add_fast_loop(bzdriverinstance)
        



    end


    def BuzzerDriver()
        if self.starttime == nil #avoid exceptions
            self.starttime = 0
        end
        # Indicate driver is running
        self.awake = tasmota.millis()
        
        # Driver will only do anything if it's in a specified time window.
        # The time window starts at starttime and ends max 5 seconds after normal end
        # maxendtime will be needed twice, so calculat it once
        var maxendtime=self.starttime+self.interval*self.maxcounter/2+5000

        # Check if we are in time window
        if tasmota.time_reached(self.starttime) && !tasmota.time_reached(maxendtime)
            if self.started==false && self.counter<2  # if we haven't started already, initialize buzzing, counter must always be set to 0 when function is called
                self.started=true 
                self.realstart=tasmota.millis() # there could have been a delay, so compute on/off-time from real start time
                gpio.digital_write(self.buzzergpio,1)
                self.counter=2 # Interval 1 started, counter is interval-number * 2, see below
                self.debuglist=self.debuglist+["start",self.counter,tasmota.millis(),self.started]
            # else check counter 
            # As we want to avoid calling an action repeatedly although done already, we have to remember it was done.
            #  To avoid an additional variable for this, counter is incremented on every action. So it increments twice and not only once per interval.
            elif self.counter <= self.maxcounter
                # Wait until (interval-endtime - offtime), then switch off and increase counter, 
                #  interval-endtime = interval-number*interval-time
                #  If time reached, counter will increase from 2*interval-number to (2*interval-number)+1
                #  As check is adding a 1, check will be before against current interval-endtime - offset (+1 makes no difference)
                #  and afterwards against (next interval-endtime) - offset (1+1=2 is next interval)
                if tasmota.time_reached( self.realstart + ( ( ( self.counter + 1 ) >> 1 ) * self.interval ) - self.offtime )
                    gpio.digital_write(self.buzzergpio,0)
                    #self.lasttimeoff=tasmota.millis()
                    self.counter += 1
                end
                # Wait until interval-endtime, then switch on and increase counter
                #  Counter should increase from (2*interval-number)+1 to 2*(interval-number+1), because off has already increased counter
                #  So check will be before against current interval-endtime (+1 makes no difference) 
                #  and after against next interval-endtime (+2 is next interval)
                #  Don't forget the brackets at bitshift, otherwise bitshift is done after multiplication
                if tasmota.time_reached( self.realstart + ( ( self.counter >> 1 ) * self.interval ) )
                    self.debuglist=self.debuglist+["onloop",self.counter,tasmota.millis(),self.realstart+(self.counter >> 1 * self.interval)]
                    gpio.digital_write(self.buzzergpio,1)
                    #self.lasttimeon=tasmota.millis()
                    self.counter += 1
                end
                # We could do an additional check against time>interval-time*maxintervals, in case we missed an action
                #  but as the logic is based on time>x*count, every missed action will be catched up
                #  and finally we will be canceled by time window, we just have to make sure we are cleaning up even in case of cancel
            else #counter>maxcounter -> interval-number>=max-interval && Off-action is done, now we can stop
                gpio.digital_write(self.buzzergpio,0)      # make sure, we haven't missed the off-action
                self.started=false
                self.endcause=1
                #self.debuglist=self.debuglist+["end",self.counter,tasmota.millis(),self.started]
            end
        elif tasmota.time_reached(maxendtime) && self.started==true # in case time window has ended, but buzzer did not finish
            gpio.digital_write(self.buzzergpio,0)
            self.started=false
            self.endcause=2
        end
    end

    def StartBuzzer(count,ontime,offtime)
        # First check if driver is running 
        if self.awake > tasmota.millis()-500
            if count > 0 # allow 0 beeps, but not negative
                # Initialize variables
                log("BerryBuzzer: Starting beep with count="+str(count)+", ontime="+str(ontime)+", offtime="+str(offtime),3)
                self.started=false # will be set to true in driver
                self.maxcounter=count*2
                self.interval=(ontime+offtime)*100 # buzzer-command is in 100ms units
                self.offtime=offtime*100

                self.realstart=0
                self.counter=0
                self.starttime=tasmota.millis()
                tasmota.set_timer(self.interval*self.maxcounter/2+6000,/->self.checkBuzzerend())
            else
                log("BerryBuzzer: StartBuzzer called with count=0, calling StopBuzzer",3)
                self.StopBuzzer()
            end
        else # use tasmota command
            log("BerryBuzzer: Driver not running, using Tasmota command",2) 
            tasmota.cmd("_buzzer "+str(count)+","+str(ontime)+","+str(offtime),true)
        end
    end

    def StopBuzzer()
        # Stop own buzzer and tasmota buzzer
        self.starttime=0
        tasmota.cmd("_buzzer 0",true)
        gpio.digital_write(self.buzzergpio,0)
        self.started=false
        self.endcause=3
        log("BerryBuzzer: Buzzer stopped by StopBuzzer",3)
    end

    def checkBuzzerend()
        # Check for endcause and return it
        log("BerryBuzzer: Buzzer ended with cause "+str(self.endcause),3)
    end

end

return BerryBuzzer
#-
# Install driver
bz=BerryBuzzer()
def bztmp()
  bz.BuzzerDriver()
end
tasmota.add_fast_loop(bztmp)

# Start Buzzer
bz.starttime=tasmota.millis()+1000
# Stop Buzzer if Script is failing
gpio.digital_write(15,0)
-#

