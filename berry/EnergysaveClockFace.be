import BaseClockFace

class EnergysaveClockFace: BaseClockFace
# This Clockface is used as a screensaver. It could reduce wearout of LEDs.
    var Pixelnum


    def init(clockfaceManager)
        #log("Energyclocksave: Init start",2)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.Pixelnum=tasmota.millis() & 0x000000ff # get a somewhat random 0<=number<=255
    end


    def render()
        self.matrixController.set_matrix_pixel_color(self.Pixelnum % 32, self.Pixelnum / 32, 0x000000, 0)
        self.Pixelnum = ( self.Pixelnum + 1 ) % 256
        self.matrixController.set_matrix_pixel_color(self.Pixelnum % 32, self.Pixelnum / 32, 0xffffff, 10)
    end
end

return EnergysaveClockFace