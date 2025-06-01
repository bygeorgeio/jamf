#!/bin/bash

# Set computer name to Serial Number
/usr/local/bin/jamf setComputerName -useSerialNumber

# Recon to update Jamf Server immediately
/usr/local/bin/jamf recon

exit 0

