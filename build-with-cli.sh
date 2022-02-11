#!/bin/bash

# install arduino-cli from github using:
#  curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh

# if Linux, to set up:
#  sudo dpkg --add-architecture i386
#  sudo apt install libc6-i386

# exit if any errors encountered
set -e

#---- project settings -----

readonly ARDUINO_FQBN="mcci:stm32:mcci_catena_4612"

ARDUINO_OPTIONS="$(echo '
                    upload_method=DFU
                    xserial=usb
                    sysclk=hsi16m
                    boot=basic
                    opt=osstd
                    lorawan_region=us915
                    lorawan_network=ttn
                    lorawan_subband=default
                    ' | xargs echo)"
readonly ARDUINO_OPTIONS

readonly ARDUINO_SOURCE=sketches/catena4612-pulse-generic/catena4612-pulse-generic.ino

#---- common code ----
BSP_MCCI=$HOME/.arduino15/packages/mcci
BSP_CORE=$BSP_MCCI/hardware/stm32/
LOCAL_BSP_CORE="$(realpath extra/Arduino_Core_STM32)"
OUTPUT_ROOT="$(realpath build)"
OUTPUT="${OUTPUT_ROOT}/ide"

function _help {
    less <<.
Build ${ARDUINO_SOURCE} using the arduino-cli tool.

Options:
    --clean does a clean prior to building.

    --verbose causes more info to be displayed.

    --help prints this message.
.
}

typeset -i OPTVERBOSE=0
typeset -i OPTCLEAN=0

# make sure everything is clean
for opt in "$@"; do
    case "$opt" in
    "--clean" )
        rm -rf "$OUTPUT_ROOT"
        OPTCLEAN=1
        ;;
    "--verbose" )
        OPTVERBOSE=$((OPTVERBOSE + 1))
        if [[ $OPTVERBOSE -gt 1 ]]; then
            ARDUINO_CLI_FLAGS="${ARDUINO_CLI_FLAGS}${ARDUINO_CLI_FLAGS+ }-v"
        fi
        ;;
    "--help" )
        _help
        exit 0
        ;;
    *)
        echo "not recognized: $opt -- use '--help' for help."
        exit 1
        ;;
    esac
done

if [[ ! -d "${OUTPUT}" ]]; then
    # the IDE hammers the specified directory; and we need other things here...
    # so make it a subdir of build.
    mkdir -p "${OUTPUT}"
fi

function _verbose {
    if [[ $OPTVERBOSE -ne 0 ]]; then
        echo "$@"
    fi
}

if [[ -d ~/Arduino/libraries ]]; then
    printf "%s\n" "Error: you have a ~/Arduino/libraries directory." \
                  "Please remove or hide it to use this script."
    exit 1
fi

# set up links to IDE
if [[ ! -d "$BSP_CORE" ]]; then
    echo "Not installed: $BSP_CORE"
    exit 1
fi

function _cleanup {
    if [[ -h "$BSP_CORE"/3.0.4 ]]; then
        _verbose "remove symbolic link"
        rm "$BSP_CORE"/3.0.4
    fi
    if [[ ! -z "$SAVE_BSP_CORE" ]] && [[ -d "$SAVE_BSP_CORE" ]]; then
        _verbose "restore BSP"
        mv "$SAVE_BSP_CORE" "$BSP_CORE"/"$SAVE_BSP_VER"
    fi
    rm -f "$LOCAL_BSP_CORE"/platform.local.txt
}

function _errcleanup {
    _verbose "Build error: remove output files"
    rm -f "$OUTPUT"/*.elf "$OUTPUT"/*.bin "$OUTPUT"/*.hex "$OUTPUT"/*.dfu
}

trap '_cleanup' EXIT
trap '_errcleanup' ERR

# set up BSP
OLD_BSP_CORE="$(echo "$BSP_CORE"/*)"
if [[ ! -h "$OLD_BSP_CORE" ]] && [[ -d "$OLD_BSP_CORE" ]]; then
    _verbose "save and overlay BSP"
    SAVE_BSP_VER="$(basename "$OLD_BSP_CORE")"
    SAVE_BSP_CORE="$(dirname "$BSP_CORE")"/stm32-"$SAVE_BSP_VER"
    mv "$OLD_BSP_CORE" "$SAVE_BSP_CORE"
    ln -sf "$LOCAL_BSP_CORE" "$BSP_CORE"/3.0.4
elif [[ -h "$OLD_BSP_CORE" ]] ; then
    _verbose "replace existing BSP link"
    ln -sf "$LOCAL_BSP_CORE" "$OLD_BSP_CORE"
else
    _verbose "link BSP core"
    ln -s "$LOCAL_BSP_CORE" "$OLD_BSP_CORE"
fi

# check tools
BSP_CROSS_COMPILE="$(printf "%s" "$BSP_MCCI"/tools/arm-none-eabi-gcc/*)"/bin/arm-none-eabi-
if [[ ! -x "$BSP_CROSS_COMPILE"gcc ]]; then
    echo "Toolchain not found: $BSP_CROSS_COMPILE"
    exit 1
fi

# do a build
_verbose "Building sketch"

_verbose arduino-cli compile $ARDUINO_CLI_FLAGS \
    -b "${ARDUINO_FQBN}":"${ARDUINO_OPTIONS//[[:space:]]/,}" \
    --build-path "$OUTPUT" \
    --libraries libraries \
    "${ARDUINO_SOURCE}"

arduino-cli compile $ARDUINO_CLI_FLAGS \
    -b "${ARDUINO_FQBN}":"${ARDUINO_OPTIONS//[[:space:]]/,}" \
    --build-path "$OUTPUT" \
    --libraries libraries \
    "${ARDUINO_SOURCE}"

# all done
_verbose "done"
exit 0

