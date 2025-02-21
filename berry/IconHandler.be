import string

class IconHandler
    var Iconbuffer
    var Currentbuffer
    var Iconlist
    var Iconlistindex

    static var Loadcount=5


    def init()
        self.Iconbuffer=[bytes(),bytes()] # two bytes buffer holding image date from two files
        self.Currentbuffer=0 # index which of both buffers to use
        self.Iconlist=[] # a list of files containing image data
        self.Iconlistindex=0 # index for the list of files
    end

    def starticonlist(iconlist,xoffset,yoffset,minbright) # starts displaying a list of icon-files
        self.Iconlist=iconlist
        self.Iconlistindex=0
        self.Currentbuffer=0
        # Load first part of images into buffer
        var drawbuffer = self.loadiconpart(self.Iconlist[self.Iconlistindex],0,self.Loadcount,self.Currentbuffer)
        # and start showing the buffer
        self.drawicon(drawbuffer,0,xoffset,yoffset,minbright)
        return 0
    end

    def loadiconpart(filename,fileindex,maxnumber,buffer)
        # This will load a given number of images from the file
        #  if file end is not reached, it will schedule another reading
        # Splitting in necessary as garbage collector can't clean up otherwise and heap will be exhausted
        
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
        # miff files can be created by image magick with "convert inputfile -type TrueColorAlpha +profile \* outputfile.miff"
        # Options given will be evaluated, all other options will be ignored. Multiple pictures in one file will be handled as animation.
        # ppm files can be created with this format by using pngtopam or giftopnm from netpbm-tools, pam files are created by using pngtopam with option -alphapam
        # with Netpbm 11.5.2 on Debian/Ubuntu
        # The official format definition of ppm and pam would allow for more variations of the formatting, but this code requires exactly the given formats


        var iconfile
        var readbuffer
        var buffersize=1000
        var counter=0

        if fileindex == 0
            self.Iconbuffer[buffer]=bytes()
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
                if freemem < 40000 # ensure we have enough memory for loading file
                    log("IconHandler: MIFF-File too big, not enough heap memory left, Free heap: " + str(freemem),1)
                    iconfile.close()
                    return nil
                end
                # this code always starts at header, reload of buffer is done during content read
                #
                # there is no search function for bytes-object and any iteration over bytes object is slow (>50msec for 1000 bytes!)
                # Search function from string-module is ten times faster than iteration (6msec), even including conversion!
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
                self.Iconbuffer[buffer].add(delay,-2) # max 32 sec signed / 64 sec unsigned
                self.Iconbuffer[buffer].add(width,1) # max 127 signed / 255 unsigned
                self.Iconbuffer[buffer].add(height,1) # max 127 signed/255 unsigned


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
                self.Iconbuffer[buffer] = self.Iconbuffer[buffer]..readbuffer[0..(width * height * 4)-1]
                readbuffer = readbuffer[(width * height * 4)..] # truncate start of readbuffer
                #reload buffer if we have emptied it and there are still images to load
                if ( counter < maxnumber ) && ( readbuffer.size() < ( buffersize / 2 ) )
                    readbuffer = readbuffer..iconfile.readbytes(buffersize)
                end
                log("end while " + str(tasmota.get_free_heap()),2)

            end
            
            # Checking for further images to load
            if newfindex < iconfile.size() # if end of file is not reached, trigger loading next part
                var timerident="LoadIconPart"+str(buffer)
                tasmota.set_timer(100,/->self.loadiconpart(filename,newfindex,maxnumber,buffer),timerident)
            end
            iconfile.close()
            return buffer

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
            self.Iconbuffer[buffer].add(2,2) # 2 seconds delay for single images
            self.Iconbuffer[buffer].add(width,1) # 
            self.Iconbuffer[buffer].add(height,1) # 


            iconfilecontent=iconfile.readline()
            if string.startswith(iconfilecontent, 'ENDHDR')
                self.Iconbuffer[buffer]=self.Iconbuffer[buffer]..iconfile.readbytes(width*height*4)
                iconfile.close()
                return buffer # one icon with no specified delay time
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
            self.Iconbuffer[buffer].add(2,2) # 2 seconds delay for single images
            self.Iconbuffer[buffer].add(width,1) # 
            self.Iconbuffer[buffer].add(height,1) # 
                
            for pixel:0..(width*height*3-1)
                self.Iconbuffer[buffer] = self.Iconbuffer[buffer]..iconfile.readbytes(3)
                self.Iconbuffer[buffer].add(0xff,1)
            end            
            iconfile.close()
            return buffer
    
        else
            log("IconHandler: Not supported file format",2)

        end
        
        iconfile.close()
        
        
        return 3
    end


    def drawicon(iconbuffern, iconbufferindex, xoffset, yoffset, minbright, clockfaceManager)
        var listsize = size(self.Iconlist)
        if listsize > 1 # trigger load of next buffer in background if iconlist > 1
            self.Iconlistindex = ( self.Iconlistindex + 1 ) % listsize
            self.Currentbuffer = ( self.Currentbuffer + 1 ) % 2
            var timerident="LoadIconPart"+str(self.Currentbuffer)
            tasmota.set_timer(500,/->self.loadiconpart(self.Iconlist[self.Iconlistindex],0,self.Loadcount,self.Currentbuffer),timerident)
        end
        # draw icon at index of iconbuffer, determine delay, set newindex
        if self.Iconbuffer[iconbuffern] == nil
            return
        end
        var matrixController=clockfaceManager.matrixController
        var brightness
        var delay = self.Iconbuffer[iconbuffern].get(iconbufferindex,2)
        var width = self.Iconbuffer[iconbuffern].get(iconbufferindex+2,1)
        var height = self.Iconbuffer[iconbuffern].get(iconbufferindex+3,1)
        
        if clockfaceManager.brightness < minbright
            brightness = minbright
        else 
            brightness = clockfaceManager.brightness
        end

        for line:0..height-1
            for pixel:0..width-1
                iconbufferindex += 4
                if self.Iconbuffer[iconbuffern].get(iconbufferindex+3) > 127 
                    matrixController.set_matrix_pixel_color(xoffset+pixel, yoffset+line, self.Iconbuffer[iconbuffern].get(iconbufferindex,-3),brightness)
                end
            end
        end
        iconbufferindex += 4


        if iconbufferindex < size(self.Iconbuffer[iconbuffern]) # if images left in iconbuffer, trigger draw of next image
            tasmota.set_timer(delay,/->self.drawicon(iconbuffern, iconbufferindex, xoffset, yoffset, minbright,matrixController), "DrawIcon" )
        else # draw image from next iconbuffer (could be the same if only one icon in iconlist)
            tasmota.set_timer(delay,/->self.drawicon(self.Currentbuffer, 0, xoffset, yoffset, minbright,matrixController), "DrawIcon" )
        end
            
    end

    def stopiconlist()
        tasmota.remove_timer("DrawIcon")
        tasmota.remove_timer("LoadIconPart0")
        tasmota.remove_timer("LoadIconPart1")
        self.Iconbuffer1=[]
        self.Iconbuffer2=[]
        self.Currentbuffer=0
    end



end

return IconHandler