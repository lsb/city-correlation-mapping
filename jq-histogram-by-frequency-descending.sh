#!/bin/bash
jq -c -s 'reduce .[] as $k ({}; .[$k] += 1) | to_entries | sort_by(- .value) | .[] | .key' | jq -c '{key: ., value: input_line_number}' | jq -c -s from_entries

