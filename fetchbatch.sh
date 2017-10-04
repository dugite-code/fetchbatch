#!/bin/sh
#
# FetchBatch init script
# Latest change: Do Aug 30 16:04:39 CEST 2012
#
### BEGIN INIT INFO
# Provides:          fetchmail
# Required-Start:    $network $local_fs $remote_fs $syslog
# Required-Stop:     $remote_fs
# Should-Start:      $mail-transport-agent postfix exim4 $named
# Should-Stop:       $mail-transport-agent postfix exim4
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: init-Script for system wide fetchmail daemon
# Description: Enable service provided by fetchmail in daemon mode
### END INIT INFO

set -e

# Defaults
PATH=/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/bin/fetchmail
USER=fetchmail
OPTIONS="-v "
FMDIR="/var/run/fetchmail"

UIDL="/var/lib/fetchmail/.fetchmail-UIDL-cache"
START_DAEMON="no"

. /lib/lsb/init-functions

if [ -r /etc/default/fetchmail ]; then
    . /etc/default/fetchmail
fi

if [ ! "x$START_DAEMON" = "xyes" -a ! "$1" = "status" ]; then
        log_action_msg "Not starting fetchmail daemon, disabled via /etc/default/fetchmail"
        exit 0
fi


test -f $DAEMON || exit 0

# sanity checks (saves on MY sanity :-P )
if ! id $USER >/dev/null 2>&1; then
	if [ "$USER" = "fetchmail" ]; then
		# The fetchmail user might have been removed when the fetchmail-common
		# package is purged. We have to re-add it here so the system-wide
		# daemon will run.

		adduser --system --ingroup nogroup --home /var/lib/fetchmail \
			--shell /bin/sh --disabled-password fetchmail >/dev/null 2>&1 || true
		# work around possible adduser bug, see #119366
		[ -d /var/lib/fetchmail ] || mkdir -p /var/lib/fetchmail
		chmod 700 /var/lib/fetchmail
		chown -h -R fetchmail:nogroup /var/lib/fetchmail
	else
		log_failure_msg "$0: $USER user does not exist!"
		exit 1
	fi
fi

# add syslog option unless user specified "set no syslog".
if ! grep -qs '^[[:space:]]*set[[:space:]]\+no[[:space:]]\+syslog' "$CONFFILE"; then
	OPTIONS="$OPTIONS --syslog"
fi

# Makes sure certain files/directories have the proper owner
for CONFILE in /etc/fetchmail.conf.d/*.conf; do
  if [ -f $CONFILE -a "`stat -c '%U %a' $CONFILE 2>/dev/null`" != "$USER 600" ]; then
  	chown -h $USER "$CONFILE"
  	chmod -f 0600 "$CONFILE"
  fi
  BNAME=$(basename "$CONFILE")
  FMDIRSUB=$FMDIR/$BNAME
  if [ ! -d "$FMDIRSUB" ]; then
    mkdir -p "$FMDIRSUB"
    chown -h $USER:nogroup "$FMDIRSUB"
    chmod -f 0700 "$FMDIRSUB"
  fi
done

case "$1" in
	start)
    for CONFILE in /etc/fetchmail.conf.d/*.conf; do
      if [ ! -r $CONFFILE ] ; then
          log_failure_msg "$CONFFILE found but not readable."
          exit 0
      fi
      BNAME=$(basename "$CONFILE")
      FMDIRSUB=$FMDIR/$BNAME
      PIDFILE=$FMDIRSUB/fetchmail.pid
      OPTIONS2="$OPTIONS --fetchmailrc $CONFILE --pidfile $PIDFILE"
  		if test -e $PIDFILE ; then
  			pid=`cat $PIDFILE | sed -e 's/\s.*//'|head -n1`
  			PIDDIR=/proc/$pid
  		    if [ -d ${PIDDIR} -a  "$(readlink -f ${PIDDIR}/exe)" = "${DAEMON}" ]; then
  				log_failure_msg "fetchmail for $BNAME already started; not starting."
  			else
  				log_warning_msg "Removing stale PID file $PIDFILE."
  				rm -f $PIDFILE
  			fi
  		fi
  	        log_begin_msg "Starting mail retriever agent:" "fetchmail for $BNAME "
  		if start-stop-daemon -S -o -q -p $PIDFILE -x $DAEMON -u $USER -c $USER -- $OPTIONS2; then
  			log_end_msg 0
  		else
  			log_end_msg 1
  		fi
    done
		;;
	status)
    for CONFILE in /etc/fetchmail.conf.d/*.conf; do
      BNAME=$(basename "$CONFILE")
      FMDIRSUB=$FMDIR/$BNAME
      PIDFILE=$FMDIRSUB/fetchmail.pid
      status_of_proc $DAEMON fetchmail -p $PIDFILE
    done
		;;
	stop)
    for CONFILE in /etc/fetchmail.conf.d/*.conf; do
      BNAME=$(basename "$CONFILE")
      FMDIRSUB=$FMDIR/$BNAME
      PIDFILE=$FMDIRSUB/fetchmail.pid
      if ! test -e $PIDFILE ; then
      	log_failure_msg "Pidfile not found! Is fetchmail for $BNAME running?"
      fi
      log_begin_msg "Stopping mail retriever agent:" "fetchmail for $BNAME "
      if start-stop-daemon -K -o -q -p $PIDFILE -x $DAEMON -u $USER; then
      	log_end_msg 0
      else
      	log_end_msg 1
		  fi
    done
		;;
	force-reload|restart)
    for CONFILE in /etc/fetchmail.conf.d/*.conf; do
      BNAME=$(basename "$CONFILE")
      FMDIRSUB=$FMDIR/$BNAME
      PIDFILE=$FMDIRSUB/fetchmail.pid
      OPTIONS2="$OPTIONS --fetchmailrc $CONFILE --pidfile $PIDFILE"
	        log_begin_msg "Restarting mail retriever agent:" "fetchmail"
  		if ! start-stop-daemon -K -o -q -p $PIDFILE -x $DAEMON -u $USER; then
  			log_end_msg 1
  		fi
  		sleep 1
  		if start-stop-daemon -S -q -p $PIDFILE -x $DAEMON -u $USER -c $USER -- $OPTIONS2; then
  			log_end_msg 0
  		else
  			log_end_msg 1
  		fi
    done
		;;
	try-restart)
		if test -e $PIDFILE ; then
			pid=`cat $PIDFILE | sed -e 's/\s.*//'|head -n1`
			PIDDIR=/proc/$pid
			if [ -d ${PIDDIR} -a  "$(readlink -f ${PIDDIR}/exe)" = "${DAEMON}" ]; then
				$0 restart
				exit 0
			fi
		fi
		test -f /etc/rc`/sbin/runlevel | cut -d' ' -f2`.d/S*fetchmail* && $0 start
		;;
	awaken)
    for CONFILE in /etc/fetchmail.conf.d/*.conf; do
      BNAME=$(basename "$CONFILE")
      FMDIRSUB=$FMDIR/$BNAME
      PIDFILE=$FMDIRSUB/fetchmail.pid
  	        log_begin_msg "Awakening mail retriever agent:" "fetchmail"
  		if [ -s $PIDFILE ]; then
  			start-stop-daemon -K -s 10 -q -p $PIDFILE -x $DAEMON
  			log_end_msg 0
  		else
  			log_end_msg 1
  		fi
    done
		;;
	debug-run)
		echo "$0: Initiating debug run of system-wide fetchmail service..." 1>&2
		echo "$0: script will be run in debug mode, all output to forced to" 1>&2
		echo "$0: stdout. This is not enough to debug failures that only" 1>&2
		echo "$0: happen in daemon mode." 1>&2
		echo "$0: You might want to direct output to a file, and tail -f it." 1>&2
		if [ "$2" = "strace" ]; then
			echo "$0: (running debug mode under strace. See strace(1) for options)" 1>&2
			echo "$0: WARNING: strace output may contain security-sensitive info, such as" 1>&2
			echo "$0: passwords; please clobber them before sending the strace file to a" 1>&2
			echo "$0: public bug tracking system, such as Debian's." 1>&2
		fi
		echo "$0: Stopping the service..." 1>&2
		"$0" stop
		echo "$0: exit status of service stop was: $?"
		echo "$0: RUNUSER is $USER"
    echo "$0: Config files loaded from /etc/fetchmail.conf.d/:"
    for CONFILE in /etc/fetchmail.conf.d/*.conf; do
      echo "$CONFILE"
    done
		echo "$0: Global OPTIONS would be $OPTIONS"
		echo "$0: Starting service in nodetach mode, hit ^C (SIGINT/intr) to finish run..." 1>&2
		if [ "$2" = "strace" ] ; then
			shift
			shift
			[ $# -ne 0 ] && echo "$0: (strace options are: -tt $@)" 1>&2
			su -s /bin/sh -c "/usr/bin/strace -tt $* $DAEMON $OPTIONS --nosyslog --nodetach -v -v" $USER <&- 2>&1
		else
			su -s /bin/sh -c "$DAEMON $OPTIONS --nosyslog --nodetach -v -v" $USER <&- 2>&1
		fi
		echo "$0: End of service run. Exit status was: $?"
		exit 0
		;;
	*)
		log_warning_msg "Usage: /etc/init.d/fetchmail {start|stop|restart|force-reload|awaken|debug-run}"
		log_warning_msg "  start - starts system-wide fetchmail service"
		log_warning_msg "  stop  - stops system-wide fetchmail service"
		log_warning_msg "  restart, force-reload - starts a new system-wide fetchmail service"
		log_warning_msg "  awaken - tell system-wide fetchmail to start a poll cycle immediately"
		log_warning_msg "  debug-run [strace [strace options...]] - start a debug run of the"
		log_warning_msg "    system-wide fetchmail service, optionally running it under strace"
		exit 1
		;;
esac

exit 0

# vim:ts=4:sw=4:
