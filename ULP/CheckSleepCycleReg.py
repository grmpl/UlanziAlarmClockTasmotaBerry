"""
Checking Sleep-Registers 0-1 and calibration

"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
# from components/soc/esp32/register/soc/reg_base.h
#define DR_REG_RTCCNTL_BASE                     0x3ff48000
#define DR_REG_RTCIO_BASE                       0x3ff48400
#define DR_REG_SENS_BASE                        0x3ff48800


# from components/soc/esp32/register/soc/sens_reg.h
#define SENS_ULP_CP_SLEEP_CYC0_REG          (DR_REG_SENS_BASE + 0x0018)
#define SENS_ULP_CP_SLEEP_CYC1_REG          (DR_REG_SENS_BASE + 0x001c)
#define RTC_CNTL_STORE1_REG          (DR_REG_RTCCNTL_BASE + 0x50)


.data
.global registercyc0
registercyc0: 
    .long 0
    .long 0
.global registercyc1
registercyc1: 
    .long 0
    .long 0
.global calibration
calibration:
 .long 0
 .long 0
.text 
.global entry
entry:
move r1, registercyc0
READ_RTC_REG(SENS_ULP_CP_SLEEP_CYC0_REG, 0, 16)
st r0, r1, 0
READ_RTC_REG(SENS_ULP_CP_SLEEP_CYC0_REG, 16, 16)
st r0, r1, 4

move r1, registercyc1
READ_RTC_REG(SENS_ULP_CP_SLEEP_CYC1_REG, 0, 16)
st r0, r1, 0
READ_RTC_REG(SENS_ULP_CP_SLEEP_CYC1_REG, 16, 16)
st r0, r1, 4

move r1, calibration
READ_RTC_REG(RTC_CNTL_STORE1_REG, 0, 16)
st r0, r1, 0
READ_RTC_REG(RTC_CNTL_STORE1_REG, 16, 16)
st r0, r1, 4

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
