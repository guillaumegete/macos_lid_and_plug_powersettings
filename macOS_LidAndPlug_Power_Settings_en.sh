#!/bin/bash

# Author:Guillaume Gète
# 01/02/2025

# Allows to choose the behavior of an Apple Silicon Macbook Pro/Air when a power cable is connected or the lid opened. More info here: https://support.apple.com/120622
# Requires SwiftDialog (https://github.com/swiftDialog)
# v1.0

# Requires an Apple Silicon processor

if [ ! "$(uname -p)" = "arm" ]; then
	echo "This script runs only on Apple Silicon Macs."
	exit 1
fi

# Requires at least macOS 15 to run

if [ "$(sw_vers --productVersion | cut -c 1-2 )" -lt "15" ]; then
	echo "This script requires at least macOS version 15."
	exit 1
fi

# Variables

# Text displayed when the user wants the Mac to start when the Mac's display is opened

lidOpenedDialog="When the Mac's lid is opened"

# Text displayed when the user wants the Mac to start when power cable is plugged

powerPluggedDialog="When I plug a power cable"

dialogButton1="Apply these settings"
dialogButton2="Cancel"
titleDialog="Power settings"
messageDialog="Your Mac can start when you plug a power cable or if you open the lid. \n\nIf you want to change this behavior, check or uncheck the following settings and click on *$dialogButton1*. \n\n **Automatically power on the Mac :**"


successMessage="The settings have been applied."

# Get current settings from BootPreference in NVRAM

if nvram BootPreference
then
	
	case $(nvram BootPreference) in
		"BootPreference	%00")
			echo "Startup when connecting to power : FALSE - Startup when opening lid : FALSE"	
			currentPlugSetting="false"
			currentLidSetting="false"
		;;
		"BootPreference	%01")
			echo "Startup when connecting to power : TRUE - Startup when opening lid : FALSE"	
			currentPlugSetting="true"
			currentLidSetting="false"
		;;
		"BootPreference	%02")
			echo "Startup when connecting to power : FALSE - Startup when opening lid : TRUE"	
			currentPlugSetting="false"
			currentLidSetting="true"
		;;		
	esac
	
else
	# If there is an error, the BootPreference is missing, so it means both settings are ON.
	echo "Startup when connecting to power : TRUE - Startup when opening lid : TRUE"	
	currentPlugSetting="true"
	currentLidSetting="true"
fi


#==================================================================#
#--------------------# Installing SwiftDialog #--------------------#
#==================================================================#

# Requires the SwiftDialog framework. It will be installed if missing. Comment or remove if you prefer to push your own version of SwiftDialog.

dialogPath="/usr/local/bin/dialog"
dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

if [ ! -e "$dialogPath" ]; then
	echo "SwiftDialog must be installed."
	curl -L "$dialogURL" -o "/tmp/dialog.pkg"
	installer -pkg /tmp/dialog.pkg -target /
	
	if [ ! -e "$dialogPath" ]; then
		echo "An error occured. SwiftDialog could not be installed."
		exit 1
	else
		echo "Swiftdialog is available. Moving on…"
	fi
else 
	echo "Swiftdialog is available. Moving on…"
fi

## Create the settings for the dialog. This is required to set up some specific settings with checkboxes.

tmpJson=$(mktemp "/tmp/dialogfile.XXXXXX")
chmod 644 "$tmpJson"

cat > "$tmpJson" <<EOF

{		
"ontop" : "true",
"bannertitle" : "$titleDialog",
"bannerimage" : "colour=green",
"bannerheight" : "50",
		"message" : "$messageDialog",
"messagefont" : "size=16",
	"icon" : "SF=power.circle.fill,colour=green,animation=pulse",
	"button1text" : "$dialogButton1",
"button2text" : "$dialogButton2",
	"checkbox" : [
		{"label" : "$powerPluggedDialog", "checked" : $currentPlugSetting, "disabled" : false, "icon" : "SF=powerplug.fill,colour=green" },
		{"label" : "$lidOpenedDialog", "checked" : $currentLidSetting, "enabled" : true, "icon" : "SF=macbook,colour=blue,weight=bold"  },
	],
"checkboxstyle" : {
	"style" : "switch",
	"size"  : "regular"
	}  

}

EOF

newPowerSettings=$(mktemp "/tmp/powerSettings.XXXXXX")

dialog --jsonfile "$tmpJson" > "$newPowerSettings"

case $? in
	0)
		# Get the values from the results
		
		lidOpenedSetting=$(grep "$lidOpenedDialog" "$newPowerSettings" | awk '{print $NF}' | sed 's/\"//g' )
		
		powerPluggedSetting=$(grep "$powerPluggedDialog" "$newPowerSettings" | awk '{print $NF}' | sed 's/\"//g' )
		
		echo "$lidOpenedSetting"
		echo "$powerPluggedSetting"
		
		
		if [ "$lidOpenedSetting" = "false" ] && [ "$powerPluggedSetting" = "false" ]; then
			nvram BootPreference=%00
		elif [ "$lidOpenedSetting" = "false" ] && [ "$powerPluggedSetting" = "true" ]; then
			nvram BootPreference=%01
		elif [ "$lidOpenedSetting" = "true" ] && [ "$powerPluggedSetting" = "false" ]; then
			nvram BootPreference=%02
		elif [ "$lidOpenedSetting" = "true" ] && [ "$powerPluggedSetting" = "true" ]; then
			nvram -d BootPreference
		fi
		
		dialog -m "$successMessage" --bannertitle "$titleDialog" --icon "SF=power.circle.fill,colour=green,animation=pulse" --style centered -s --bannerimage colour=green --bannerheight 50 --button1text "OK"

	;;
	2)
		echo "Pressed Cancel Button (button 2)"
	;;
esac

# Cleanup 
rm -f "$tmpJson" "$newPowerSettings"

exit 0
