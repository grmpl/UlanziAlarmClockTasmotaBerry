import persist

class AlarmHandler
    var beeplist # Defines the beeping sequence
    var beepindex #  controls the current beeping sequence

    def init()
        # beeplist for 1 second interval: starting every 3 seconds
        #self.beeplist = [1,0,0,1,0,0,1,0,0,1,0,0,1,0,0]
        #  now every 2 seconds
        #self.beeplist = self.beeplist + [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1]
        #  increasing
        #self.beeplist = self.beeplist + [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
        #  increasing
        #self.beeplist = self.beeplist + [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2]
        #  increasing
        #self.beeplist = self.beeplist + [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3]
        #  increasing
        #self.beeplist = self.beeplist + [4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4]
        
        # beeplist for 10 second interval:
        # starting with 3 beeps in 3 seconds
        self.beeplist=["4,3,27","6,3,17","11,3,7","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2","21,3,2"]
        self.beepindex = 0
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
