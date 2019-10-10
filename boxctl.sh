#!/bin/ksh

# /*
#  * Copyright (c) 2019 Aaron Bieber <aaron@bolddaemon.com>
#  *
#  * Permission to use, copy, modify, and distribute this software for any
#  * purpose with or without fee is hereby granted, provided that the above
#  * copyright notice and this permission notice appear in all copies.
#  *
#  * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
#  * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
#  * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
#  * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# */

set -au

SERVER=""
RUN_USER="root"
VERBOSITY=0
DRY=0
MAINTENANCE=0
SNAPSHOT=""
FORCE=0
SSH_CTL_PATH="/tmp/boxctl-%r@%h:%p"
SSH_OPTS="-o ControlMaster=auto -o ControlPersist=60s -o ControlPath=${SSH_CTL_PATH}"

while getopts "fh:mnu:sv" arg; do
	case $arg in
		f)
			FORCE=1
			;;
		h)
			SERVER=$OPTARG
			;;
		m)
			MAINTENANCE=1
			;;
		n)
			DRY=1
			;;
		u)
			RUN_USER=$OPTARG
			;;
		s)
			SNAPSHOT="-Dsnap"
			;;
		v)
			VERBOSITY=$((VERBOSITY+1))
			;;
	esac
done

PKG_DIFF_INSTALL=$(cat <<EOF
if [ -f /etc/packages ] && [ "${FORCE}" == "0" ]; then
	# Already ran a full install, so only install new packages
	diff -u /etc/packages /etc/packages.tmp | grep -e ^+[a-z0-9] | \
		sed 's/^+//' > /tmp/new_packages
	/usr/sbin/pkg_add %s ${SNAPSHOT} -z -l /tmp/new_packages
else
	/usr/sbin/pkg_add %s ${SNAPSHOT} -z -l /etc/packages.tmp
fi
mv /etc/packages.tmp /etc/packages
EOF
)

SERVICE_START_RESTART=$(cat <<EOF
/usr/sbin/rcctl enable %s; \
/usr/sbin/rcctl check %s && \
	/usr/sbin/rcctl restart %s || \
	/usr/sbin/rcctl start %s
EOF
)

msg() {
	local _level _msg
	_level=$1
	_msg=$2
	if [ $VERBOSITY -ge $_level ] && [ $DRY == 0 ]; then
		echo "==> ${SERVER} -> $_msg"
	fi
}

expand_v() {
	V=""
	if [ $VERBOSITY -gt 0 ]; then
		for v in $(jot $VERBOSITY); do
			V="${V}v"
		done
	fi
	if [ "${V}" == "" ]; then
		echo "${V}"
	else
		echo "-${V}"
	fi
}

ssh_verbose() {
	local _opt=""
	if [ $VERBOSITY -ge 4 ]; then
		_opt="$V"
	fi

	if [ $DRY == 1 ]; then
		echo ssh ${SSH_OPTS} $_opt "$1" "${2}"
	else
		ssh ${SSH_OPTS} $_opt "$1" "${2}"
	fi
}

ssh_quiet() {
	if [ $DRY == 1 ]; then
		echo "ssh ${SSH_OPTS} '$1' '${2}' >/dev/null"
	else
		ssh ${SSH_OPTS} "$1" "${2}" >/dev/null
	fi
}

scp_verbose() {
	local _opt=""
	if [ $VERBOSITY -ge 4 ]; then
		_opt="$V"
	fi

	if [ $DRY == 1 ]; then
		echo scp ${SSH_OPTS} $_opt "$1" "${2}"
	else
		scp ${SSH_OPTS} $_opt "$1" "${2}"
	fi
}

scp_quiet() {
	if [ $DRY == 1 ]; then
		echo "scp ${SSH_OPTS} '$1' '${2}' >/dev/null"
	else
		scp ${SSH_OPTS} "$1" "${2}" >/dev/null
	fi
}


_scp() {
	local _src _dest
	_src=$1
	_dest=$2

	if [ $VERBOSITY -gt 2 ]; then
		scp_verbose "$_src" "$_dest"
	else
		scp_quiet "$_src" "$_dest"
	fi
}

_ssh() {
	local _server _cmd
	_server=$1
	_cmd=$2

	if [ $VERBOSITY -gt 2 ]; then
		ssh_verbose "$_server" "$_cmd"
	else
		ssh_quiet "$_server" "$_cmd"
	fi
}

V=$(expand_v)

if [ -f ./files ]; then
	msg 0 "installing $(wc -l files | awk '{print $1 " " $2}')"
	for file in $(cat files); do
		local _src _dest _mode _owner _group
		read _src _owner _group _mode _dest <<EOF
			$(echo $file | sed 's/:/ /g')
EOF
		msg 1 "\t${_src} -> ${_dest}"
		msg 2 "\t\tchown ${_owner}:${_group} $_dest"
		msg 2 "\t\tchmod ${_mode} $_dest"

		_scp $_src "${RUN_USER}@${SERVER}:$_dest"
		_ssh ${RUN_USER}@${SERVER} "/sbin/chown ${_owner}:${_group} \
			$_dest; /bin/chmod ${_mode} $_dest"
	done
fi

if [ -f ./services ]; then
	msg 0 "enabling services $(wc -l services | awk '{print $1 " " $2}')"
	for service in $(cat services); do
		msg 1 "\tenabling/restarting ${service}"
		cmd="$(printf "$SERVICE_START_RESTART" \
			$service $service $service $service)"
		_ssh ${RUN_USER}@${SERVER} "${cmd}"
	done
fi

if [ -f ./packages ]; then
	msg 0 "installing $(wc -l packages | awk '{print $1 " " $2}')"
	cmd=$(printf "${PKG_DIFF_INSTALL}" $V $V)
	_scp packages "${RUN_USER}@${SERVER}:/etc/packages.tmp"
	_ssh ${RUN_USER}@${SERVER} "${cmd}"
fi

if [ $MAINTENANCE == 1 ]; then
	msg 0 "cleaning up unused packages"
	_ssh ${RUN_USER}@${SERVER} "/usr/sbin/pkg_delete $V -a"
	msg 0 "installing firmware updates"
	_ssh ${RUN_USER}@${SERVER} "/usr/sbin/fw_update $V -a"
fi
