"""
Template for exporting ULP code to Tasmotas Berry implementation
Just do a cat template1st assemblercode.s template2nd >code.py to generate the py-file
"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
# This program will activate the GPIO for the buzzer in regular intervals.
#  The intervals will be set by sleeptime, so the timing must not be handled here. This program 
#   just expects to be called in a regular timing.
#  Sleeptime can be modified any time. A currently running sleep-Timer will be changed to new runtime
#   without restarting. I.e. changing from 10 to 20 after 9 seconds runtime will lead to additional 11 sec runtime,
#   and changing from 20 to 10 after 15 seconds of runtime will end timer immediately.
#  As with tasmota buzzer, besides the timing, you can specify the repetitions and a tune.
# Differences to the tasmota buzzer:
#  Parameters will be limited to 16 bit, and trailing zeros in tune will not be ignored, 
#   this will allow for a pause between repetitions.
# The program will save states like counter and tune-pointer, but these states will be kept in the
#  shared memory and can be modified any time by the caller. Modifications will just be handled in 
#  the next cycle. 
# The caller has to make sure, that modifications to the parameters are not overwritten by this program.
#  This can be done by checking contents shortly after setting them, as runtime of this program
#  is short and predictable (<1msec) and sleep time should be >> running time. Or, taking the safe way, 
#  stopping the program, e.g. by setting and then restarting it with new parameters.
#  I do not implement a locking mechanism, as there is no infrastructure like an OS providing this in a safe way
#  and implementing an own solution will generate a lot of additional risks, like deadlocks for example.
# There are several ways for stopping the program which will have different outcomes. Be sure to choose the right one
#  - Calling ResetRTCGPIO on ULP - this will stop the buzzer immediately, initialize the memory incl. registers and give the buzzer back to Tasmota
#     you must call gpio_init again before running BuzzerULP!
#  - Calling StopULPBuzzer on ULP - this will stop the buzzer immediately and initialize the memory including registers, it will not give the buzzer back to Tasmota
#     this is the only safe way of starting a new buzzer tune immediately!
#  - Setting counter to 0: This will stop buzzer in next run, keeping tune_pointer and tune in memory and will not touch registers.
#     It can take up to sleeptime until buzzer is shut off!
#     As counter could be modified by program, change of counter must be verified!
#     Use with care due to possible unforeseen side effects! Only recommended if pausing without reset is required.
#  - Setting tune to 0: This will stop buzzer in the next run after tune has finished. Counter should be 0, tune_pointer back to 0x8000
#     This is a slow, controlled exit. Runtime is hard to predict and could be very long!
#     Before starting another buzzer activity, StopULPBuzzer should be called.
# These are the best ways to handle some scenarios:
#  - Play a buzzing tune, independent of current state: 
#    1) Stop ULP-Buzzer by running StopULPBuzzer - this would make sure, there are no conflicts with a running buzzer
#    2) Load ULPBuzzer
#    3) Initialize parameters and wakeperiod
#    4) run ULPBuzzer
#  - Change the tune while a tune is already playing:
#    1) Just Change tune
#    2) ULPBuzzer will play new tune when last has finished - this behaviour avoids any irregularities during change
#    3) Please be aware: If counter runs out or no tune is running, new tune will not be played, so this has to be checked first
#  - Stop current buzzer immediately:
#    1) Just call StopULPBuzzer
#  - Stop buzzer after tune has finished:
#    1) Set tune to 0 - tune will never be modified by the ULPBuzzer and tune will only be checked when tune_pointer=0x8000
#  - Change the counter to a new value, without disturbing a currently running rythm, but ensuring it will be played even if current tune is finished or not running
#    Now this is tricky, as the only way to run a buzzer when it is not running is by calling ULP.run() and as this is running it immediately,
#     any current playing will be disturbed. So you have to check for current running buzzer before calling ULP.run()
#    1) Make sure, sleeptime>5msec - sleeps <5msec do not make sense and it gives us time to change things
#    2) Read counter
#    3) If counter=0 current tune will not be played again, ULPBuzzer has either stopped or will stop in next cycle without doing anything
#          so we could run ULP.run() without disturbing a running tune. As we have to modify counter first, there is a small chance
#           old tune will be started before run is executed, but that should only be a slight disturbance <2msec and not worth any additional effort
#       If counter > 0 we do have time to change things. It will be at least sleeptime, because even if counter just switches to 0, 
#        evaluation will be done only in the next cycle. We just have to make sure counter is changed and not overwritten by a currently running ULPBuzzer
#       3a) if counter=0 call ULP.run
#       3b) if counter >0 change counter to at least 2
#       3c) wait 2msec (>max runtime of ULPBuzzer <sleeptime)
#       3d) check counter if counter <> saved counter || saved counter-1 (ULPBuzzer could have started and finished once in last 2msec) - set it again
#  - Play a short beep but keep current tune running:
#    Simple way:
#    1) read and save current tune_pointer, counter, tune
#    2) run StopULPBuzzer
#    3) Load ULPBuzzer, set counter, tune to beep
#    4) Start ULPBuzzer
#    5) Wait for beep to end (2x sleep time!
#    6) Restore counter, tune_pointer, tune
#    7) Start ULPBuzzer again
#    Difficult way:
#    0) make sure you are in sleeptime and have time for modifications by temporarily extending sleeptime
#    00) wait 2msec to make sure, potentially running program has ended
#    1) read tune_pointer, tune
#    2) modify tune: add additional on-time at tune_pointer and clear all bits already played
#    3) set tune_pointer to 0x8000 to force reading of new tune
#    4) call ULP.run() for immediate buzzing
#    5) wait 2msec for current run to end 
#    6) change sleeptime and tune back to old value - should be enough time until it is read in again.

# from components/soc/esp32/include/soc/soc.h
#define DR_REG_RTCCNTL_BASE                     0x3ff48000
#define DR_REG_RTCIO_BASE            0x3ff48400

# from components/soc/esp32/include/soc/rtc_cntl_reg.h
#define RTC_CNTL_STATE0_REG          (DR_REG_RTCCNTL_BASE + 0x18)
#define RTC_CNTL_ULP_CP_SLP_TIMER_EN  (BIT(24))
#define RTC_GPIO_OUT_REG             (DR_REG_RTCIO_BASE + 0x0)
#define RTC_GPIO_OUT_DATA_S          14
# defining GPIO-number of buzzer dynamically would be much effort,
#  so the number is defined statically
# it's the output of ULP.gpio_init(gpio.pin(gpio.BUZZER),1)
#define BUZZERGPIO                   13 


.data
.global counter # will be set by the caller
counter: 
    .long 0

.global tune
tune: 
    .long 2 # this is the minimal tune, but it must always be set by the caller

.global tune_pointer
tune_pointer: 
    .long 0x8000 # initialized at 1000 0000 0000 0000, handled by the program, but modifiable by the caller

.global timeroverride
timeroverride: # this will change sleep time in sync with changed tune
    .long 0 # low bit sleep 0 - offtime
    .long 0 # high bit sleep 0 - ontime
    .long 0 # low bit sleep 1 - offtime
    .long 0 # high bit sleep 1 - ontime

.global timersave
timersave: # this is to save time if changed
    .long 0 # low bit sleep 0 - offtime
    .long 0 # high bit sleep 0 - ontime
    .long 0 # low bit sleep 1 - offtime
    .long 0 # high bit sleep 1 - ontime

.global returnvalue
returnvalue:
    .long 0

.text
.global entry
entry:
    # general register usage:
    # r0: adresses for load/store, temporary storage, needed for comparison
    # r1: counter
    # r2: tune 
    # r3: tune_pointer
    # values are loaded into r0 if comparison is necessary
    
    # check for counter, if counter <=0 do nothing
    move r0, counter
    ld r0, r0, 0
    jumpr exit, 0, LE # r0 <= 0
    # save counter in r1
    move r1, r0 

    # load tune_pointer, tune will only be read at start of tune
    move r0, tune_pointer
    ld r0, r0, 0
    jumpr tune_pointer_regsave, 0, LT # everything all right
    jumpr tune_pointer_regsave, 0, GT # everything all right
    move r0, 0x8000 # something went wrong, correct tune_pointer to 0x800
tune_pointer_regsave:
    move r3,r0 # store at correct register

    # preceding bits in tune with 0 must be ignored, this will allow to play tunes < 16 bit, too
    #  So, if we start in tune_pointer from 1000 0000 0000 0000, we proceed until the first 1 is found
    #  otherwise if tune_pointer is anywhere other than 0x8000, we assume searching was done already
    # tune_pointer is still at r0
    jumpr search1, 0x8000, EQ
sfound:
    # found first 1, or being in the middle of the tune, so check if switch buzzer on or off
    # r0 is used for result, as we do not want to overwrite the other registers
    and r0, r2, r3
    jump switchoff, EQ # bit in tune at pointer is 0, we have to jump to Off-routine

switchon:
    # bit is 1, switch buzzer on
    WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + BUZZERGPIO, 1, 1)
    sleep 1 # choose on-time which must be saved in Sleep-Register 1
    jump halting # subroutine to prepare for next cycle

switchoff:
    # switch buzzer off
    WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + BUZZERGPIO, 1, 0)
    sleep 0 # choose off-time which must be saved in Sleep-Register 0
    jump halting # subroutine to prepare for next cycle

# Prepare for next cycle 
halting:
    # shift tune_pointer to the next bit, if tune_pointer is 0, tune is finished
    #  then we have to decrement counter and set tune_pointer to 0x8000 again
    rsh r3, r3, 1
    jump nextcount, EQ
    # Debugging only ####################
    # move r0,returnvalue
    # st r2,r0,0
    # ###################################
    # otherwise store new tune_pointer and wait for next cycle
    move r0, tune_pointer
    st r3, r0, 0 
    halt

nextcount:
    # we do not stop the buzzer! If there is a 1 at the end of tune, buzzer will keep being active until 1st 0 in next tune-cycle
    # decrement counter - 
    sub r1, r1, 1
    # store the new counter value
    move r0, counter
    st r1, r0, 0
    # set tune_pointer to beginning
    # we always start at beginning, as tune could change until next cycle
    move r3,0x8000
    # and store the new value
    move r0, tune_pointer
    st r3, r0, 0
    halt


# Subroutine to find the first 1 in the tune
search1:
    # Load tune
    move r0, tune
    ld r0, r0, 0 
    jumpr slowexit, 0, EQ # with tune=0 we will not count down the counter, but it will stop slowly at next cycle
    move r2,r0 # otherwise store at correct register
    # tbd: check for timer-override and save it #########################################################################
nextsearch:
    # tune is at r3, tune_pointer at r2, but we do not want to modify them, so use r0 as result of comparison
    and r0, r2, r3
    jump 0found, EQ # last operation resulted in 0 - loop until 1 is found
    jump sfound # otherwise continue with main program
0found:
    rsh r3, r3, 1 # move tune_pointer to the next bit
    jump nextsearch

slowexit:
    # just set counter to 0 and wait for next cycle
    move r1,0
    move r0, counter
    st r1, r0, 0
    sleep 0
    halt

# End of cycles 
exit:
    move r0, returnvalue
    move r1,99
    st r1,r0,0

    # ensure counter is set to 0
    move r0, counter
    move r1,0
    st r1,r0,0

    # switch buzzer off
    WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + BUZZERGPIO, 1, 0)
    # avoid running the program again
    WRITE_RTC_REG(RTC_CNTL_STATE0_REG, RTC_CNTL_ULP_CP_SLP_TIMER_EN, 1, 0) 
    # De-init of RTC-GPIO must be done manually by ResetRTCGPIO - it doesn't make sense to cal gpio_init every time
    halt

"""

binary = src_to_binary(source,cpu="esp32")

# Export section for Berry
code_b64 = ubinascii.b2a_base64(binary).decode('utf-8')[:-1]

file = open ("ulp_template.txt", "w")
file.write(code_b64)

print("")
# For convenience you can add Berry commands to rapidly test out the resulting ULP code in the console
# This could also be used in an init function of a Tasmota driver
print("#You can paste the following snippet into Tasmotas Berry console:")
print("import ULP")
print("ULP.wake_period(0,500000)")
print("var c = bytes().fromb64(\""+code_b64+"\")")
print("ULP.load(c)")
print("ULP.run()")
