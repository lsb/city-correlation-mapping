#!/bin/sh

YEAR=$1
envsubst < top-hundred.sql.envsubst | sqlite3 revisions.db > $1.psv
