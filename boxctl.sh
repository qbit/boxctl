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
COPY=0
SSH_CTL_PATH="/tmp/boxctl-%r@%h:%p"
SSH_OPTS="-o ControlMaster=auto -o ControlPersist=60s -o ControlPath=${SSH_CTL_PATH}"
RSYNC_OPTS="--rsync-path=/usr/bin/openrsync -Dlrt"

while getopts "cfh:mnu:sv" arg; do
	case $arg in
		c)
			COPY=1
			;;
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
/usr/sbin/rcctl enable %s;
if /usr/sbin/rcctl check %s; then
	AGE=\$(stat -s %s | awk -v now=\$(date +%%s) \
		'{split(\$10,a,"="); print now - a[2]}')
	if [ \$AGE -lt 100 ] || [ "${FORCE}" == "1" ]; then
		logger -t boxctl "restarting %s (\$AGE seconds old)"
		/usr/sbin/rcctl restart %s
	else
		logger -t boxctl "not restarting %s (\$AGE seconds old)"
	fi
else
	/usr/sbin/rcctl start %s
fi
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

rsync_verbose() {
	local _opt=""
	if [ $VERBOSITY -ge 2 ]; then
		_opt="$V"
	fi

	if [ $DRY == 1 ]; then
		echo openrsync ${RSYNC_OPTS} $_opt "$1" "$2"
	else
		openrsync ${RSYNC_OPTS} $_opt "$1" "$2"
	fi
}

rsync_quiet() {
	if [ $DRY == 1 ]; then
		echo openrsync ${RSYNC_OPTS} "$1" "$2"
	else
		openrsync ${RSYNC_OPTS} "$1" "$2" >/dev/null
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


_rsync() {
	local _src _dest
	_src=$1
	_dest="$(dirname $2)"

	if [ $VERBOSITY -gt 2 ]; then
		rsync_verbose "$_src" "$_dest"
	else
		rsync_quiet "$_src" "$_dest"
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

fnc() {
	local _count
	_count=$(grep -v ^# $1 | wc -l | awk '{print $1}')
	echo "${1} ${_count}"
}


if [ "${COPY}" == "1" ]; then
	if [ -f ./files ]; then
		msg 0 "syncing $(fnc files) from ${SERVER}"
		for file in $(cat files | grep -v ^#); do
			local _src _dest _mode _owner _group _dir
			read _src _owner _group _mode _dest <<EOF
				$(echo $file | sed 's/:/ /g')
EOF
			_dir=$(dirname $_dest)
			msg 1 "\t${_dest} -> ${_src}"
			_rsync "${RUN_USER}@${SERVER}:$_dest" $_src
		done
	fi
	exit 0
fi

if [ -f ./packages ]; then
	msg 0 "installing $(fnc packages)"
	cmd=$(printf "${PKG_DIFF_INSTALL}" $V $V)
	_scp packages "${RUN_USER}@${SERVER}:/etc/packages.tmp"
	_ssh ${RUN_USER}@${SERVER} "${cmd}"
fi

if [ -f ./groups ]; then
	msg 0 "adding $(fnc groups)"
	for group in $(cat groups | grep -v ^#); do
		local _group _gid
		read _group _gid <<EOF
			$(echo $group | sed 's/:/ /g')
EOF
		msg 1 "\t${_group} (${_gid})"
		_ssh ${RUN_USER}@${SERVER} "grep -q ^${_group} /etc/group || \
			/usr/sbin/groupadd -g ${_gid} ${_group}"
	done
fi

if [ -f ./users ]; then
	msg 0 "adding $(fnc users)"
	for user in $(cat users | grep -v ^#); do
		local _u _uid _gid _c _home _shell _pass
		read _u _uid _gid _c _home _shell _pass <<EOF
			$(echo $user | sed 's/:/ /g')
EOF
		msg 1 "\t${_u} (${_c})"
		_ssh ${RUN_USER}@${SERVER} "grep -q ^${_u} /etc/passwd || \
			/usr/sbin/useradd \
				-s ${_shell} \
				-c '${_c}' \
				-d '${_home}' \
				-m \
				-g ${_gid} \
				-u ${_uid} \
				-p ${_pass} \
				${_u}"
	done
fi

if [ -f ./files ]; then
	msg 0 "installing $(fnc files)"
	for file in $(cat files | grep -v ^#); do
		local _src _dest _mode _owner _group _dir
		read _src _owner _group _mode _dest <<EOF
			$(echo $file | sed 's/:/ /g')
EOF
		_dir=$(dirname $_dest)
		msg 1 "\t${_src} -> ${_dest}"
		msg 2 "\t\tmkdir -p ${_dir}"
		msg 2 "\t\tchown ${_owner}:${_group} $_dest"
		msg 2 "\t\tchmod ${_mode} $_dest"

		_ssh ${RUN_USER}@${SERVER} "mkdir -p ${_dir}"
		_rsync $_src "${RUN_USER}@${SERVER}:$_dest"
		_ssh ${RUN_USER}@${SERVER} "/sbin/chown ${_owner}:${_group} \
			$_dest; /bin/chmod ${_mode} $_dest"
	done
fi

if [ -f ./services ]; then
	msg 0 "enabling services $(fnc services)"
	local _svc _chfile
	for service in $(cat services | grep -v ^#); do
		read _svc _chfile <<EOF
			$(echo $service | sed 's/:/ /g')
EOF
		msg 1 "\tenabling/restarting ${_svc}"
		cmd="$(printf "$SERVICE_START_RESTART" \
			$_svc $_svc $_chfile $_svc $_svc $_svc $_svc)"
		_ssh ${RUN_USER}@${SERVER} "${cmd}"
	done
fi

if [ $MAINTENANCE == 1 ]; then
	msg 0 "cleaning up unused packages"
	_ssh ${RUN_USER}@${SERVER} "/usr/sbin/pkg_delete $V -a"
	msg 0 "updating installed packages"
	_ssh ${RUN_USER}@${SERVER} "/usr/sbin/pkg_add $V -u"
	msg 0 "installing firmware updates"
	_ssh ${RUN_USER}@${SERVER} "/usr/sbin/fw_update $V"
fi

if [ -f ./commands ]; then
	local _tmp=$(mktemp)
	rm $_tmp
	msg 0 "executing 'commands' file"
	_scp commands "${RUN_USER}@${SERVER}:${_tmp}"
	_ssh ${RUN_USER}@${SERVER} "chmod +x ${_tmp}; . ${_tmp}; rm ${_tmp}"
fi
