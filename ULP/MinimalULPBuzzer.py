"""
Template for exporting ULP code to Tasmotas Berry implementation
Just do a cat template1st assemblercode.s template2nd >code.py to generate the py-file
"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
# Testprogram to test buzzer action with fixed values
# ULP.gpio_init(gpio.pin(gpio.BUZZER),1)
# 
# from components/soc/esp32/include/soc/soc.h
#define DR_REG_RTCCNTL_BASE                     0x3ff48000
#define DR_REG_RTCIO_BASE            0x3ff48400

# from components/soc/esp32/include/soc/rtc_cntl_reg.h
#define RTC_CNTL_STATE0_REG          (DR_REG_RTCCNTL_BASE + 0x18)
#define RTC_CNTL_ULP_CP_SLP_TIMER_EN  (BIT(24))
#define RTC_GPIO_OUT_REG             (DR_REG_RTCIO_BASE + 0x0)
#define RTC_GPIO_OUT_DATA_S          14


.data

.text
.global entry
entry:

# r0 will be used for state
# r0>0 - shut off
jumpr switchofftoon, 0, EQ
# else switch on to off
WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + 13, 1, 0)
# sleep time off
move r0,0
sleep 0
halt


switchofftoon: 
WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + 13, 1, 1)
# sleep time on
move r0,1
sleep 1
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
