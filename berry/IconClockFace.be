import BaseClockFace
import persist

class IconClockFace: BaseClockFace

    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
                
    end


    def render()
        var iconfromfile

        self.matrixController.clear()
        self.matrixController.change_font('Glance')

        #log("IconClockFace: Draw 2nd Icon",4)
        #log("IconClockFace: Draw 2nd Icon, time: " + str(tasmota.millis()),4)
        iconfromfile = self.loadicon('555.pam')
        self.drawicon(iconfromfile,8,0)
        #log("IconClockFace: 2nd Icon drawn, time: " + str(tasmota.millis()),4)
        # ~80msec!

        #log("IconClockFace: Draw 4th Icon",4)
        iconfromfile = self.loadicon('36220.pam')
        self.drawicon(iconfromfile,24,0)

        #log("IconClockFace: Draw 3rd Icon",4)
        iconfromfile = self.loadicon('3253.pam')
        self.drawicon(iconfromfile,16,0)

        #log("IconClockFace: Draw 1st Icon",4)
        iconfromfile = self.loadicon('96.pam')
        self.drawicon(iconfromfile,0,0)




    end

end

return IconClockFace