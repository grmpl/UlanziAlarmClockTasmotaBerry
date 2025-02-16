import introspect
import string

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

        # Icons can be loaded from a pam- or ppm-file with the following structure:
        # pam:
        # P7
        # WIDTH 8
        # HEIGHT 8
        # DEPTH 4
        # MAXVAL 255
        # TUPLTYPE RGB_ALPHA
        # ENDHDR
        # <R G B Alpha values for each pixel, 1 byte per value>
        # ppm:
        # P6
        # 8 8
        # 255
        # < R G B values for each pixel, 1 byte per value>
        # ppm files are created with this format by using pngtopam or giftopnm, pam files are created by using pngtopam with option -alphapam
        # with Netpbm 11.5.2 on Debian/Ubuntu
        # The official format definition would allow for more variations of the formatting, but this code requires exactly the given formats


        # 
        var iconfile
        var iconfilecontent
        var iconmatrix=[]


        try
            iconfile=open(filename,'rb')
        except .. as err
            log("BaseClockFace: Can't open iconfile " + filename + ", error: " + str(err),1)
            return nil
        end

        iconfilecontent=iconfile.readline()
        if string.startswith(iconfilecontent, 'P7')
            log("BaseClockFace: PAM file found",4)
            var width
            var height

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'WIDTH')
                width = number(string.split(iconfilecontent," ")[1])
                if (width < 1) || (width >32)
                    log("BaseClockFace: Width in iconfile not between 1 and 32",1)
                    iconfile.close()
                    return nil
                end
            else
                log("BaseClockFace: Expecting WIDTH in second line of iconfile",1)
                iconfile.close()
                return nil
            end

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'HEIGHT')
                height = number(string.split(iconfilecontent," ")[1])
                if (height < 1) || (height >8)
                    log("BaseClockFace: Height in iconfile not between 1 and 8",1)
                    iconfile.close()
                    return nil
                end
            else
                log("BaseClockFace: Expecting HEIGHT in third line of iconfile",1)
                iconfile.close()
                return nil
            end


            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'DEPTH')
                var depth = number(string.split(iconfilecontent," ")[1])
                if depth != 4
                    log("BaseClockFace: Depth in pam-iconfile must be 4",1)
                    iconfile.close()
                    return nil
                end
            else
                log("BaseClockFace: Expecting DEPTH in fourth line of iconfile",1)
                iconfile.close()
                return nil
            end

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'MAXVAL')
                var maxval = number(string.split(iconfilecontent," ")[1])
                if (maxval < 1) || (maxval > 255)
                    log("BaseClockFace: Maxval not between 1 and 255",1)
                    iconfile.close()
                    return nil
                end
            else
                log("BaseClockFace: Expecting MAXVAL in fiveth line of iconfile",1)
                iconfile.close()
                return nil
            end

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'TUPLTYPE')
                var tuple = string.split(iconfilecontent," ")[1]
                if !string.startswith(tuple,'RGB_ALPHA')
                    log("BaseClockFace: Tupletype in pam-iconfile must be RGB_ALPHA",1)
                    iconfile.close()
                    return nil
                end
            else
                log("BaseClockFace: Expecting TUPLETYPE in fiveth line of iconfile",1)
                iconfile.close()
                return nil
            end

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'ENDHDR')
                for line:0..(height-1)
                    var linelist = []
                    for pixel:0..(width-1)
                        iconfilecontent=iconfile.readbytes(4)
                        if iconfilecontent[3] < 127 # transparency >50%
                            linelist.push(nil)
                        else 
                            linelist.push(iconfilecontent.geti(0,-3))
                        end
                    end
                    iconmatrix.push(linelist)
                end            
                iconfile.close()
                return iconmatrix
            else
                log("BaseClockFace: Expecting ENDHDR in sixth line of iconfile",1)
                iconfile.close()
                return nil
            end

        # end of p7-read

        elif string.startswith(iconfilecontent, 'P6')
            log("BaseClockFace: PPM file found",4)
            var width
            var height

            iconfilecontent=iconfile.readline()
            width = number(string.split(iconfilecontent," ")[0])
            height = number(string.split(iconfilecontent," ")[1])
            if (width < 1) || (width >32)
                log("BaseClockFace: Width in iconfile not between 1 and 32",1)
                iconfile.close()
                return nil
            end
            if (height < 1) || (height >8)
                log("BaseClockFace: Height in iconfile not between 1 and 8",1)
                iconfile.close()
                return nil
            end


            iconfilecontent=iconfile.readline()
            var maxval = number(iconfilecontent)
            if (maxval < 1) || (maxval > 255)
                log("BaseClockFace: Maxval not between 1 and 255",1)
                iconfile.close()
                return nil
            end
                
            for line:0..(height-1)
                var linelist = []
                for pixel:0..(width-1)
                    iconfilecontent=iconfile.readbytes(3)
                    linelist.push(iconfilecontent.geti(0,-3))
                end
                iconmatrix.push(linelist)
            end            
            iconfile.close()
            return iconmatrix
       
        else
            log("BaseClockFace: Not supported file format",2)

        end
        
    iconfile.close()
    end

    def drawicon(iconlist,offsetx,offsety,minbright)
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
