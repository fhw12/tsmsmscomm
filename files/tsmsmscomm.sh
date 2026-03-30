#!/bin/sh

INITFILE=/etc/init.d/tsmsmscomm
SERVICE_PID_FILE=/var/run/tsmsmscomm.pid
APP=$0
PAR1=$1
PAR2=$2

usage() {
    echo "Usage: $APP [ COMMAND [ OPTIONS ] ]"
    echo "Without any command Tsmsmscomm will be runned in the foreground without debug mode"
    echo
    echo "Commands are:"
    echo "    start|stop|restart|reload     controlling the daemon"
    echo "    debug                         run in debug mode"
    echo "    help                          show this and exit"
    doexit
}
callinit() {
    [ -x $INITFILE ] || {
        echo "No init file '$INITFILE'"
        return
    }
    RETVAL=$?
}
run() {
    uci set tsmsmscomm.general.debug='0'
    uci commit tsmsmscomm
    exec /usr/bin/lua /usr/lib/lua/tsmsmscomm/app.lua
    RETVAL=$?
}

debug() {
    tsmsmscomm stop
    uci set tsmsmscomm.general.debug='1'
    [ -n "$PAR2" ] || {
        exec /usr/bin/lua /usr/lib/lua/tsmsmscomm/app.lua
    }
    [ -n "$PAR2" ] && {
        uci set tsmsmscomm.general.param=$PAR2
    }
    [ -n "$PAR2" ] || {
        uci delete tsmsmscomm.general.param
    }
    uci commit tsmsmscomm
    sleep 1
    RETVAL=$?
}

doexit() {
    exit $RETVAL
}

[ -n "$INCLUDE_ONLY" ] && return

CMD="$1"
[ -z $CMD ] && {
    run
    doexit
}
shift
# See how we were called.
case "$CMD" in
    start|restart|reload)
echo STARTING $CMD
        callinit $CMD
        ;;
    debug)
        debug
        ;;
    stop)
        uci set tsmsmscomm.general.debug='0'
        uci commit tsmsmscomm
        callinit $CMD
        ;;
    *help|*?)
        usage $0
        ;;
    *)
        RETVAL=1
        usage $0
        ;;
esac

doexit
