# Testprogram to test buzzer action with fixed values
# import ULP
# ULP.wake_period(1,200000)
# ULP.wake_period(0,1000000)
# ULP.gpio_init(gpio.pin(gpio.BUZZER),1)
# 
# var c = bytes().fromb64("dWxwAAwAKAAAAAAAAQAFggAAC4IAAewdAACAcgAAAJIAAACwAAXsHRAAgHIBAACSAAAAsA==")
# ULP.load(c)
# ULP.run()
# 
# Intervals can be modified in runtime by ULP.wake_period
#  Shortest on-interval which is usable:5-10 msec 
#
# Stop with: ResetRTCGPIO.py 
# var c = bytes().fromb64("dWxwAAwAOAAIAAAAKAHMGQYAYBwGAMAv4QCAcgQAAGgoAbAt8QCAcgQAAGgAAIByAQCAcgIAgHIDAIByAABAdAAAALAAAAAAAAAAAA==")
# ULP.load(c)
# ULP.run()
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

