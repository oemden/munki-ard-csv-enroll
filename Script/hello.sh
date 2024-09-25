#!/bin/bash
/usr/bin/clear 2>/dev/null
##
## oem at oemden dot com
##

## encrypt basch script: https://apple.stackexchange.com/questions/402913/convert-bash-script-to-a-compiled-standalone-binary-executable-not-text
# aka : Install and use brew install shc
#
# Here are the steps I used to create and test the executable.
#
# Enter the following command to compile the script using shc.
#
#shc -f hello.sh
# Enter the following command to rename the executable.
#
#mv hello.sh.x hello
# Enter the command to test.
#
#./hello
#
#
#############

osascript -e 'display dialog "HELLO encrypted script"' >/dev/null

