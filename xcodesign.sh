#!/usr/bin/env sh

# README:
# Programs using the Virtualization framework must be signed with an
# entitlements file. I unfortunately cannot find a method of auto-signing
# the builds using SPM. I overcame this using a Makefile to run codesign.
# However when you open the package in Xcode, the builds will be in the
# Xcode DerivedData tree. This script just runs codesign on all Xcode
# debug executables called `vmac`.

# To use:
# * Open project in Xcode, and build (CMD+B)
# * Run this script as normal user `sh xcodesign.sh`
# * Run in Xcode without building (CTRL+CMD+R)
# If you run with the normal CMD+R it will also rebuild as well. Same with
# the `swift run` command.

for p in `ls $HOME/Library/Developer/Xcode/DerivedData/vmac-*/Build/Products/Debug/vmac`
do
	codesign --entitlements vmac.entitlements --force -s - "$p"
done
