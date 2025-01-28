"""
This program  just stops the ULP-Buzzer without giving GPIO back to IOMux
var c = bytes().fromb64("dWxwAAwALAAEAAAAAAHsHQYAYBwGAMAvsQCAcgQAAGgAAIByAQCAcgIAgHIDAIByAABAdAAAALAAAAAA")
ULP.load(c)
ULP.run()

"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
#define DR_REG_RTCCNTL_BASE                     0x3ff48000
#define DR_REG_RTCIO_BASE                       0x3ff48400

#define RTC_CNTL_STATE0_REG          (DR_REG_RTCCNTL_BASE + 0x18)
#define RTC_IO_TOUCH_PAD3_REG          (DR_REG_RTCIO_BASE + 0xa0)
#define RTC_GPIO_OUT_REG             (DR_REG_RTCIO_BASE + 0x0)

#define RTC_CNTL_SLEEP_EN  (BIT(31))
#define RTC_CNTL_ULP_CP_SLP_TIMER_EN  (BIT(24))
#define RTC_IO_TOUCH_PAD3_MUX_SEL_M  (BIT(19))
#define RTC_GPIO_OUT_DATA_S          14
#define BUZZERGPIO                   13 

.data
.global registercntl
registercntl: .long 0
.text 
.global entry
entry:
WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + BUZZERGPIO, 1, 0) # shut buzzer off
WRITE_RTC_REG(RTC_CNTL_STATE0_REG, RTC_CNTL_ULP_CP_SLP_TIMER_EN, 1,0) #disable ULP Sleep-Timer
# Check if successful
READ_RTC_REG(RTC_CNTL_STATE0_REG, 16, 16)
move r1, registercntl
st r0, r1, 0
# And reset all registers, to avoid any side effects from wrong initialisation
move r0, 0
move r1, 0
move r2, 0
move r3, 0
stage_rst
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
