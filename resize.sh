#!/bin/bash

get_size()
{
	echo $1 | awk -F"@" '{print $1}'
}

get_offset()
{
	echo $1 | awk -F"@" '{print $2}'
}

echo_print()
{
	echo "Apk size:   $app_size"
	echo "Apk offset: $app_offset"
	echo "Mid name:   $mid_name"
	echo "Mid size:   $mid_size"
	echo "Mid offset: $mid_offset"
	echo "End name:   $end_name"
	echo "End size:   $end_size"
	echo "End offset: $end_offset"
	echo "Rfs name:   $rfs_name"
	echo "Rfs size:   $rfs_size"
	echo "Rfs offset: $rfs_offset"
}

# unpack the update.img
updateimg_file=$1
if [ -f $updateimg_file ]; then
	cp -a $updateimg_file rockdev/update.img
fi
cd rockdev
./unpack.sh
cd ..

parameter_file=rockdev/output/parameter
partition1=`grep userdata $parameter_file | awk -F "userdata" '{print $1}'`
partition2=`grep userdata $parameter_file | awk -F "userdata" '{print $2}'`

# Apk partition
app_partition=`echo $partition1 | awk -F"," '{print $NF}' | awk -F"(" '{print $1}'`
app_size=`get_size $app_partition`
app_offset=`get_offset $app_partition`
# old build: radical_update@android, or linuxroot@dualos
# new build: radical_update@android, or ramfs@dualos
mid_partition=`echo $partition2 | awk -F"," '{print $2}' | awk -F"(" '{print $1}'`
mid_name=`echo $partition2 | awk -F"(" '{print $2}' | awk -F")" '{print $1}'`
mid_size=`get_size $mid_partition`
mid_offset=`get_offset $mid_partition`
# user partition
end_partition=`echo $partition2 | awk -F"," '{print $3}' | awk -F"(" '{print $1}'`
end_name=`echo $partition2 | awk -F"(" '{print $3}' | awk -F")" '{print $1}'`
end_size=`get_size $end_partition`
end_offset=`get_offset $end_partition`
# for new build: linuxroot@dualos
rfs_partition=`echo $partition2 | awk -F"," '{print $4}' | awk -F"(" '{print $1}'`
rfs_name=`echo $partition2 | awk -F"(" '{print $4}' | awk -F")" '{print $1}'`
rfs_size=`get_size $rfs_partition`
rfs_offset=`get_offset $rfs_partition`
app_size_orig=$app_size


# read from the input
echo "Tell me the size you need for App partition:"
echo -e "1: 1GB\n2: 2GB\n3: 3GB\n4: 4GB\n5: 5GB\n6: 6GB"
read -p "Choose the number: " wanna_size

# check & map the size to GB
GByte=$((0x200000))
case $wanna_size in
1 | 2 | 3 | 4 | 5 | 6)
	wanna_size_gb=`expr $wanna_size \* $GByte`
	;;	
*)
	echo "Warning: unkown size."
	exit
	;;	
esac

# get new partitions
app_size_dec=$wanna_size_gb
mid_offset_dec=`expr $app_size_dec + $(($app_offset))`
end_offset_dec=`expr $mid_offset_dec + $(($mid_size))`

app_size=`echo "obase=16;$app_size_dec" | bc`
mid_offset=`echo "obase=16;$mid_offset_dec" | bc`
end_offset=`echo "obase=16;$end_offset_dec" | bc`

partition0=`echo $partition1 | awk -F"$app_partition" '{print $1}'`
if [ -z $rfs_name ]; then
	partition2="),$mid_size@0x$mid_offset($mid_name),-@0x$end_offset($end_name)"
else
	echo "New dualOS build"
	# Note: $rfs_offset is fix value in new build
	end_size_dec=`expr $(($end_size)) + $(($app_size_orig)) - $app_size_dec`
	end_size=0x`echo "obase=16;$end_size_dec" | bc`
	partition2="),$mid_size@0x$mid_offset($mid_name),$end_size@0x$end_offset($end_name),-@$rfs_offset($rfs_name)"
fi
partitions="$partition0"0x"$app_size@$app_offset(userdata$partition2"

# generate a new parameter
sed -i "/userdata/d" $parameter_file
echo "$partitions" >> $parameter_file

# debug
#echo_print

# repack the update.img
cp -a rockdev/output/* rockdev/
./mkupdate.sh

# restore
git checkout rockdev

echo "Done: new firmware<rockdev/update.img>"
