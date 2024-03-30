#!/bin/sh -ex
LOG_DIR="install-logs"
mkdir -p $LOG_DIR/pts
for p in $(grep -v '#' ${WORK_ENV}profiles.txt | grep -v '/build-'); do

  export basename=$(basename "$p")
  export COMPILE_TIME_PATH_CUR="${COMPILE_TIME_PATH}${basename}/"
  mkdir -p "${COMPILE_TIME_PATH_CUR}"

  COMPILE_FAIL_PATH_CUR="${COMPILE_FAIL_PATH}${basename}"
  COMPILE_STATS_PATH_CUR="${COMPILE_STATS_PATH}${basename}"

  export CC_PRINT_INTERNAL_STAT=1
  export CC_PRINT_INTERNAL_STAT_FILE="$COMPILE_STATS_PATH_CUR"

  $PTS debug-install $p

  FAILED_LOG="${WORK_ENV}installed-tests/${p}/install-failed.log"
  if [ -e $FAILED_LOG ]; then
    mkdir -p $COMPILE_FAIL_PATH_CUR
    cp $FAILED_LOG "${COMPILE_FAIL_PATH_CUR}"
  fi

  # Extract the total compile time
  compile_time=$(awk '{sum += $1} END {print sum}' "$COMPILE_TIME_PATH_CUR/${basename}.time")

  # Extract the total GVN time
  for json_file in "${COMPILE_TIME_PATH_CUR}/*.json"; do
    tmp=$(jq '.traceEvents|.[] | select(.name == "Total GVNPass") | .dur ' $json_file)
    echo "$tmp" >> "$COMPILE_TIME_PATH_CUR/${basename}.gvnpass"
  done

  gvn_time=$(awk -F '[ ]' '{sum += $1} END {print sum}' "$COMPILE_TIME_PATH_CUR/${basename}.gvnpass")
  gvn_time=$(echo "scale=2;$gvn_time / 1000" | bc)

  # Output compile time results as csv
  echo "${basename}, ${compile_time}, ${gvn_time}" > "$COMPILE_TIME_PATH_CUR/${basename}.csv"

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
  echo "$res" >"$COMPILE_STATS_PATH_CUR"

done