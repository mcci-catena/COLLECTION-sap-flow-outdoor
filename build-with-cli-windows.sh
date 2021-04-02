#!/bin/bash

# download arduino-cli from the following link:
# https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip

# Once downloaded, extract the binary arduino-cli into a directory that is in your PATH.

# exit if any errors encountered
set -e

export OUTPUT=C:\\tmp\\build-catena4612-pulse-generic

# make sure everything is clean
if [[ "$1" = "--clean" ]]; then
    rm -rf "$OUTPUT"
fi

# do a build
arduino-cli compile \
    -b mcci:stm32:mcci_catena_4612:\
upload_method=DFU,\
xserial=usb,\
sysclk=hsi16m,\
opt=osstd,\
lorawan_region=us915,\
lorawan_network=ttn,\
lorawan_subband=default \
    --build-path "$OUTPUT" \
    --libraries libraries \
    sketches/catena4612-pulse-generic/catena4612-pulse-generic.ino
