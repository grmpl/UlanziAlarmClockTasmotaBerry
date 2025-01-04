import string

import BaseClockFace

class DateClockFace: BaseClockFace
    var clockfaceManager
    var matrixController
    var showYear

    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.showYear = true
    end

    def handleActionButton()
        self.showYear = !self.showYear
    end

    def render()
        self.matrixController.clear()
        var time_data = tasmota.rtc("local")
        var x_offset = 3
        var y_offset = 0

        var date_str = ""
        if self.showYear != true
            self.matrixController.change_font('Glance')
            date_str = tasmota.strftime("%d.%m.",time_data)
            self.matrixController.print_string(date_str, x_offset, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
        else
            self.matrixController.change_font('MatrixDisplay3x5')
            x_offset = 5
            y_offset = 1
            date_str = tasmota.strftime("%d",time_data)
            self.matrixController.print_string(date_str, x_offset, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            date_str = tasmota.strftime("%m",time_data)
            self.matrixController.print_string(date_str, x_offset+10, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            date_str = tasmota.strftime("%y",time_data)
            self.matrixController.print_string(date_str, x_offset+20, y_offset, true, self.clockfaceManager.color, self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(x_offset+8, y_offset+4, self.clockfaceManager.color, self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(x_offset+18, y_offset+4, self.clockfaceManager.color, self.clockfaceManager.brightness)
        
            # Icon
            self.matrixController.set_matrix_pixel_color(0, 1, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(1, 1, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(2, 1, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(3, 1, 0xff0000,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(0, 2, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(1, 2, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(2, 2, 0xffffff,self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(3, 2, 0xffffff,self.clockfaceManager.brightness)
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
        
        end

        
    end
end

return DateClockFace
