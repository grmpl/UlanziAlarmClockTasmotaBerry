# ULP programs
Beside some small utilities and tests for programming of the ULP-Coprozessor of the ESP32, this folder contains an implementation of the Tasmota-buzzer-command on this ULP: ULPBuzzer.S

Although it is marked as "deprecated" I used the micropython-assembler from esp32_ulp for assembling the programs. 

Code is only tested on **ESP32**!

## ULPBuzzer
This program will activate the GPIO for the buzzer in regular intervals.  
The intervals will be set by sleeptime, so the timing must not be handled in this program. It just expects to be called in a regular timing.

Similar to Tasmota buzzer command this program expects a tune-bitmask which defines on and off states and a counter which defines the repetitions of this tune.  
There is no separate implementation of simple beeps, as these are just simple tunes (i.e. 0x2).  
The tune-bitmask is different from Tasmota-tune:
 1. Only a 16-bit-value is allowed, no 32-bit-value
 2. One bit is reserved for selecting sleeptimers: 0 will use the 0/1-pair, 1 will use the 2/3-pair (off/on)
 3. So only 15 bits of on/off are possible
 3. Trailing 0 will **not** be ignored - they can be used for pausing in between tunes

This program was written to get rid of the inaccurate timing of Tasmota buzzer.  
As control of this buzzer command from Tasmota would lead again to timing problems, the possibility of changing tune and timing "on the fly" without disturbing timing was included:
  - Changing the tune will not take immediate effect, but only after current tune is finished.  
  This ensures you don't have to take care of exact timing when to switch the tune.
  - One can switch between sleeptimer 0=off/1=on and 2=off/3=on with first bit of tune.  
  This ensures changing the tune and timing is an atomic transaction and cannot be disturbed by some freaky timing.

There is no risk of conflicting changes between Tasmota and ULP, as tune-data will never be changed by ULP.  
If you switch timerpairs with tune, you can control tune and timing.

I thought of setting sleeptimer-values directly out ouf ULP. But this is difficult, as REG_WR does not allow dynamic values. So you would have to use some hacks like executable code in data section to make this possible.
  
If any other parameter then tune is changed, the buzzer should be stopped first.  
If you do not stop, you have to take great care of timing. Otherwise your changed variable could be overwritten by the program or unforeseen side effects due to bad timing could occur.

Sleeptimers could be modified any time without risk, but without using tune-change mentioned above, your changes will take effect immediately without any sync to current running tune.

One note: I a timer is already running and you change it with tasmota.wake_period(), new endtime will be calculated from new setting.  
I.e. changing from 10 to 20 after 9 seconds runtime will lead to additional 11 sec runtime and changing from 20 to 10 after 15 seconds of runtime will end timer immediately.

There are several ways for stopping the program which will have different outcomes. Be sure to choose the right one
 - Calling ResetRTCGPIO on ULP - this will stop the buzzer immediately, initialize the memory incl. registers and give the buzzer back to Tasmota. **Attention**: You must call gpio_init again before running BuzzerULP! Otherwise buzzer will not work.
 - Calling StopULPBuzzer on ULP - this will stop the buzzer immediately and initialize the memory including registers, it will not give the buzzer back to Tasmota. This is the only safe way for changing parameters other than tune.
 - Setting tune to 0: This will stop buzzer in the next run after tune has finished.   
This is a slow, controlled exit. Runtime is hard to predict and could be very long! Before starting another buzzer activity, additionally StopULPBuzzer should be called. Useful if you want a "clean" ending of your tune.
 - Not recommended: Setting counter to 0: This will stop buzzer in next run, keeping tune_pointer and tune in memory and will not touch registers.  
 It can take up to sleeptime until buzzer is shut off, so timing is difficult! You have to make sure, your changed counter is not overwritten accidentally! Can't think of a usecase for this.

Always keep in mind, that ULP is running completely separated from Tasmota. Synching both could be tricky.