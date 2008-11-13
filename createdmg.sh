#!/bin/bash
echo "create image"
/usr/bin/hdiutil create -type SPARSE -fs "HFS+" -volname  enfuseGUI enfuseGUI.sparseimage
/usr/bin/hdiutil attach -nobrowse -mountpoint enfuseGUI enfuseGUI.sparseimage 
echo "copying data"
cp -R build/Release/enfuseGUI.app enfuseGUI
ln -s /Applications /Volumes/enfuseGUI/.
echo "detaching"
/usr/bin/hdiutil detach enfuseGUI
echo "compressing DMG"
/usr/bin/hdiutil convert -format UDZO -o enfuseGUI.dmg enfuseGUI.sparseimage

