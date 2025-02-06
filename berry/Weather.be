import json

class Weather
    var cl
    var last_update_time
    var last_update_time_f
    var weather_cache
    var forecast_cache
    var latitude
    var longitude

    def init()
        self.cl = webclient()
        self.latitude = tasmota.cmd("_latitude")["Latitude"]
        self.longitude = tasmota.cmd("_longitude")["Longitude"]
        log("Using latitude: " + str(self.latitude) + " longitude: " + str(self.longitude),2)
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + str(self.latitude) + "&longitude=" + str(self.longitude) + "&current_weather=true&timezone=auto"
        self.cl.begin(url)

        self.last_update_time = 0
        self.weather_cache = nil
        self.forecast_cache = nil
    end

    def get_weather()
        if self.weather_cache != nil
            if self.last_update_time + 600 > tasmota.rtc()['local']
                return self.weather_cache['current_weather']
            end
        end

        var r = self.cl.GET()
        self.last_update_time = tasmota.rtc()['local']
        if r == 200
            self.weather_cache = json.load(self.cl.get_string())
            return self.weather_cache['current_weather']
        else
            return nil
        end
    end

    def get_forecast()
        if self.forecast_cache != nil
            if self.last_update_time + 600 > tasmota.rtc()['local']
                return self.forecast_cache['hourly']
            end
        end

        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + str(self.latitude) + "&longitude=" + str(self.longitude) + "&hourly=temperature_2m,weather_code&timezone=Europe%2FBerlin&temporal_resolution=hourly_3&forecast_days=1"
        self.cl.begin(url)
        var r = self.cl.GET()
        self.last_update_time_f = tasmota.rtc()['local']
        if r == 200
            self.forecast_cache = json.load(self.cl.get_string())
            return self.forecast_cache['hourly']
        else
            return nil
        end
    end
end


return Weather
