import math
import json
import fonts

class MatrixController
    # this version is using blend_color to enable continuous transparency - I'm not sure if this is a good idea
    var leds
    # var matrix # matrix does not work correctly, working without matrix
    var foreground 
    var background
    var font
    var font_width
    static var row_size=8
    static var col_size=32
    var long_string
    var long_string_offset

    var prev_color
    var prev_brightness
    var prev_corrected_color

    def init()
        log("MatrixController Init",3)
        #self.row_size = 8
        #self.col_size = 32
        self.long_string = ""
        self.long_string_offset = 0

        self.leds = Leds(
            self.row_size * self.col_size,
            gpio.pin(gpio.WS2812, 1), # Look up the correct GPIO pin for WS2812 with ID 2 (1 in Berry)
            Leds.WS2812_GRB,
            3 # There seems to be an RMT conflict with the default one causing pixel corruption
        )
        self.leds.gamma = false
        # We do not use matrix, as matrix isn't working correctly in Tasmota 14.4
        # self.matrix = self.leds.create_matrix(self.col_size, self.row_size)
        # this does not work: matrix.set_alternate(true)
        # and matrix.set_bytes neither
        # Foreground and background are stored in buffers
        # As we will use blend_color, foreground must be initialized with 0xff000000 - which means max transparency
        self.foreground=bytes(-(self.row_size*self.col_size)*4)
        var fgblank=bytes()
        for i:0..self.col_size-1
            fgblank.add(0xff000000,-4)
        end
        for i:0..self.row_size-1
            self.foreground.setbytes(i*self.col_size*4,fgblank)
        end
        self.background=bytes(-(self.row_size*self.col_size)*3)

        self.change_font('MatrixDisplay3x5')

        self.clear()

        self.prev_color = 0
        self.prev_brightness = 0
        self.prev_corrected_color = 0
    end

    def clear(fg,x,y,w,h)

        if !fg # not foreground
            # Let's try if this works out - blend_color costs time, with this loop we will need ~50msec
            # Alternatively we could handle transparency a either full or no and just set pixels_buffer to foreground, 
            var blank=bytes(-self.col_size*3)
            var fgmerge=bytes(-self.col_size*self.row_size*3) # is speed really worth allocating a complete display buffer? Could be done in lines
            for i:0..self.row_size-1
                self.background.setbytes(i*self.col_size*3,blank)
                for j:0..self.col_size-1
                    fgmerge.set((i*self.col_size+j)*3, self.leds.blend_color( 0x000000, self.foreground.get((i*self.col_size+j)*4,-4)  ) , -3 )
                end
            end
                self.leds.pixels_buffer().setbytes( 0 , fgmerge  ) 
        else 
            if x == nil || x >= self.col_size
                x = 0
            end
            if y == nil || y >= self.row_size
                y = 0
            end
            if w == nil || x+w > self.col_size
                w = self.col_size-x
            end
            if h == nil || y+w > self.row_size
                h = self.row_size-y
            end
            
            var fgblank=bytes()
            for i:1..w
                fgblank.add(0xff000000,-4)
            end
            for i:0..h-1
                if (y+i) % 2 == 1 # odd lines - reverse
                    self.foreground.setbytes(( (y+i+1) * self.col_size - x - w) * 4,fgblank)
                    self.leds.pixels_buffer().setbytes(( (y+i+1) * self.col_size - x - w) * 3,self.background[( (y+i+1) * self.col_size - x - w) * 3..],0,w*3)
                else 
                    self.foreground.setbytes(( (y+i) * self.col_size + x) * 4,fgblank)
                    self.leds.pixels_buffer().setbytes(( (y+i) * self.col_size + x ) * 3,self.background[( (y+i) * self.col_size +x ) * 3..],0,w*3)
                end

            end
        end

    end

    def draw()
        self.leds.show()
    end

    def change_font(font_key)
        self.font = fonts.font_map[font_key]['font']
        self.font_width = fonts.font_map[font_key]['width']
    end

    # x is the column, y is the row, (0,0) from the top left
    def set_matrix_pixel_color(x, y, color, brightness, fg) #
        # background should be controlled by Clockface, foreground can be set by any other routine and will overlay background
        # save and remove alpha-value, to_gamma is not prepared for 4-bytes values
        var alpha = color & 0xff000000
        color = color & 0x00ffffff
        # if y is odd, reverse the order of y (LED-strip is laid in zigzag, matrix with set_alternate doesn't work correctly)
        if y % 2 == 1
            x = self.col_size - x - 1
        end

        if x < 0 || x >= self.col_size || y < 0 || y >= self.row_size
            #log("Invalid pixel: "+str(x)+", "+str(y),3)
            return
        end

        # Cache brightness calculation and gamma correction for this tuple of bri, color
        if brightness != self.prev_brightness || color != self.prev_color
            self.prev_brightness = brightness
            self.prev_color = color
            self.prev_corrected_color = self.to_gamma(color, brightness)
        end

        var pixelnum = x + y*self.col_size
        if !fg
            self.background.set( pixelnum*3 , self.prev_corrected_color, -3 )
            self.leds.pixels_buffer().set( pixelnum*3 , 
                                           self.leds.blend_color( self.prev_corrected_color , 
                                                                  self.foreground.get( pixelnum*4 , -4 ) ) ,
                                           -3 )
        else
            var trgb=self.prev_corrected_color + (0xff000000-alpha) # blend_color needs inverted alpha-value
            self.foreground.set(pixelnum*4 , trgb,-4)
            self.leds.pixels_buffer().set( pixelnum*3 , 
                                           self.leds.blend_color( self.background.get( pixelnum*3 , -3 ), trgb  ) ,
                                           -3 )
        end
        self.leds.dirty()
    end

    # set pixel column to binary value
    def print_binary(value, column, color, brightness)
        for i: 0..7
            if value & (1 << i) != 0
                # print("set pixel ", i, " to 1")
                self.set_matrix_pixel_color(column, i, color, brightness)
            end
        end
    end

    def print_char(char, x, y, collapse, color, brightness)
        var actual_width = collapse ? -1 : self.font_width

        if self.font.contains(char) == false
            log("Font does not contain char: "+str(char),2)
            return 0
        end

        var font_height = size(self.font[char])
        for i: 0..(font_height-1)
            var code = self.font[char][i]
            for j: 0..7
                if code & (1 << (7 - j)) != 0
                    self.set_matrix_pixel_color(x+j, y+i, color, brightness)

                    if j > actual_width
                        actual_width = j
                    end
                end
            end
        end

        return collapse ? actual_width + 1 : actual_width
    end

    def print_string(string, x, y, collapse, color, brightness)
        var char_offset = 0

        for i: 0..(size(string)-1)
            var actual_width = 0

            if x + char_offset > 1 - self.font_width
                actual_width = self.print_char(string[i], x + char_offset, y, collapse, color, brightness)
            end

            if actual_width == 0
                actual_width = 1
            end

            char_offset += actual_width + 1
            self.print_binary(0, x + char_offset, y, color, brightness)
        end
    end

    # Taken straight from the tasmota berry source-code
    # https://github.com/arendst/Tasmota/blob/e9d1e8c7250d89a24ade0c42a64731d6c492bbb2/lib/libesp32/berry_tasmota/src/embedded/leds.be#L158-L172
    def to_gamma(rgbw, bri)
       bri = (bri != nil) ? bri : 100
       var r = tasmota.scale_uint(bri, 0, 100, 0, (rgbw & 0xFF0000) >> 16)
       var g = tasmota.scale_uint(bri, 0, 100, 0, (rgbw & 0x00FF00) >> 8)
       var b = tasmota.scale_uint(bri, 0, 100, 0, (rgbw & 0x0000FF))


       return light.gamma8(r) << 16 |
              light.gamma8(g) <<  8 |
              light.gamma8(b)
    end
end

return MatrixController
