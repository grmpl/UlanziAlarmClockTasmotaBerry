import BaseClockFace
import Weather
import string
import persist

class WeatherClockFace: BaseClockFace


    var weather

    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.weather = Weather()
    end

    def handleActionButton()
        tasmota.cmd("_buzzer")
    end

    def render()
        self.matrixController.clear()
        var rtc = tasmota.rtc()

        var temp
        var temp_neg
        var temp_str
        var temp_color
        var wmocode12
        var wmocode18

        temp = [99,99]
        temp_neg = [false,false]
        temp_str = ["--","--"]
        temp_color=[0xfc4300,0xfc4300]

        #var temp_color=0xff00a0
        var forecastresult = self.weather.get_forecast()
        if forecastresult != nil 
            temp = [forecastresult['temperature_2m'][4],forecastresult['temperature_2m'][6]]
            if temp[0] != nil
                if temp[0] < 0
                   temp[0] = temp[0] * -1
                   temp_neg[0] = true
                   temp_color[0]=0x0000ff
                end
            end
            if temp[1] != nil
                if temp[1] < 0
                   temp[1] = temp[1] * -1
                   temp_neg[1] = true
                   temp_color[1]=0x0000ff
                end
            end


            temp_str[0] = string.format("%2.0f",temp[0])
            temp_str[1] = string.format("%2.0f",temp[1])
        end
                
        # Display temperature
        self.matrixController.change_font('MatrixDisplay3x5')
        self.matrixController.print_string(temp_str[0],8,3, false, temp_color[0], self.clockfaceManager.brightness)
        self.matrixController.print_string(temp_str[1],24,3, false, temp_color[1], self.clockfaceManager.brightness)
        
        if temp_neg[0] 
            self.matrixController.set_matrix_pixel_color(10, 1, temp_color[0], self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(11, 1, temp_color[0], self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(12, 1, temp_color[0], self.clockfaceManager.brightness)
        end

        if temp_neg[1] 
            self.matrixController.set_matrix_pixel_color(26, 1, temp_color[1], self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(27, 1, temp_color[1], self.clockfaceManager.brightness)
            self.matrixController.set_matrix_pixel_color(28, 1, temp_color[1], self.clockfaceManager.brightness)
        end

  
        
    end

end

return WeatherClockFace
