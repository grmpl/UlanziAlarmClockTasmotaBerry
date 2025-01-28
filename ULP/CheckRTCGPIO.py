"""
Just to check which register is changed by ULP.gpio_init()
Result: RTC_IO_TOUCH_PAD3_REG is modified by ULP.gpio_init(gpio.pin(gpio.BUZZER),1)

Berry-Commands:
import ULP
var c = bytes().fromb64("dWxwAAwAHAAIAAAAJwGwLXEAgHIEAABoKAGwLYEAgHIEAABoAAAAsAAAAAAAAAAA")
ULP.load(c)
ULP.run()
ULP.get_mem(7) # RTC_IO_TOUCH_PAD2_REG (12-28)
ULP.get_mem(8) # RTC_IO_TOUCH_PAD3_REG (12-28)
ULP.gpio_init(gpio.pin(gpio.BUZZER),1)
var c = bytes().fromb64("dWxwAAwAHAAIAAAAJwGwLXEAgHIEAABoKAGwLYEAgHIEAABoAAAAsAAAAAAAAAAA")
ULP.load(c)
ULP.run()
ULP.get_mem(7) # RTC_IO_TOUCH_PAD2_REG (12-28)
ULP.get_mem(8) # RTC_IO_TOUCH_PAD3_REG (12-28)

"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
#define DR_REG_RTCCNTL_BASE                     0x3ff48000
#define DR_REG_RTCIO_BASE                       0x3ff48400

#define RTC_CNTL_STATE0_REG          (DR_REG_RTCCNTL_BASE + 0x18)
#define RTC_IO_TOUCH_PAD2_REG          (DR_REG_RTCIO_BASE + 0x9c)
#define RTC_IO_TOUCH_PAD2_REG          (DR_REG_RTCIO_BASE + 0x9c)
#define RTC_IO_TOUCH_PAD3_REG          (DR_REG_RTCIO_BASE + 0xa0)

#define RTC_CNTL_SLEEP_EN  (BIT(31))
#define RTC_CNTL_ULP_CP_SLP_TIMER_EN  (BIT(24))
#define RTC_IO_TOUCH_PAD2_MUX_SEL_M  (BIT(19))


.data
.global registertouch1
registertouch1: .long 0
registertouch2: .long 0
.text 
.global entry
entry:
READ_RTC_REG(RTC_IO_TOUCH_PAD2_REG, 12, 16)
move r1, registertouch1
st r0, r1, 0
READ_RTC_REG(RTC_IO_TOUCH_PAD3_REG, 12, 16)
move r1, registertouch2
st r0, r1, 0
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
