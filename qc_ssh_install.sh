#!/bin/bash

set -o nounset
declare -r ROOTDEV="${1:-}"
declare -r MNTDIR="/mnt/a"
declare -r SSHAUTHTAR="/home/malo/src/neural_quadcortex/install_ssh/qc_ssh_root.tgz"
declare -r tmpfile="/tmp/$$.t.sh"
declare -i rc=0

function finish {
  sudo rm -r ${tmpfile}
  sudo umount /mnt/a 2>/dev/null
}

Usage(){
	echo "$0 </dev/sdX> - need a root device"
}

FatalError(){
	local -r msg="${1:-}"
	echo "Fatal Error: ${msg}"
	exit 99
}

Create_Tmp_File(){
	sudo rm -f ${tmpfile} && \
	touch ${tmpfile} && \
	sudo chown $USER: ${tmpfile} && \
	sudo chmod 0700 ${tmpfile}
}

MAIN(){
	echo "Using root device ${ROOTDEV}"
	mount|grep "${MNTDIR}" && FatalError "/mnt/a already in use"
	mkdir -p ${MNTDIR} || FatalError "Failed to mount ${MNTDIR}"
	sudo mount ${ROOTDEV} ${MNTDIR}
	sudo test -d ${MNTDIR}/opt/neuraldsp || FatalError "unable to find directory: ${MNTDIR}/opt/neuraldsp"
	sudo touch ${MNTDIR}/opt/neuraldsp/allow_sshd || {
		sudo umount /mnt/a
		FatalError "failed to touch ${MNTDIR}/opt/neuraldsp/allow_sshd"
	}
	
	Create_Tmp_File
	
	cat >${tmpfile} <<_EOF
#!/bin/bash
	
id -u|grep '^0$' || {
	echo "Must be uid 0"
	exit 99
}
	
cd ${MNTDIR}/root || exit 99
echo "Install ssh authorized_keys"
tar xzf ${SSHAUTHTAR}
## make sire that the permission are right.
## otherwise we see this error @logs/system/<NNN>-mmcblk0p1.log
# Authentication refused: bad ownership or modes for file /root/.ssh/authorized_keys
chmod 0700 .ssh
chmod 0644 .ssh/authorized_keys

## customize sshd config
sed -i -e 's/#PermitRootLogin yes/PermitRootLogin yes/' -e 's/.*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
-e 's/.*UseDNS .*/UseDNS no/' ${MNTDIR}/etc/ssh/sshd_config

echo "Login port will be:"
grep -w 'Port 57284' ${MNTDIR}/etc/ssh/sshd_config
_EOF
	
	sudo ${tmpfile}
}

## call MAIN ###
if [[ -z "${ROOTDEV}" ]]
then
	Usage
	exit 99
fi

trap finish EXIT
MAIN 2>&1|tee qc_ssh_install.log

exit ${rc}
