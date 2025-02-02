"""
Template for exporting ULP code to Tasmotas Berry implementation
Just do a cat template1st assemblercode.s template2nd >code.py to generate the py-file
"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
# This program will activate the GPIO for the buzzer in regular intervals.
#  The intervals will be set by sleeptime, so the timing must not be handled in this program.
#   It just expects to be called in a regular timing.
#
# Count and tune can be changed by changing RTC-SlowMem with ULP.set_mem()
# Tune will only be loaded from memory when previous tune finished, rest of time it will be stay in register
# 

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
    .long 0x4000 # initialized at 0100 0000 0000 0000, handled by the program

.global returnvalue
returnvalue:
    .long 0

.global watchdog
watchdog:
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

    # save 1 to watchdog
    move r0, watchdog
    move r3,999
    st r3,r0,0

    # load tune_pointer, tune will only be read at start of tune, otherwise it will stay in r2
    move r0, tune_pointer
    ld r0, r0, 0
    jumpr tune_pointer_regsave, 0, GT # tune_pointer can only run from 0x4000 to 0x0001, if tune_pointer <=0 something went wrong
    move r0, 0x4000 # correct tune_pointer to 0x4000, first bit will always be 0 in tune_pointer
tune_pointer_regsave:
    move r3,r0 # store tune_pointer at correct register

    # preceding bits in tune with 0 must be ignored, this will allow to play tunes < 16 bit, too
    #  So, if we start in tune_pointer from 0100 0000 0000 0000, we proceed until the first 1 is found
    #  otherwise if tune_pointer is anywhere other than 0x4000, we assume searching was done already
    # tune_pointer is still at r0, no move necessary
    jumpr search1, 0x4000, EQ #
sfound:
    # found first 1, or being in the middle of the tune, so check if switch buzzer on or off
    # tune will be in r2 from previous run or search, we don't reload it!
    # check for 1 in tune (r2) at tune_pointer (r3), r0 is used for result, as we do not want to overwrite the other registers
    and r0, r2, r3
    jump switchoff, EQ # bit in tune at pointer is 0, we have to jump to Off-routine

switchon:
    # bit is 1, switch buzzer on
    WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + BUZZERGPIO, 1, 1)
    # determine which sleeptimer to use by checking first bit
    and r0, r2, 0x8000
    jump sleeptimer1,EQ # first bit = 0
    sleep 3 # use 3 with first bit = 1
    jump halting
sleeptimer1:
    sleep 1 # choose on-time which must be saved in Sleep-Register 1
    jump halting # subroutine to prepare for next cycle

switchoff:
    # switch buzzer off
    WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + BUZZERGPIO, 1, 0)
    # determine which sleeptimer to use
    and r0, r2, 0x8000
    jump sleeptimer0,EQ # first bit = 0
    sleep 2 # first bit = 1
    jump halting
sleeptimer0:
    sleep 0 # choose off-time which must be saved in Sleep-Register 0
    jump halting # subroutine to prepare for next cycle

# Prepare for next cycle 
halting:
    # shift tune_pointer to the next bit, if tune_pointer is 0, tune is finished
    #  then we have to decrement counter and set tune_pointer to 0x8000 again
    # again: do not care about first bit - this will always be 0 in tune_pointer
    rsh r3, r3, 1 # shift r3
    jump nextcount, EQ # if 0 we have finished tune
    # otherwise store new tune_pointer and wait for next cycle
    move r0, tune_pointer
    st r3, r0, 0 # save
    halt

nextcount:
    # tune_pointer should be 0, set it to beginning - we do not start at already found first 1-bit, as tune could change
    move r3,0x4000
    # and store the new value
    move r0, tune_pointer
    st r3, r0, 0
    # we do not stop the buzzer at the end of tune! If there is a 1 at the end of tune, buzzer will keep being active until 1st 0 in next tune-cycle
    # decrement counter - 
    sub r1, r1, 1
    # store the new counter value
    move r0, counter
    st r1, r0, 0
    halt


# Subroutine to find the first 1 in the tune, we jump with tune_pointer=0x4000 into search1
search1:
    # Load tune
    move r0, tune
    ld r0, r0, 0 
    jumpr 0tune, 0, EQ # do not start search on tune=0, as this will result in endless loop! Set tune_pointer=0x0001, switch off, set sleep, nextcount
    jumpr 0tune, 0x8000, EQ # the same for tune=0 with second timerset
    move r2,r0 # otherwise store at correct register
nextsearch:
    # tune is at r3, tune_pointer at r2, but we do not want to modify them, so use r0 as result of comparison
    and r0, r2, r3
    jump 0found, EQ # last operation resulted in 0 - loop until 1 is found
    jump sfound # otherwise continue with main program
0found:
    rsh r3, r3, 1 # move tune_pointer to the next bit
    jump nextsearch
    
0tune:
    move r3, 0x0001 # we skipped search, so set tune_pointer to last bit
    jump switchoff

# End of cycles 
exit:
    move r0, returnvalue
    move r1,99 #0x63
    st r1,r0,0

    # ensure counter is set to 0
    move r0, counter
    move r1,0
    st r1,r0,0
    # and tune_pointer set to 0x400
    move r0, tune_pointer
    move r3, 0x4000
    st r3, r0, 0

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
