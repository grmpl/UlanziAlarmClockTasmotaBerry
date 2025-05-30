import introspect
import string

class BaseClockFace
    var clockfaceManager
    var matrixController

    var hasValue
    var value

    def init(clockfaceManager)
        log(classname(self) + "Init",3)

        self.clockfaceManager = clockfaceManager
        self.matrixController = clockfaceManager.matrixController
        # Clear of background will be called in every Clockface at every rendering, so we don't have to clear it here
        # Clear of foreground will be done only in Iconhandler, so we have to clear it explicitely for all Clockfaces without IconHandler
        self.matrixController.clear(true)
    end

    def deinit()
        log(classname(self)+ "DeInit",3)
    end

    def close()
        # dummy
    end


    def render()
        # will be called in every render-function
        #self.matrixController.clear()
    end
    
    def drawsimpleicon(iconlist,offsetx,offsety,minbright)
        # input: bytes-list, offset x, offset y
        # for each line, for each pixel set matrixpixelcolor
        # if pixel=nil do nothing
        # byte array could be static var, possibly coded into base64
        var x
        var y
        var brightness
        x=offsetx
        y=offsety
        # low brightness does not work for icons, colors will fade away
        if iconlist == nil
            return
        end
        if self.clockfaceManager.brightness < minbright
            brightness = minbright
        else
            brightness = self.clockfaceManager.brightness
        end
        for line:iconlist[0..]
            if line != nil
                for pixel:line[0..]
                    if pixel != nil
                        self.matrixController.set_matrix_pixel_color(x, y, pixel,brightness)
                    end
                    x += 1 #also with pixel=nil
                end
                x=offsetx
            end
            y += 1 # nil-line possible
        end

    end

end

return BaseClockFace
