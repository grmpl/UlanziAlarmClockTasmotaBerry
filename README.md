# Tasmota Berry Apps for the Ulanzi TC001

This repository contains a few berry script files that run on my Ulanzi TC001.
It is just a cloud backup/should serve for inspiration for others. Don't expect any support whatsoever.

Thanks a lot to [https://github.com/iliaan/ulanzi-lab](https://github.com/iliaan/ulanzi-lab) for laying the groundwork!

## Flash Tasmota firmware

### **Warning**: 
Flashing Tasmota firmware on your device may potentially brick or damage the device. It is important to proceed with caution and to understand the risks involved before attempting to flash the firmware. Please note that any modifications to the device's firmware may void the manufacturer's warranty and may result in permanent damage to the device. It is strongly recommended to thoroughly research the flashing process and to follow instructions carefully. The user assumes all responsibility and risk associated with flashing the firmware.

To install Tasmota firmware on the Ulanzi TC001, follow these steps:

1. Download the Tasmota firmware from the [official Tasmota website](http://ota.tasmota.com/tasmota32/release/).
2. Follow installation guide [here](https://templates.blakadder.com/ulanzi_TC001.html).
3. In the Tasmota web interface, go to "Consoles" and select "Console". Enter the command "Pixels 256" to enable the 256-pixel display mode.
4. Set the time zone via the console by entering the command "Timezone +2:00".


## Misc Notes

- To stop processing of button events by tasmota, use `SetOption73 1`

- To give exclusive matrix access to Berry:
  - Set the real GPIO 32 to WS2812 ID 2
  - Remember that the WS2812 ID starts at 0 in berry