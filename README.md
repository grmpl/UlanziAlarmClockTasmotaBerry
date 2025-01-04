# Tasmota-Ulanzi-AlarmClock
Tasmota Berry Implementation of an Alarm Clock on a Ulanzi TC001

The code is based on the works of https://github.com/iliaan/ulanzi-lab and https://github.com/Hypfer/ulanzi-tc001-tasmota . Thanks a lot to them.

This is just a rough implementation, I'm no professional programmer and testing was not done yeth for longer time. Don't expect too much of this. There shouldn't be much errors, but performance is poor and during testing I experienced Wifi instability with the Ulanzi (maybe due to high CPU or memory usage).

Nevertheless it seems to be working stable. :-)

## Installation
Flashing Tasmota firmware on your device may potentially brick or damage the device. It is important to proceed with caution and to understand the risks involved before attempting to flash the firmware. Please note that any modifications to the device's firmware may void the manufacturer's warranty and may result in permanent damage to the device. It is strongly recommended to thoroughly research the flashing process and to follow instructions carefully. The user assumes all responsibility and risk associated with flashing the firmware.


1. Flash Tasmota on your Ulanzi TC001. (You should compile an own build with support for the real time clock in the Ulanzi: https://tasmota.github.io/docs/DS3231/, otherwise your alarm clock will need network to set the time after reset)
2. Set Template and Module according to https://templates.blakadder.com/ulanzi_TC001.html
4. Set Pixel-Number of the Display in Console: `Pixels 256` (Please note: This is only possible with ID=1 on GPIO32 with WSD2812)
5. Stop processing of buttons in Tasmota: `SetOption73 1`
6. Set timezone according to your needs. For Middle Europe it's: `Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120`
7. Set latitude and longitude to your place. For Munich e.g. it's: `backlog latitude 48.138613; longitude 11.573833`
8. Set long button press to your needs, e.g. 2 Seconds: `setoption32 20` (Please note: This will also decrease the time for setting reset to 20 seconds)
9. Upload all the files in berry-directory to Tasmota filesystem. Do not upload autoexec.be yet!
10. Check if Scripts are working correctly by running the commands in autoexec.be manually.
11. Add the following rule to tasmota: `ON Clock#Timer=1 DO AlarmActivate 1 ENDON ON Clock#Timer=2 DO AlarmActivate 2 ENDON ON Clock#Timer=3 DO AlarmActivate 3 ENDON  ON Clock#Timer=4 DO AlarmActivate 4 ENDON ` 
12. If everything works, upload autoexec.be from root directory.



## Usage
- Setting alarm time is only possible by setting Tasmota timers. You can set the timers by Web frontend or MQTT.
- Timers 1-4 in Tasmota are available for setting an alarm time. Don't forget to activate timers in general and set timers to repeat if you want to use them more than once.
- Activating and deactivating of individual timers is possible at the clock.
- You have multiple displays, which you can choose from by pressing left and right button.
- Main display shows time, temperature and an alarm indicator. The alarm indicator is a line of 4 Pixels, where every pixel indicates the status of an alarm time: Red=deactivated, green=activated, yellow=alarm running. If Snooze is active, the indicator first turns completely to blue, then going back to normal color pixel by pixel until Snooze time is ended.
- Next display shows the date. You can switch to big display by pressing the middle button.
- Next 4 displays show the 4 alarm times. You can activate/deactivate the alarm by pressing the middle button. Active alarm is shown by a green clock, deactivated alarm by a red clock. The indicator in the middle tells you which of the 4 alarm times you are seeing.
- If alarm starts, buzzer will beep. Beeping will start slowly and repetition intervall will be repeated in time. During alarm *any* button press will activate Snooze.
- Long press on middle button will stop alarm until next timer fires.
- An additional on the main web page will give you the possibility to stop an alarm remotely.


## Additional information
- You can set a rule which will fire a MQTT-message or anything like that in case a Timer is triggered and the ClockfaceManager is not working: `ON INPUT=AlarmActivate DO var6 99 ENDON ON COMMAND=UNKNOWN DO IF ( var6 == 99 ) var7 ALARM; var6 0 ELSE var6 0 ENDIF ENDON`. (Maybe it could be written in a better way, the problem is: The alarm must only go on, if the error is an unknown command "AlarmActivate" - the corresponding JSON is `{"Command":"Unknown","Input":"ALARMACTIVATE"}`)


