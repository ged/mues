#!/bin/sh

set -x

### Path to the C pre-processor
CPP=/lib/cpp
MYSQL=`which mysql`

### Run mysql with a password prompt?
PROMPT_FOR_PASSWORD=0

### Command-line flags. Uncomment the empty one to get a (mostly) silent run
#FLAGS=''
FLAGS='-vv'


if [ $PROMPT_FOR_PASSWORD != 0 ]; then
	FLAGS="${FLAGS} -p"
fi

${CPP} MUES.sql | ${MYSQL} ${FLAGS}
set +x
