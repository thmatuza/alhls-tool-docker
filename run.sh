#!/bin/bash
#
BASE=/tmp
PID=$BASE/app.pid
LOG=$BASE/app.log
ERROR=$BASE/app-error.log

VARIANT_O=4M
VARIANT_L=2M
VARIANT_P=0.5M
WEB_BASE=webroot
WEB_O=$WEB_BASE/$VARIANT_O
WEB_L=$WEB_BASE/$VARIANT_L
WEB_P=$WEB_BASE/$VARIANT_P

WEB_SCRIPT=lowLatencyHLS.php

PART_TARGET_DURATION=202
TARGET_DURATION=4
ADDRESS='224.0.0.50'
PORT_O=9121
PORT_L=9123
PORT_P=9125
SLIDING_WINDOW=16

SEGMENTER_CMD='mediastreamsegmenter'
SEGMENTER_COMMAND_L="$SEGMENTER_CMD -w $PART_TARGET_DURATION -t $TARGET_DURATION $ADDRESS:$PORT_L -s $SLIDING_WINDOW -D -T -f ./$WEB_L/"
SEGMENTER_COMMAND_P="$SEGMENTER_CMD -w $PART_TARGET_DURATION -t $TARGET_DURATION $ADDRESS:$PORT_P -s $SLIDING_WINDOW -D -T -f ./$WEB_P/"
SEGMENTER_COMMAND_O="$SEGMENTER_CMD -w $PART_TARGET_DURATION -t $TARGET_DURATION $ADDRESS:$PORT_O -s $SLIDING_WINDOW -D -T -f ./$WEB_O/"

COMPRESSOR_CMD='tsrecompressor'
COMPRESSOR_COMMAND="$COMPRESSOR_CMD -L $ADDRESS:$PORT_L -P $ADDRESS:$PORT_P -O $ADDRESS:$PORT_O -h -g -x -a"

LOG_BASE=log
LOG_O=$LOG_BASE/${SEGMENTER_CMD}_${VARIANT_O}.txt
LOG_L=$LOG_BASE/${SEGMENTER_CMD}_${VARIANT_L}.txt
LOG_P=$LOG_BASE/${SEGMENTER_CMD}_${VARIANT_P}.txt
LOG_COMPRESSOR=$LOG_BASE/$COMPRESSOR_CMD.txt

export DOCKER_HOST_IP=$(ipconfig getifaddr en0)

status() {
    echo
    echo "==== Status"

    if [ -f $PID ]
    then
        echo
        echo "Pid file: $( cat $PID ) [$PID]"
        echo
        ps -ef | grep -v grep | grep $( cat $PID )
    else
        echo
        echo "No Pid file"
    fi
}

start() {
    if [ -f $PID ]
    then
        echo
        echo "Already started. PID: [$( cat $PID )]"
    else
        echo "==== Start"
        touch $PID

        mkdir -p $LOG_BASE

        rm -rf ./$WEB_BASE
        mkdir ./$WEB_BASE

        mkdir ./$WEB_L
        mkdir ./$WEB_P
        mkdir ./$WEB_O

        cp ./data/nginx/server.crt ./$WEB_BASE/
        cp master.m3u8 ./$WEB_BASE
        cp $WEB_SCRIPT ./$WEB_L/
        cp $WEB_SCRIPT ./$WEB_P/
        cp $WEB_SCRIPT ./$WEB_O/

        if nohup $SEGMENTER_COMMAND_L >>$LOG_L 2>&1 &
        then echo "$(date '+%Y-%m-%d %X'): START L" >>$LOG
        else echo "Error... "
             /bin/rm $PID
             return 1
        fi
        if nohup $SEGMENTER_COMMAND_P >>$LOG_P 2>&1 &
        then echo "$(date '+%Y-%m-%d %X'): START P" >>$LOG
        else echo "Error... "
             /bin/rm $PID
             return 1
        fi
        if nohup $SEGMENTER_COMMAND_O >>$LOG_O 2>&1 &
        then echo "$(date '+%Y-%m-%d %X'): START O" >>$LOG
        else echo "Error... "
             /bin/rm $PID
             return 1
        fi
        if nohup $COMPRESSOR_COMMAND >>$LOG_COMPRESSOR 2>&1 &
        then echo $! >$PID
             echo "Done."
             echo "$(date '+%Y-%m-%d %X'): START COMPRESSOR" >>$LOG
             docker-compose up -d
        else echo "Error... "
             /bin/rm $PID
        fi
    fi
}

kill_cmd() {
    SIGNAL=""; MSG="Killing "
    while true
    do
        LIST=`ps -ef | grep -v grep | grep -e $SEGMENTER_CMD -e COMPRESSOR_CMD | awk '{print $2}'`
        if [ "$LIST" ]
        then
            echo; echo "$MSG $LIST" ; echo
            echo $LIST | xargs kill $SIGNAL
            sleep 2
            SIGNAL="-9" ; MSG="Killing $SIGNAL"
            if [ -f $PID ]
            then
                /bin/rm $PID
            fi
        else
           echo; echo "All killed..." ; echo
           break
        fi
    done
}

stop() {
    echo "==== Stop"

    if [ -f $PID ]
    then
        if kill $( cat $PID )
        then echo "Done."
             echo "$(date '+%Y-%m-%d %X'): STOP" >>$LOG
        fi
        /bin/rm $PID
        kill_cmd
        docker-compose down
    else
        echo "No pid file. Already stopped?"
    fi
}

case "$1" in
    'start')
            start
            ;;
    'stop')
            stop
            ;;
    'restart')
            stop ; echo "Sleeping..."; sleep 1 ;
            start
            ;;
    'status')
            status
            ;;
    *)
            echo
            echo "Usage: $0 { start | stop | restart | status }"
            echo
            exit 1
            ;;
esac

exit 0