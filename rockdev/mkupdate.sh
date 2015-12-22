#!/bin/bash
pause()
{
	echo "Press any key to quit:"
	read -n1 -s key
	exit 1
}
echo "start to make update.img..."
if [ ! -f "parameter" ]; then
	echo "Fail! missing file: parameter!"
	pause
fi
if [ ! -f "package-file" ]; then
	echo "Fail! missing file:  package-file!"
	pause
fi

./afptool -pack ./ Image/update.img || pause
./rkImageMaker -RK330A Loader.bin Image/update.img update.img -os_type:androidos || pause
echo "Making update.img OK."
#echo "Press any key to quit:"
#read -n1 -s key
exit 0
