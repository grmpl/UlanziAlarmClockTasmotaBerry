import BaseClockFace
import persist

class IconClockFace: BaseClockFace

    var Icons

    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.Icons=[[nil],[nil],[nil],[nil]]
                
    end


    def render()
        var iconfromfile

        self.matrixController.clear()
        self.matrixController.change_font('Glance')

        #log("IconClockFace: Draw 2nd Icon",4)
        #log("IconClockFace: Draw 2nd Icon, time: " + str(tasmota.millis()),4)
        if self.Icons[1] == [nil]
            self.Icons[1] = self.loadicon('555.pam')
        end
        self.drawicon(self.Icons[1],8,0,40)
        #log("IconClockFace: 2nd Icon drawn, time: " + str(tasmota.millis()),4)
        # ~80msec!

        #log("IconClockFace: Draw 4th Icon",4)
        if self.Icons[3] == [nil]
            self.Icons[3]  = self.loadicon('36220.pam')
        end
        self.drawicon(self.Icons[3],24,0,40)

        #log("IconClockFace: Draw 3rd Icon",4)
        if self.Icons[2] == [nil]
            self.Icons[2] = self.loadicon('3253.pam')
        end
        self.drawicon(self.Icons[2],16,0,40)

        #log("IconClockFace: Draw 1st Icon",4)
        if self.Icons[0] == [nil]
            self.Icons[0] = self.loadicon('96.pam')
        end
        self.drawicon(self.Icons[0],0,0,40)




    end

end

return IconClockFace