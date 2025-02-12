import BaseClockFace

class EnergysaveClockFace: BaseClockFace

    var Pixelnum


    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.Pixelnum=tasmota.millis() & 0x000000ff # get a somewhat random 0<=number<=255
    end


    def render()
        self.matrixController.clear()
        self.matrixController.set_matrix_pixel_color(self.Pixelnum % 32, self.Pixelnum / 32, 0xffffff, 0)
        self.Pixelnum = ( self.Pixelnum + 1 ) % 256
    end
end

return EnergysaveClockFace