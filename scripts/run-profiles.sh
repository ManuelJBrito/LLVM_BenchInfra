#!/bin/sh -ex
LOG_FILE="run-logs.txt"

batch_setup=`echo y && echo n && echo n && echo y && echo n && echo y && echo y`
echo $batch_setup | $PTS batch-setup

for p in $(grep -v '#' ${WORK_ENV}profiles.txt | grep -v '/build-')
do
	result_name=`echo $p | cut -d'/' -f2`"run"
	result_name="$result_name\n$result_name\n$result_name"
	pts_command="echo -n '$result_name' | $PTS batch-run $p"
	sh -c "$pts_command" 2>&1| tee -a $LOG_FILE
done