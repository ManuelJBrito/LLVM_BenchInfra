#!/bin/sh -ex
for p in $(grep -v '#' ${WORK_ENV}profiles.txt | grep -v '/build-'); do
  result_name=`echo $p | cut -d'/' -f2| tr -d '.'`"run"
  results=$results" "$result_name
done

rm -rf ${RESULTS_PATH}merge-*
echo n | $PTS merge-results $results 
merged_results=$(find ${RESULTS_PATH} -type d -name "merge-*" | head -n 1 | xargs -I {} basename {})
$PTS result-file-to-csv $merged_results



