#!/bin/sh
#Reset modem

echo "0" > /sys/class/gpio/modem_reset/value
sleep 1
echo "1" > /sys/class/gpio/modem_reset/value
