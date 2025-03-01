import string

class IconHandler
# Class for loading and displaying icons from files, including animations.
# Memory is a crucial point, as animated icons could take up a lot of memory. Some measures are taken to control memory usage:
# - Loading will be done in parts for animations with >Loadcount images. 
#    This must be done as otherwise heap memory will get exhausted. As Berry is blocking code, even garbage collector cannot
#    run during code running. Combined with too less control over Berry object memory allocation this leads to high memory usage 
#    during one load step. In splitting the loading of the file, garbage collector gets the chance to clean up.
# - Before loading next image, free memory will be checked. This helps, but is no guarantee for not exhausting memory
# - Only two icon-files will be buffered in memory. If more than two files are to be displayed, display and loading is done alternately
# - Buffering is done in plain byte-types. Attempts to store them in lists were abandoned, as lists will take up to 5x more of memory space.
# 
# Icons can be loaded from a miff-, pam- or ppm-file with the following structure:
# miff:
# id=ImageMagick
# class=DirectClass
# columns=0-32
# rows=0-8
# depth=8
# type=TrueColorAlpha
# delay=??
# ticks-per-second=???
#
# pam:
# P7
# WIDTH 8
# HEIGHT 8
# DEPTH 4
# MAXVAL 255
# TUPLTYPE RGB_ALPHA
# ENDHDR
# <R G B Alpha values for each pixel, 1 byte per value>
#
# ppm:
# P6
# 8 8
# 255
# < R G B values for each pixel, 1 byte per value>
#
# miff files can be created by image magick with "convert inputfile -type TrueColorAlpha +profile \* outputfile.miff"
# Keys stated above will be evaluated, all other keys will be ignored. Multiple pictures in one file will be handled as animation.
# ppm files can be created with this format by using pngtopam or giftopnm from netpbm-tools, pam files are created by using pngtopam with option -alphapam
# with Netpbm 11.5.2 on Debian/Ubuntu
# The official format definition of ppm and pam would allow for more variations of the formatting, but this code requires exactly the given formats
# Netpbm would allow for animations, too, but giftopnm can only create ppm which does not support alpha-channel and png does not support animations, so I switched to miff instead.

    var Iconbuffer
    var Currentbuffer
    var Iconlist
    var Iconlistindex
    var IconlistRunning
    var Clockfacemanager
    var InstanceID
    var PrevWidth
    var PrevHeight

    static var Loadcount=5


    def init()
        self.Iconbuffer=[bytes(),bytes()] # two bytes buffer holding image date from two files
        self.Currentbuffer=0 # index which of both buffers to use
        self.Iconlist=[] # a list of files containing image data
        self.Iconlistindex=0 # index for the list of files
        self.InstanceID=str(tasmota.millis())
        self.IconlistRunning=false
    end

    def deinit()
        #log("IconHandler: Deinit start",2)
        tasmota.remove_timer(self.InstanceID)
        self.IconlistRunning=false
        #log("IconHandler: Deinit finish",2)
    end

    def starticonlist(iconlist,xoffset,yoffset,minbright,clockfaceManager,drawid) # starts displaying a list of icon-files
        self.Iconlist=iconlist
        self.Iconlistindex=0
        self.Currentbuffer=0
        self.Clockfacemanager=clockfaceManager
        # stop any running list
        self.stopiconlist()
        # Load first part of images into buffer
        var drawbuffer = self.loadiconpart(self.Iconlist[self.Iconlistindex],0,self.Loadcount,self.Currentbuffer)
        # and start showing the buffer
        self.drawmultipleicons(drawbuffer,0,xoffset,yoffset,minbright,self.Clockfacemanager)
        self.IconlistRunning=true
        return 0
    end

    def loadiconpart(filename,fileindex,maxnumber,bufferslot)
        # This will load a given number of images from the file
        #  if file end is not reached, it will schedule another reading
        # Splitting in necessary as garbage collector can't clean up otherwise in between so heap will soon be exhausted

        var iconfile
        var readbuffer
        var buffersize=1000
        var counter=0

        if fileindex == 0
            self.Iconbuffer[bufferslot]=bytes()
        end


        try
            iconfile=open(filename,'rb')
        except .. as err
            log("IconHandler: Can't open iconfile " + filename + ", error: " + str(err),1)
            return nil
        end
        iconfile.seek(fileindex)
        readbuffer=iconfile.readbytes(buffersize)

        if string.startswith(readbuffer.asstring(), 'id=ImageMagick') || fileindex > 0
            log("IconHandler: Miff file found",4)
            var header=""
            var headerprevsize=0
            var width=0 
            var height=0
            var delay=0
            var headerendstring=bytes('3A1A').asstring() 
            var headerend=-1
            var keypos=-1
            var bufferindex = 0
            var freemem
            var newfindex=fileindex
 

            while readbuffer.size() > 0 && counter < maxnumber
                counter += 1
                freemem = tasmota.get_free_heap()
                #log("start while " + str(freemem),2)
                if freemem < 30000 # ensure we have enough memory for loading file
                    log("IconHandler: MIFF-File too big, not enough heap memory left, Free heap: " + str(freemem),1)
                    iconfile.close()
                    return nil
                end
                # this code always starts at header, reload of buffer is done during content read
                
                # We have to search for end of header in buffer
                # Unfortunately there is no search-function implemented in bytes-type.
                # Looping over buffer would be a bad idea: looping by itself is slow in berry (10msec for 1000 entries)
                # and looping over bytes is very very slow: it would take ~80 msec for 1000 bytes! (800 msec for 10000 bytes)
                # Search function from string-type would give a result even from 10000 bytes in 8 msec! (including conversion!)
                # So, even it looks strange, string-conversion is a good idea.
                header=readbuffer.asstring() # asstring is half the size of tohex, so we work with string
                #log("debug: header " + header)
                headerend=string.find(header,headerendstring) 
                while headerend < 0
                    readbuffer=iconfile.readbytes(buffersize)
                    if readbuffer.size() == 0 
                        log("IconHandler: Header End not found in MIFF-file",1 )
                        iconfile.close()
                        return nil
                    end
                    headerprevsize=size(header)
                    header=header..readbuffer.asstring()
                    headerend=string.find(header, headerendstring) 
                end
                header = string.split(header,headerend)[0]
                

                # check header

                keypos = string.find(header,"class=")
                if !( keypos > 0 && string.startswith(header[keypos..keypos+25],"class=DirectClass",true) )
                    log("IconHandler: Can't load MIFF-File, it is not DirectClass.",1)
                    iconfile.close()
                    return nil
                end
                
                keypos = string.find(header,"type=")
                if !( keypos > 0 && string.startswith(header[keypos..keypos+25],"type=TrueColorAlpha",true) )
                    log("IconHandler: Can't load MIFF-File, it is not type TrueColorAlpha.",1)
                    iconfile.close()
                    return nil

                end

                keypos = string.find(header,"depth=")
                if !( keypos > 0 && string.startswith(header[keypos..keypos+25],"depth",true) )
                    log("IconHandler: Can't load MIFF-File, depth is not 8",1)
                    iconfile.close()
                    return nil
                end

                keypos = string.find(header,"columns=")
                if keypos < 0
                    log("IconHandler: Can't find columns in MIFF-file",1)
                    iconfile.close()
                    return nil
                else 
                    width = int(header[keypos+8..keypos+9]) 
                    if (width < 1 || width > 32)
                        log("IconHandler: Columns out of range in MIFF-file",1)
                        iconfile.close()
                        return nil
                    end
                end

                keypos = string.find(header,"rows=")
                if keypos < 0
                    log("IconHandler: Can't find rows in MIFF-file",1)
                    iconfile.close()
                    return nil
                else 
                    height = int(header[keypos+5..keypos+5]) 
                    if (height < 1 || height > 8)
                        log("IconHandler: Rows out of range in MIFF-file",1)
                        iconfile.close()
                        return nil
                    end
                end
                
                keypos = string.find(header,"delay=")
                if keypos < 0
                    delay = 20 # 2 seconds default value for single images
                else 
                    delay = int(header[keypos+6..keypos+9]) 
                end
                
                keypos = string.find(header,"ticks-per-second=")
                if keypos < 0
                    delay = 10 * delay # 100 ticks per second
                else 
                    delay = 1000 / int(header[keypos+17..keypos+20]) * delay
                end
                #imagelist.push([delay,[]]) - a list will have too much overhead, we must stick to bytes buffer
                self.Iconbuffer[bufferslot].add(delay,-2) # max 32 sec signed / 64 sec unsigned
                self.Iconbuffer[bufferslot].add(width,1) # max 127 signed / 255 unsigned
                self.Iconbuffer[bufferslot].add(height,1) # max 127 signed/255 unsigned


                readbuffer = readbuffer[headerend+2-headerprevsize..] # truncate readbuffer at beginning
                newfindex = newfindex + headerend + 3 + (width * height * 4) # calculate new fileindex from header and picture size

                # load complete image into buffer
                while readbuffer.size() < width * height * 4
                    readbuffer = readbuffer..iconfile.readbytes(buffersize)
                end
                #- too much overhead! Iconfiles could be >10k and list would take up to 5 times of memory compared to bytes only
                for line:0..(height-1)
                    imagelist[-1][-1].push([])
                    for pixel:0..(width-1)
                            bufferindex = ( (line * width) + pixel ) * 4
                            if readbuffer[bufferindex+3] < 127 # transparency > 50%
                                imagelist[-1][-1][-1].push(nil)
                            else
                                imagelist[-1][-1][-1].push(readbuffer.geti(bufferindex,-3))
                            end
                    end
                end
                -#    
                self.Iconbuffer[bufferslot] = self.Iconbuffer[bufferslot]..readbuffer[0..(width * height * 4)-1]
                readbuffer = readbuffer[(width * height * 4)..] # truncate start of readbuffer
                #reload buffer if we have emptied it and there are still images to load
                if ( counter < maxnumber ) && ( readbuffer.size() < ( buffersize / 2 ) )
                    readbuffer = readbuffer..iconfile.readbytes(buffersize)
                end
                #log("end while " + str(tasmota.get_free_heap()),2)

            end
            
            # Checking for further images to load
            if newfindex < iconfile.size() # if end of file is not reached, trigger loading next part
                tasmota.set_timer(100,/->self.loadiconpart(filename,newfindex,maxnumber,bufferslot),self.InstanceID)
            end
            iconfile.close()
            return bufferslot

        # end of miff-read

        # other file formats will only read one single image
        elif string.startswith(readbuffer.asstring(), 'P7')
            log("IconHandler: PAM file found",4)
            var width
            var height
            # Reposition file offset
            iconfile.seek(3)
            var iconfilecontent

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'WIDTH')
                width = number(string.split(iconfilecontent," ")[1])
                if (width < 1) || (width >32)
                    log("IconHandler: Width in iconfile not between 1 and 32",1)
                    iconfile.close()
                    return nil
                end
            else
                log("IconHandler: Expecting WIDTH in second line of iconfile",1)
                iconfile.close()
                return nil
            end

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'HEIGHT')
                height = number(string.split(iconfilecontent," ")[1])
                if (height < 1) || (height >8)
                    log("IconHandler: Height in iconfile not between 1 and 8",1)
                    iconfile.close()
                    return nil
                end
            else
                log("IconHandler: Expecting HEIGHT in third line of iconfile",1)
                iconfile.close()
                return nil
            end


            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'DEPTH')
                var depth = number(string.split(iconfilecontent," ")[1])
                if depth != 4
                    log("IconHandler: Depth in pam-iconfile must be 4",1)
                    iconfile.close()
                    return nil
                end
            else
                log("IconHandler: Expecting DEPTH in fourth line of iconfile",1)
                iconfile.close()
                return nil
            end

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'MAXVAL')
                var maxval = number(string.split(iconfilecontent," ")[1])
                if (maxval < 1) || (maxval > 255)
                    log("IconHandler: Maxval not between 1 and 255",1)
                    iconfile.close()
                    return nil
                end
            else
                log("IconHandler: Expecting MAXVAL in fiveth line of iconfile",1)
                iconfile.close()
                return nil
            end

            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'TUPLTYPE')
                var tuple = string.split(iconfilecontent," ")[1]
                if !string.startswith(tuple,'RGB_ALPHA')
                    log("IconHandler: Tupletype in pam-iconfile must be RGB_ALPHA",1)
                    iconfile.close()
                    return nil
                end
            else
                log("IconHandler: Expecting TUPLETYPE in fiveth line of iconfile",1)
                iconfile.close()
                return nil
            end
            self.Iconbuffer[bufferslot].add(2000,-2) # 2 seconds delay for single images
            self.Iconbuffer[bufferslot].add(width,1) # 
            self.Iconbuffer[bufferslot].add(height,1) # 


            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'ENDHDR')
                self.Iconbuffer[bufferslot]=self.Iconbuffer[bufferslot]..iconfile.readbytes(width*height*4)
                iconfile.close()
                return bufferslot # one icon with no specified delay time
            else
                log("IconHandler: Expecting ENDHDR in sixth line of iconfile",1)
                iconfile.close()
                return nil
            end

        # end of p7-read

        elif string.startswith(readbuffer.asstring(), 'P6')
            log("IconHandler: PPM file found",4)
            var width
            var height
            # Reposition file offset
            iconfile.seek(3)
            var iconfilecontent

            iconfilecontent=iconfile.readline()
            width = number(string.split(iconfilecontent," ")[0])
            height = number(string.split(iconfilecontent," ")[1])
            if (width < 1) || (width >32)
                log("IconHandler: Width in iconfile not between 1 and 32",1)
                iconfile.close()
                return nil
            end
            if (height < 1) || (height >8)
                log("IconHandler: Height in iconfile not between 1 and 8",1)
                iconfile.close()
                return nil
            end


            iconfilecontent=iconfile.readline()
            var maxval = number(iconfilecontent)
            if (maxval < 1) || (maxval > 255)
                log("IconHandler: Maxval not between 1 and 255",1)
                iconfile.close()
                return nil
            end
            self.Iconbuffer[bufferslot].add(2000,-2) # 2 seconds delay for single images
            self.Iconbuffer[bufferslot].add(width,1) # 
            self.Iconbuffer[bufferslot].add(height,1) # 
                
            for pixel:0..(width*height-1)
                self.Iconbuffer[bufferslot] = self.Iconbuffer[bufferslot]..iconfile.readbytes(3)
                # add alpha-channel
                self.Iconbuffer[bufferslot].add(0xff,1)
            end            
            iconfile.close()
            return bufferslot
    
        else
            log("IconHandler: Not supported file format",2)

        end
        
        iconfile.close()
        
        
        return 3
    end


    def drawmultipleicons(iconbufferslot, iconbufferindex, xoffset, yoffset, minbright, clockfaceManager,drawid)
        #clockfaceManager.energysaveoverride=tasmota.millis()
        #log("drawmultipleicons called with " + str(iconbufferslot) + " " + str(iconbufferindex) + " " + str(clockfaceManager),2 )
        var listsize = size(self.Iconlist)
        var matrixController=clockfaceManager.matrixController
        if listsize > 1 && iconbufferindex == 0 # trigger load of next buffer in background if iconlist > 1 and we are at beginning
            self.Iconlistindex = ( self.Iconlistindex + 1 ) % listsize
            self.Currentbuffer = ( self.Currentbuffer + 1 ) % 2
            tasmota.set_timer(500,/->self.loadiconpart(self.Iconlist[self.Iconlistindex],0,self.Loadcount,self.Currentbuffer),self.InstanceID)
            # and wipe previous icon
            matrixController.clear(true, xoffset, yoffset, self.PrevWidth, self.PrevHeight)
        end
        # draw icon at index of iconbuffer, determine delay, set newindex
        if self.Iconbuffer[iconbufferslot] == nil
            return
        end
        var brightness
        var delay = self.Iconbuffer[iconbufferslot].get(iconbufferindex,-2)
        self.PrevWidth = self.Iconbuffer[iconbufferslot].get(iconbufferindex+2,1)
        self.PrevHeight = self.Iconbuffer[iconbufferslot].get(iconbufferindex+3,1)
        
        if clockfaceManager.brightness < minbright
            brightness = minbright
        else 
            brightness = clockfaceManager.brightness
        end

        # Draw complete icon
        for line:0..self.PrevHeight-1
            for pixel:0..self.PrevWidth-1
                iconbufferindex += 4
                matrixController.set_matrix_pixel_color(xoffset+pixel, yoffset+line, 
                                                        (self.Iconbuffer[iconbufferslot].get(iconbufferindex+3) << 24 ) + 
                                                                 self.Iconbuffer[iconbufferslot].get(iconbufferindex,-3),
                                                        brightness,true)
            end
        end
        matrixController.draw()
        iconbufferindex += 4

        if drawid == nil
            drawid = "DrawIcon"
        end

        #log("Drawn, Index at " + str(iconbufferindex) + " delay at " + str(delay) + " size Iconbuffer " + str(size(self.Iconbuffer[iconbufferslot])) + " Currentbuffer " + str(self.Currentbuffer),2)
        if iconbufferindex < size(self.Iconbuffer[iconbufferslot]) # if images left in iconbuffer, trigger draw of next image
            # all images in one iconfile should have same size, otherwise we would have to call a timeconsuming clear every time
            tasmota.set_timer(delay,/->self.drawmultipleicons(iconbufferslot, iconbufferindex, xoffset, yoffset, minbright,clockfaceManager), self.InstanceID )
        else # draw image from next iconbuffer (could be the same if only one icon in iconlist)
            # have to wipe current icon first, as next icon could be different size
            tasmota.set_timer(delay,/->self.drawmultipleicons(self.Currentbuffer, 0, xoffset, yoffset, minbright,clockfaceManager), self.InstanceID )
        end
            
    end

    def stopiconlist()
        # stop deferred jobs
        tasmota.remove_timer(self.InstanceID)
        self.IconlistRunning=false
        
    end



end

return IconHandler