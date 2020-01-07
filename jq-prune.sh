#!/bin/bash
jq -c --slurpfile a page-ids.json 'select($a[0][.rpageid])'
