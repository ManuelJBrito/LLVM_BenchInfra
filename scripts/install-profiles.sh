#!/bin/sh -ex
LOG_DIR="install-logs"
mkdir -p $LOG_DIR/pts 
PTS_COMMAND="(trap 'kill 0' INT; "
for p in $(grep -v '#' ${WORK_ENV}profiles.txt | grep -v '/build-'); do

  basename=$(basename "$p")
  export COMPILE_TIME_PATH_CUR="${COMPILE_TIME_PATH}${basename}/"
  COMPILE_FAIL_PATH_CUR="${COMPILE_FAIL_PATH}${basename}"
  COMPILE_TIME_PATH_CUR="${COMPILE_TIME_PATH}${basename}"
  COMPILE_STATS_PATH_CUR="${COMPILE_STATS_PATH}${basename}"

  export CC_PRINT_INTERNAL_STAT=1
  export CC_PRINT_INTERNAL_STAT_FILE="$COMPILE_STATS_PATH_CUR"

  $PTS debug-install $p

  FAILED_LOG="${WORK_ENV}installed-tests/${p}/install-failed.log"
  if [ -e $FAILED_LOG ]; then
    mkdir -p $COMPILE_FAIL_PATH_CUR
    cp $FAILED_LOG "${COMPILE_FAIL_PATH_CUR}"
  fi


  echo $(awk '{sum += $1} END {print sum}' "$COMPILE_TIME_PATH_CUR") > "${COMPILE_TIME_PATH_CUR}"

  # Process the file to sum up values associated with "GVN" entries
  res=$(grep -i 'GVN' "$COMPILE_STATS_PATH_CUR" | awk -F ': ' '{
      key = $1
      value = $2
      gsub(/["{},]/, "", value)  # Remove unwanted characters
      sums[key] += value
  }
  END {
      for (key in sums) {
          print key ": " sums[key]
      }
  }') 
  echo "$res" > "$COMPILE_STATS_PATH_CUR"

  # PTS_COMMAND=$PTS_COMMAND"\$PTS debug-install $p 2>&1 | tee \$LOG_DIR/$p.log; echo $?;"
done
PTS_COMMAND=$PTS_COMMAND"wait)"

eval $PTS_COMMAND
