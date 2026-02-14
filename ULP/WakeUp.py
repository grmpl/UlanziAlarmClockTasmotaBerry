"""
Will wake up the main SoC when any button is pressed

Berry-Commands:
import ULP
ULP.gpio_init(gpio.pin(gpio.KEY1,0),0)
ULP.gpio_init(gpio.pin(gpio.KEY1,1),0)
ULP.gpio_init(gpio.pin(gpio.KEY1,2),0)
ULP.wake_period(0,100000)
var c = bytes().fromb64("dWxwAAwATAAIAAAACQH8LwEAFoIJAdQqAQASggkBeC8BAA6CMQGAcgQAANAQAAByBAAAaAAAAJIAAACwQQGAcgQAANAQAAByBAAAaAEAAJAAAACSAAAAsAAAAAAAAAAA")
ULP.load(c)
ULP.run()


"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
#define DR_REG_RTCIO_BASE                       0x3ff48400 # base for IO-register see 6.13.3 in https://documentation.espressif.com/esp32_technical_reference_manual_en.pdf
#define RTCIO_RTC_GPIO_IN_REG             (DR_REG_RTCIO_BASE + 0x24) # IN-Register see Register 6.44 in chapter above, 0-13 is reserved, starting from bit 14

.data
.global result1
result1: .long 0 # to check programming functionality
.global result2
result2: .long 0
.text 
.global entry
entry:
    READ_RTC_REG(RTCIO_RTC_GPIO_IN_REG, 14+17, 1) # read state of GPIO17 (middle button) into register r0
    JUMPR  wake, 1, LT # default state of GPIO17 is high, when button is pressed, it will be low
    READ_RTC_REG(RTCIO_RTC_GPIO_IN_REG, 14+7, 1) # read state of GPIO7 (left button) into register r0
    JUMPR  wake, 1, LT # default state of GPIO17 is high, when button is pressed, it will be low
    READ_RTC_REG(RTCIO_RTC_GPIO_IN_REG, 14+16, 1) # read state of GPIO17 (right button) into register r0
    JUMPR  wake, 1, LT # default state of GPIO17 is high, when button is pressed, it will be low
    #increment result1
    move r1, result1 # get address of result1
    ld r0, r1, 0 # load value of result1 into r0
    add r0, r0, 1 # increment value in r0
    st r0, r1, 0 # store incremented value back to result1    
    sleep 0
    halt
wake:
    move r1, result2 # get address of result2
    ld r0, r1, 0 # load value of result2 into r0
    add r0, r0, 1 # increment value in r0
    st r0, r1, 0 # store incremented value back to result2
    wake
    sleep 0
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
print("ULP.gpio_init(gpio.pin(gpio.KEY1,0),0)")
print("ULP.gpio_init(gpio.pin(gpio.KEY1,1),0)")
print("ULP.gpio_init(gpio.pin(gpio.KEY1,2),0)")
print("ULP.wake_period(0,100000)") # wake up every 100ms to check button state, will not wake up SoC
print("var c = bytes().fromb64(\""+code_b64+"\")")
print("ULP.load(c)")
print("ULP.run()")
print("ULP.sleep(60) # sleep for maximum of 60 seconds")

