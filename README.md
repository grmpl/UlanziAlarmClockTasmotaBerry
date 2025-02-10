# Tasmota-Ulanzi-AlarmClock with ULP-based buzzer
Tasmota Berry Implementation of an Alarm Clock on a Ulanzi TC001 with a ULP-based buzzer.

The code is based on the works of https://github.com/iliaan/ulanzi-lab and https://github.com/Hypfer/ulanzi-tc001-tasmota . Thanks a lot to them.

I'm no professional programmer, so excuse some crappy coding. ;-)

**This branch is only working with ULP-support compiled into Tasmota!** If you do not want to compile Tasmota, you can use the branch "buzzeroptimization", but I will not continue working on this branch.

The ULP-Buzzer was introduced, as the berry code is running too long and buzzer-intervals are highly irregular. It would have been very complicated to reduce the berry code to many small parts running independently and result will still have been unclear. With ULP-based buzzer the buzzer intervals will be independent of berry code running.

## Installation
Flashing Tasmota firmware on your device may potentially brick or damage the device. It is important to proceed with caution and to understand the risks involved before attempting to flash the firmware. Please note that any modifications to the device's firmware may void the manufacturer's warranty and may result in permanent damage to the device. It is strongly recommended to thoroughly research the flashing process and to follow instructions carefully. The user assumes all responsibility and risk associated with flashing the firmware.

1. **You must compile Tasmota with ULP-Support for this branch!**  
You can add RTC-support, too, if you are already compilint. See Additional Information below.
2. Flash the compiled Tasmota on your Ulanzi TC001.
3. Set Template and Module according to https://templates.blakadder.com/ulanzi_TC001.html, but set ID=2 on GPIO32.
4. ~~Set Pixel-Number of the Display in Console: `Pixels 256`~~ (The command works only with ID=1 on GPIO32 with WSD2812, and according to my eperience it is not necessary)
5. Stop processing of buttons in Tasmota: `SetOption73 1`
6. Set timezone according to your needs. For Middle Europe it's: `Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120`
7. Set latitude and longitude to your place. For Munich e.g. it's: `backlog latitude 48.138613; longitude 11.573833`
8. Set long button press to your needs, e.g. 2 Seconds: `setoption32 20` (Please note: This will also decrease the time for complete reset to 20 seconds, so don't hold it too long)
9. Upload all the files in berry-directory to Tasmota filesystem. Do not upload autoexec.be yet! You can use filesplit from util.be to upload all files in one go.
10. Check if Scripts are working correctly by running the commands in autoexec.be manually.
11. Add the following rule to tasmota: `ON Clock#Timer=1 DO AlarmActivate 1 ENDON ON Clock#Timer=2 DO AlarmActivate 2 ENDON ON Clock#Timer=3 DO AlarmActivate 3 ENDON  ON Clock#Timer=4 DO AlarmActivate 4 ENDON ` 
12. If everything works, upload autoexec.be from root directory.
13. I would recommend `setoption13 1`, this would make the buttons a lot more responsive. Long press functions are handled by the code even with this option set. Nevertheless the code is written to support `setoption13 0`,too.


## Usage
- Alarm time is controlled by setting Tasmota timers. You can set the timers by Web frontend, MQTT and on the alarm faces.
- Timers 1-4 in Tasmota are available for setting an alarm time. Don't forget to activate timers in general and set timers to repeat if you want to use them more than once.
- Activating and deactivating of timers is possible at the clock.
- You have multiple displays, which you can choose from by pressing left and right button.
- Main display shows time, temperature and an alarm indicator. The alarm indicator is a line of 4 Pixels, where every pixel indicates the status of an alarm time: Red=deactivated, green=activated, yellow=alarm running. If Snooze is active, the indicator first turns completely to blue, then going back to normal color pixel by pixel until Snooze time is ended.
- Next display shows the date. You can switch to big display by pressing the middle button.
- Next display shows the weather at noon and 6 PM for current day. You have to upload icons in pam- or ppm-format with correct filename into tasmota filesystem for this face. See WeatherClockFace.be. I haven't put the icons on github due to possible license issues.
- Next 4 displays show the 4 alarm times. You can activate/deactivate the alarm by pressing the middle button. Active alarm is shown by a green clock, deactivated alarm by a red clock. The indicator in the middle tells you which of the 4 alarm times you are seeing.  
Editing of alarm is possible by long press of middle button. The value to be changed (hour, minute, repeat) is set to different color, it can be changed with left and right button. Short press of middle butten switches to next value, long press saves new timer setting. Don't expect too much. It is not performant, quick button presses are not possible, long press/fast change is not implemented. So you have to be patient. It's for the usecases where you don't have your smartphone at hand.
- If alarm starts, buzzer will beep. Beeping will start slowly and repetition intervall will be increased in time. During alarm *any* button press on any face will activate Snooze.
- Long press on middle button on all faces will stop alarm until next timer fires.
- An additional button on the main web page will give you the possibility to stop an alarm remotely.


## Additional information
- `setoption13 1` will not allow for multipress and safety actions like reset by very long press or switch Wifi by 6x-press. As there is easy serial access to the clock, I don't think these safety actions are necessary. If you want to keep the safety actions, you have to use `setoption13 0` which will result in laggy button reaction as system always has to wait some time to determine if it is a multiple press. Be aware that impatient button usage my lead to unwanted reset or wifi switch in this case.  
- You can set a rule which will fire a MQTT-message or anything like that in case a Timer is triggered and the ClockfaceManager is not working: `ON INPUT=AlarmActivate DO var6 99 ENDON ON COMMAND=UNKNOWN DO IF ( var6 == 99 ) var7 ALARM; var6 0 ELSE var6 0 ENDIF ENDON`. (Maybe it could be written in a better way, the problem is: The alarm must only go on, if the error is an unknown command "AlarmActivate" - the corresponding JSON is `{"Command":"Unknown","Input":"ALARMACTIVATE"}`)
- Concerning compiling: TasmoCompiler worked for me best. It created a small and very stable build. I experienced many WIFI reconnects on the Ulanzi with the official tasmota32.bin, even when the ClockfaceManager wasn't running (especially during file upload). My user_config_override.h created from scratch wasn't much better. With TasmoCompiler I could stick to the bare necessities: Rules, WS2812 LEDs, Temp/Hum sensors, SD Card/Little FS, Timers, Light sensors, Berry scripting, ULP-support and Web interface. I even added telegram and ping. As neither RTC nor ULP is included in any feature group and buzzer is included in feature group LVGL (which we don't need) you have to use custom parameters:
```    
        #ifndef USE_RTC_CHIPS
        #define USE_RTC_CHIPS
        #define USE_DS3231
        #endif


        #ifndef USE_BUZZER
        #define USE_BUZZER
        #endif
        
        #ifndef USE_BERRY_ULP 
        #define USE_BERRY_ULP      // (ESP32, ESP32S2 and ESP32S3 only) Add support for the ULP via Berry (+5k flash)
        #endif
```



