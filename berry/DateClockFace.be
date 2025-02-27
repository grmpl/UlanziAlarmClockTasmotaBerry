import string
import persist

import BaseClockFace
import IconHandler

class DateClockFace: BaseClockFace
    var iconHandler
    var showYear

    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.showYear = false
        self.iconHandler = IconHandler()
    end

    def deinit()
        self.iconHandler.stopiconlist()
        self.matrixController.clear(true)
    end

    def handleActionButton(value)
        var so13 = tasmota.get_option(13)
        if ( so13 == 1 && value == 15 ) || (so13 == 0) # for setoption13=1 react on clear only
            self.showYear = !self.showYear
        end
    end

    def render()
        self.matrixController.clear()
        var time_data = tasmota.rtc("local")
        var x_offset = 3
        var y_offset = 1


        var date_str = ""
        if persist.member('snooze') == 1  # Snooze indicator
            self.matrixController.set_matrix_pixel_color(31, 0, 0x0000ff,self.clockfaceManager.brightness)
        end
        if self.showYear != true
            var iotdlist = persist.member("iotdlist")
            if !self.iconHandler.IconlistRunning || self.iconHandler.Iconlist != iotdlist
                self.iconHandler.stopiconlist()
                self.matrixController.clear(true)
                self.iconHandler.starticonlist(persist.member('iotdlist'),0,0,40,self.clockfaceManager,"DateCFDrawid") 
            end

            self.matrixController.change_font('MatrixDisplay3x5')
            x_offset = 12
            y_offset = 2
            date_str = tasmota.strftime("%d",time_data)
            self.matrixController.print_string(date_str, x_offset, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            date_str = tasmota.strftime("%m",time_data)
            self.matrixController.print_string(date_str, x_offset+10, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(x_offset+8, y_offset+4, self.clockfaceManager.color, self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(x_offset+18, y_offset+4, self.clockfaceManager.color, self.clockfaceManager.brightness)
        else
            self.iconHandler.stopiconlist()
            self.matrixController.clear(true)
            self.matrixController.change_font('MatrixDisplay3x5')
            x_offset = 5
            y_offset = 2
            date_str = tasmota.strftime("%d",time_data)
            self.matrixController.print_string(date_str, x_offset, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            date_str = tasmota.strftime("%m",time_data)
            self.matrixController.print_string(date_str, x_offset+10, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            date_str = tasmota.strftime("%y",time_data)
            self.matrixController.print_string(date_str, x_offset+20, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(x_offset+8, y_offset+4, self.clockfaceManager.color, self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(x_offset+18, y_offset+4, self.clockfaceManager.color, self.clockfaceManager.brightness)
        
            #Date Icon - should be changed to drawsimpleicon
            self.matrixController.set_matrix_pixel_color(0, 2, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(1, 2, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(2, 2, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(3, 2, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(0, 3, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(1, 3, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(2, 3, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(3, 3, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(0, 4, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(1, 4, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(2, 4, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(3, 4, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(0, 5, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(1, 5, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(2, 5, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(3, 5, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(0, 6, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(1, 6, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(2, 6, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(3, 6, 0xffffff,self.clockfaceManager.brightness)
        
        end

        
    end
end

return DateClockFace
