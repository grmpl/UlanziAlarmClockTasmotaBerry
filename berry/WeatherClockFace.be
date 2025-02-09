import BaseClockFace
import Weather
import string
import persist

class WeatherClockFace: BaseClockFace


    var weather
    var weathericon 
    var weatherfile

    def init(clockfaceManager)
        super(self).init(clockfaceManager)
        self.matrixController.clear()
        self.weather = Weather()
        self.weathericon=[[nil],[nil]]
        self.weatherfile=["",""]
    end

    def handleActionButton()
        tasmota.cmd("_buzzer")
    end

    def render()
        self.matrixController.clear()
        var rtc = tasmota.rtc()

        var temp = [99,99]
        var temp_neg = [false,false]
        var temp_str = ["--","--"]
        var temp_color = [0xfc4300,0xfc4300]
        var wmocode=[99,99]



        #var temp_color=0xff00a0
        var forecastresult = self.weather.get_forecast()
        if forecastresult != nil 
            
            wmocode = [forecastresult['weather_code'][4],forecastresult['weather_code'][6]]
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
                
        self.matrixController.change_font('MatrixDisplay3x5')
        for iconnumber:0..1
            var xoffset=iconnumber*16
        # Display temperature
            self.matrixController.print_string(temp_str[iconnumber],8 + xoffset,3, false, temp_color[iconnumber], self.clockfaceManager.brightness)
        
            if temp_neg[iconnumber] 
                self.matrixController.set_matrix_pixel_color((10 + xoffset), 1, temp_color[iconnumber], self.clockfaceManager.brightness)
                self.matrixController.set_matrix_pixel_color((11 + xoffset), 1, temp_color[iconnumber], self.clockfaceManager.brightness)
                self.matrixController.set_matrix_pixel_color((12 + xoffset), 1, temp_color[iconnumber], self.clockfaceManager.brightness)
            end


        # Display weather icon
            var wmo=wmocode[iconnumber]
            if wmo == 1 || wmo == 2 || wmo == 3 || wmo == 45 || wmo == 48
                # cloudy (1-3) /fog (45,48)
                if ( self.weatherfile[iconnumber] == "cloudy.pam" ) && ( self.weathericon[iconnumber] != nil )
                    self.drawicon(self.weathericon[iconnumber],xoffset,0)
                else
                    log("WeatherClockFace: weatherfile=" + self.weatherfile[iconnumber] + " weahtericon=" + str(self.weathericon[iconnumber]) + " must load again",4)
                    self.weatherfile[iconnumber]="cloudy.pam"
                    self.weathericon[iconnumber] = self.loadicon("cloudy.pam")
                    if self.weathericon[iconnumber] != nil
                        self.drawicon(self.weathericon[iconnumber],xoffset,0)
                    else 
                        log("WeatherClockFace: Couldn't load icon!",1)
                    end
                end                    

            elif wmo == 51 || wmo == 53 || wmo == 55 || wmo == 56 || wmo == 57 ||
                wmo == 61 || wmo == 63 || wmo == 65 || wmo == 66 || wmo == 67 ||
                wmo == 80 || wmo == 81 || wmo == 82 || wmo == 95 || wmo == 96 || wmo == 99
                # rain, 56,57,66,67 with ice, 95,96,99 thunderstorm
                if ( self.weatherfile[iconnumber] == "rainy.pam" ) && ( self.weathericon[iconnumber] != nil )
                    self.drawicon(self.weathericon[iconnumber],xoffset,0)
                else
                    self.weatherfile[iconnumber]="rainy.pam"
                    self.weathericon[iconnumber] = self.loadicon("rainy.pam")
                    if self.weathericon[iconnumber] != nil
                        self.drawicon(self.weathericon[iconnumber],xoffset,0)
                    else 
                        log("WeatherClockFace: Couldn't load icon!",1)
                    end
                end                    
            elif wmo == 71 || wmo == 73 || wmo == 75 || wmo == 77 || wmo == 85 || wmo == 86
                # snow
                if ( self.weatherfile[iconnumber] == "snowfall.pam" ) && ( self.weathericon[iconnumber] != nil )
                    self.drawicon(self.weathericon[iconnumber],xoffset,0)
                else
                    self.weatherfile[iconnumber]="snowfall.pam"
                    self.weathericon[iconnumber] = self.loadicon("snowfall.pam")
                    if self.weathericon[iconnumber] != nil
                        self.drawicon(self.weathericon[iconnumber],xoffset,0)
                    else 
                        log("WeatherClockFace: Couldn't load icon!",1)
                    end
                end                    

            elif wmo == 0
                # sunny
                if ( self.weatherfile[iconnumber] == "sunny.pam" ) && ( self.weathericon[iconnumber] != nil )
                    self.drawicon(self.weathericon[iconnumber],xoffset,0)
                else
                    self.weatherfile[iconnumber]="sunny.pam"
                    self.weathericon[iconnumber] = self.loadicon("sunny.pam")
                    if self.weathericon[iconnumber] != nil
                        self.drawicon(self.weathericon[iconnumber],xoffset,0)
                    else 
                        log("WeatherClockFace: Couldn't load icon!",1)
                    end
                end                    

            else
                # unknown
                if ( self.weatherfile[iconnumber] == "unknown.pam" ) && ( self.weathericon[iconnumber] != nil )
                    self.drawicon(self.weathericon[iconnumber],xoffset,0)
                else
                    self.weatherfile[iconnumber]="unknown.pam"
                    self.weathericon[iconnumber] = self.loadicon("unknown.pam")
                    if self.weathericon[iconnumber] != nil
                        self.drawicon(self.weathericon[iconnumber],xoffset,0)
                    else 
                        log("WeatherClockFace: Couldn't load icon!",1)
                    end
                end                    
            end
        end
    
        
    end

end

return WeatherClockFace
