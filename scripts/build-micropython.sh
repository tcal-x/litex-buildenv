#!/bin/bash

if [ "`whoami`" = "root" ]
then
    echo "Running the script as root is not permitted"
    exit 1
fi

CALLED=$_
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && SOURCED=1 || SOURCED=0

SCRIPT_SRC=$(realpath ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_SRC)
TOP_DIR=$(realpath $SCRIPT_DIR/..)

if [ $SOURCED = 1 ]; then
        echo "You must run this script, rather then try to source it."
        echo "$SCRIPT_SRC"
        return
fi

if [ -z "$PLATFORM" ]; then
	echo "Please set PLATFORM"
	exit 1
fi
if [ -z "$TARGET" ]; then
	echo "Please set TARGET"
	exit 1
fi
if [ -z "$CPU" ]; then
	echo "Please set CPU"
	exit 1
fi

set -x
set -e

MPY_SRC_DIR=$TOP_DIR/third_party/micropython
if [ ! -d "$MPY_SRC_DIR" ]; then
	(
		cd $(dirname $MPY_SRC_DIR)
		git clone https://github.com/upy-fpga/micropython.git
		cd $MPY_SRC_DIR
		git submodule update --init
	)
fi

TARGET_BUILD_DIR=$(realpath build)/${PLATFORM}_${TARGET}_${CPU}/
TARGET_MPY_BUILD_DIR=$TARGET_BUILD_DIR/software/micropython

if [ ! -d $TARGET_BUILD_DIR/software/include/generated ]; then
	make firmware
fi

if [ ! -e "$TARGET_MPY_BUILD_DIR/generated" ]; then
	mkdir -p $TARGET_MPY_BUILD_DIR
	(
		cd $TARGET_MPY_BUILD_DIR
		ln -s $(realpath $PWD/../../software/include/generated) $TARGET_MPY_BUILD_DIR/generated
	)
fi


OLD_DIR=$PWD
cd $TARGET_MPY_BUILD_DIR
export CROSS_COMPILE=$CPU-elf-newlib-
export BUILDINC_DIRECTORY=$TARGET_BUILD_DIR/software/include
export BUILD=$TARGET_MPY_BUILD_DIR
make -C ../../../../third_party/micropython/litex/
python -m litex.soc.tools.mkmscimg -f $TARGET_MPY_BUILD_DIR/firmware.bin -o $TARGET_MPY_BUILD_DIR/firmware.fbi
cd $OLD_DIR

/usr/bin/env python mkimage.py --output-file=$TARGET_BUILD_DIR/micropython.bin --override-firmware=$TARGET_MPY_BUILD_DIR/firmware.fbi
