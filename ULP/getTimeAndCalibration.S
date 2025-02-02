# Just to read out RTC-Clock and calibration
# 
# var c = bytes().fromb64("dWxwAAwARAAQAAAAAwT8HwgAAIADAHgvEABAcggAQIARAYByBACAJwQAAGgEAMAvBAQAaDEBgHIUAIAnBAAAaBQAwC8EBABoBgBgHAAAALAAAAAAAAAAAAAAAAAAAAAA")
# ULP.load(c)
# ULP.run()
# t=tasmota.millis() # time in milliseconds
# cal=ULP.get_mem(20)*0x10000+ULP.get_mem(19)
# sum=0
# for i:0..18 # calibration is in Q13.19-format and must be converted
# var act=1.0*( (cal & (1<<i))>>i ) * math.pow(2,-19+i)
# sum=sum+act
# end
# caldez = sum+(cal>>19) # calibration in microseconds/tick (set by esp32-idf)
# ulptime=ULP.get_mem(18)*0x10000+ULP.get_mem(17) # RTC-time in ticks
# Result: ulptime does not match tasmota.millis(), which makes sense, as ulptime will overflow every few hours
#    to compare both timers, one needs a common reference first
#    if you do have a common reference, both timers will differ by ~1%
#




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
