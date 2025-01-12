import persist
import BerryBuzzer

class AlarmHandler
    var beeplist # Defines the beeping sequence
    var beepindex #  controls the current beeping sequence
    var buzzer # Instance of the buzzer driver

    def init()
        # beeplist for 1 second interval: starting every 3 seconds
        # starting with 3 beeps in 3 seconds
        self.beeplist=[[1,2,1],[0,0,0],[0,0,0],[0,0,0],[0,0,0],[0,0,0],[0,0,0],[0,0,0],[0,0,0],[0,0,0]]
        self.beeplist=self.beeplist + [[1,2,1],[0,0,0],[0,0,0],[0,0,0],[0,0,0],[1,2,1],[0,0,0],[0,0,0],[0,0,0],[0,0,0]]
        self.beeplist=self.beeplist + [[1,2,1],[0,0,0],[1,2,1],[0,0,0],[1,2,1],[0,0,0],[1,2,1],[0,0,0],[0,0,0],[1,2,1]]
        self.beeplist=self.beeplist + [[2,2,1],[2,2,1],[2,2,1],[2,2,1],[2,2,1],[2,2,1],[2,2,1],[2,2,1],[2,2,1],[2,2,1]]
        self.beeplist=self.beeplist + [[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1]]
        self.beeplist=self.beeplist + [[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1]]
        self.beeplist=self.beeplist + [[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1]]
        self.beeplist=self.beeplist + [[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1]]
        self.beeplist=self.beeplist + [[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1],[3,1,1]]
        self.beepindex = 0
        self.buzzer=BerryBuzzer()
    end

    def Beep()
        var buzzerattr

        if self.beepindex < self.beeplist.size()
            self.buzzer.StartBuzzer(self.beeplist[self.beepindex][0],self.beeplist[self.beepindex][1],self.beeplist[self.beepindex][2])             
            self.beepindex += 1
        # Alarm off
        else
            self.beepindex = 0
            persist.alarmactive=0
            log("AlarmHandler: Timeout Alarm",2)
            tasmota.publish_result("{\"Alarm\":\"Timeout\"}","") # Subtopic doesn't work, therefore empty
        end
    end

    def StopBuzzer()
        self.buzzer.StopBuzzer()
    end

    def StopBuzzerWithBeep()
        self.buzzer.StopBuzzer()
        self.buzzer.StartBuzzer(1,1,1)  
    end
end

return AlarmHandler
