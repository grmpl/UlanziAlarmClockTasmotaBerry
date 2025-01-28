# Testing done by:
# def gettime()
# print(tasmota.millis()-t0,ULP.get_mem(8))
# ULP.wake_period(0,100)
# end
# var c = bytes().fromb64("dWxwAAwAIAAEAAAAgQCAcgQAANAQAAByBAAAaOgDBYIAAACwBgBgHAAAALD/////")
# ULP.load(c)
# timer=100
# ULP.wake_period(0,timer*1000)
# ULP.run()
# t0=tasmota.millis()
# c0=0
# tasmota.set_timer(timer*500,gettime)
#
# stop program with: ULP.wake_period(0,100) - this will get the counter fast to 1000
#
# Results: Wakeperiod 10.000 -> 10.025
#          Wakeperiod 100.000 -> 100.25
#          Wakeperiod 50.000 -> 50.16
#          Wakeperiod 20.000 -> 20.05
#          Wakeperiod 500.000 -> 502,0
#          Wakeperiod 100.000.000 -> 100402
# -> Deviation ~0.2-0.4% 



#define DR_REG_RTCCNTL_BASE                     0x3ff48000
#define RTC_CNTL_STATE0_REG          (DR_REG_RTCCNTL_BASE + 0x18)
#define RTC_CNTL_ULP_CP_SLP_TIMER_EN  (BIT(24))

.data
.global counter
counter: .long -1
.text
.global entry
entry:
    move r1, counter # get the address of the counter into r1
    ld r0, r1, 0 # load the counter value into r0 
    add r0, r0,1 # increment the counter
    st r0, r1, 0 # store the counter value back into the counter
    jumpr stop, 1000, GE
    halt
stop:
    WRITE_RTC_REG(RTC_CNTL_STATE0_REG, RTC_CNTL_ULP_CP_SLP_TIMER_EN, 1, 0) #disable ULP Sleep-Timer
    halt
