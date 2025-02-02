"""
Template for exporting ULP code to Tasmotas Berry implementation
Just do a cat template1st assemblercode.s template2nd >code.py to generate the py-file
"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
# Just to read out time-register and calibration

# from components/soc/esp32/register/soc/reg_base.h
#define DR_REG_RTCCNTL_BASE                     0x3ff48000
# from components/soc/esp32/register/soc/rtc_cntl_reg.h
#define RTC_CNTL_TIME0_REG          (DR_REG_RTCCNTL_BASE + 0x10)
#define RTC_CNTL_STATE0_REG          (DR_REG_RTCCNTL_BASE + 0x18)
#define RTC_CNTL_ULP_CP_SLP_TIMER_EN  (BIT(24))
#define RTC_CNTL_TIME_UPDATE_REG         (DR_REG_RTCCNTL_BASE + 0xc)
#define RTC_CNTL_TIME_UPDATE_S  31
#define RTC_CNTL_TIME_VALID_S  30
#define RTC_CNTL_STORE1_REG          (DR_REG_RTCCNTL_BASE + 0x50)


.data
.global time
time:
    .long 0
    .long 0
.global calibration
calibration:
    .long 0
    .long 0

.text
.global entry
entry:
    # next poke the RTC-controlle to update the time register
    WRITE_RTC_REG(RTC_CNTL_TIME_UPDATE_REG, RTC_CNTL_TIME_UPDATE_S, 1, 1)
    jump check_time_valid
check_time_valid:
    /* Check if RTC_CNTL_TIME_VALID bit is 1, otherwise repeat */
    READ_RTC_REG(RTC_CNTL_TIME_UPDATE_REG, RTC_CNTL_TIME_VALID_S, 1)
    AND R0, R0, 1
    JUMP check_time_valid, EQ

    # r0 is used for reading register, r1 will be used for the memory adressing
    move r1, time # get the address of the list into r1
    # read the RTC-register for time
    # get the lower 16 bit from the RTC-register into r0
    READ_RTC_REG(RTC_CNTL_TIME0_REG, 0, 16)
    # then store the value in the list
    st r0, r1, 0
    # get the higher 16 bit from the RTC-register
    READ_RTC_REG(RTC_CNTL_TIME0_REG, 16, 16)
    # save the value in the list in next word
    st r0, r1, 4 # store the value in next word (we have words, but can only store in lower 16 bits), offset is in bytes, so we need 4 here
    # save calibration
    move r1, calibration
    READ_RTC_REG(RTC_CNTL_STORE1_REG, 0, 16)
    st r0, r1, 0
    READ_RTC_REG(RTC_CNTL_STORE1_REG, 16, 16)
    st r0, r1, 4
    # halt the ULP-timer, so it will not run again
    #  Please note: an ULP.run() from Tasmota will autmatically enable the ULP-timer again!
    WRITE_RTC_REG(RTC_CNTL_STATE0_REG, RTC_CNTL_ULP_CP_SLP_TIMER_EN, 1, 0) #disable ULP Sleep-Timer
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
