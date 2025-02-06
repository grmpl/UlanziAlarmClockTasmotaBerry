import introspect

class BaseClockFace
    var clockfaceManager
    var matrixController

    var hasValue
    var value

    def init(clockfaceManager)
        log(classname(self) + "Init",3);

        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
    end

    def deinit()
        log(classname(self)+ "DeInit",3);
    end


    def render()
        self.matrixController.clear()
    end

    def loadicon(filename)
        # Convert images with netpbm-tools.
        # pngtopam will generate a pam-file when option -alphapam is used
        # pngtopam without -alphapam and giftopnm will generate a ppm-file 
        # Read file by line, check for P6/P7 magic number
        #  P7 : Check Width <=32, Check height <=8, check depth=4, check maxval = 255, check  TUPLTYPE RGB_ALPHA-> reject if not in range
        #  P6:  Check Width <=32, Check height <=8, check maxval = 255 -> reject if not in range
        # read image from file into bytes-list: [line1[pixel1(0xRRGGBB),pixel2(0xRRGGBB)],pixel3 nil,line2[...]]
        #   pixel=nil if alpha <128, meaning don't touch the pixel, leave it as it is -> no gradient supported
    end

    def drawicon(iconlist,offsetx,offsety)
        # input: bytes-list, offset x, offset y
        # for each line, for each pixel set matrixpixelcolor
        # if pixel=nil do nothing
        # byte array could be static var, possibly coded into base64
        var x
        var y
        x=offsetx
        y=offsety
        for line:iconlist[0..]
            if line != nil
                for pixel:line[0..]
                    if pixel != nil
                        self.matrixController.set_matrix_pixel_color(x, y, pixel,self.clockfaceManager.brightness)
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
