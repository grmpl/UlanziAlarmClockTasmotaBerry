"""
This is just a program to prevent the ULP from doing anything. 
It's useful if you want to clear ULP code.
To run it:
ULP.wake_period(0,10000000)
var c = bytes().fromb64("dWxwAAwABAAAAAAAAAAAsA==")
ULP.load(c)
ULP.run()



Template for exporting ULP code to Tasmotas Berry implementation
"""
from esp32_ulp import src_to_binary
import ubinascii

source = """
.text
.global entry
entry:
  halt  # go back to sleep until next wakeup period
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
