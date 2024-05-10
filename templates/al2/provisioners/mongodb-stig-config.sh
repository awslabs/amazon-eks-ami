#!/usr/bin/env bash

auditd_rules_changed=0

# 1.1.1.1 Ensure mounting of cramfs filesystems is disabled
# 1.1.1.2 Ensure mounting of hfs filesystems is disabled
# 1.1.1.3 Ensure mounting of hfsplus filesystems is disabled
# 1.1.1.4 Ensure mounting of squashfs filesystems is disabled
# 1.1.1.5 Ensure mounting of udf filesystems is disabled
# 3.4.2 Ensure SCTP is disabled
# 3.4.3 Ensure RDS is disabled
# 3.4.4 Ensure TIPC is disabled
function disable_unwanted_kernel_modules() {
  for mod in \
      cramfs \
      hfs \
      hfsplus \
      squashfs \
      udf \
      SCTP \
      RDS \
      TIPC \
    ; do
    if ! grep -q "install ${mod} /bin/true" "/etc/modprobe.d/${mod}.conf"; then
      echo "Disabling kernel module ${mod}."
      echo "install ${mod} /bin/true" > "/etc/modprobe.d/${mod}.conf"
    else
      echo "Kernel module ${mod} already disabled."
    fi

    if lsmod | grep -q "${mod}"; then
      echo "${mod} currently loaded, removing ${mod} module."
      rmmod "${mod}"
    fi
  done
}

# 1.1.2 Ensure /tmp is configured
# 1.1.3 Ensure separate file system for /tmp
# 1.1.4 Ensure nodev option set on /tmp partition
# 1.1.5 Ensure nosuid option set on /tmp partition
# 1.1.6 Ensure noexec option set on /tmp partition
function V72065_configure_tmp() {
  # adjust stock systemd tmp.mount config and enable
  local Config="/usr/lib/systemd/system/tmp.mount"
  local Success="Ensured /tmp is configured, per Tenable 1.1.2."
  local Failure="Failed to ensure /tmp is configured, not in compliance with Tenable 1.1.2."
  local Contents
  Contents=$(cat <<EOF
# DO NOT EDIT
# THIS FILE IS MANAGED BY STIG SCRIPT
# ANY CHANGES WILL BE OVERWRITTEN

[Unit]
Description=Temporary Directory
Documentation=man:hier(7)
Documentation=http://www.freedesktop.org/wiki/Software/systemd/APIFileSystems
ConditionPathIsSymbolicLink=!/tmp
DefaultDependencies=no
Conflicts=umount.target
Before=local-fs.target umount.target

[Mount]
What=tmpfs
Where=/tmp
Type=tmpfs
Options=mode=1777,strictatime,noexec,nodev,nosuid

[Install]
WantedBy=local-fs.target
EOF
)

  if [[ "$(echo "${Contents}" | sha256sum)" != "$(sha256sum < "${Config}")" ]]; then
    echo "Writing /tmp mount configuration to ${Config}."
    echo "${Contents}" > "${Config}"
  fi

  if ! systemctl is-enabled tmp.mount; then
    echo "Enabling tmp.mount."
    systemctl enable tmp.mount
  fi

  (systemctl is-enabled tmp.mount && echo "${Success}") || {
    echo "${Failure}"
  }
}

# 1.1.18 Ensure noexec option set on /dev/shm partition
function configure_dev_shm() {
  local Config="/etc/fstab"
  local Regex1="/dev/shm *tmpfs"
  local Regex2="/dev/shm .*noexec"
  local Success="Ensured /dev/shm is tmpfs partition with noexec option set, per Tenable 1.1.18."
  local Failure="Failed to ensure /dev/shm is tmpfs partition with noexec option set, not in compliance with Tenable 1.1.18."

  if ! grep -q "${Regex1}" "${Config}"; then
    echo "Configuring /dev/shm partition."
    echo "tmpfs /dev/shm tmpfs defaults,noexec,nodev,nosuid 0 0" >> "${Config}"
    mount -o remount,noexec,nodev,nosuid /dev/shm
  fi

  (grep -q "${Regex1}" "${Config}" && grep -q "${Regex2}" "${Config}" && echo "${Success}") || {
    echo "${Failure}"
  }
}

# 1.2.4 Ensure software packages have been digitally signed by a Certificate Authority (CA)
function V71979_local_yum_signed() {
  local Config="/etc/yum.conf"
  local Regex1="^ *localpkg_gpgcheck *= *1"
  local Success="Ensured software packages are digitally signed by a Certificate Authority, per Tenable 1.2.4."
  local Failure="Failed to ensure software packages are digitally signed by a Certificate Authority, not in compliance with Tenable 1.2.4."

  if ! grep -q "${Regex1}" "${Config}"; then
    echo "Configuring yum local package GPG check."
    echo "localpkg_gpgcheck=1" >> /etc/yum.conf
  fi

  (grep -q "${Regex1}" "${Config}" && echo "${Success}") || {
    echo "${Failure}"
  }
}

# 1.5.2 Ensure address space layout randomization (ASLR) is enabled
# 3.2.1 Ensure source routed packets are not accepted
# 3.2.2 Ensure ICMP redirects are not accepted
# 3.2.3 Ensure secure ICMP redirects are not accepted
# 3.2.4 Ensure suspicious packets are logged
# 3.2.5 Ensure broadcast ICMP requests are ignored
# 3.2.6 Ensure bogus ICMP responses are ignored
# 3.2.7 Ensure Reverse Path Filtering is enabled
# 3.2.8 Ensure TCP SYN Cookies is enabled
# 3.2.9 Ensure IPv6 router advertisements are not accepted
# 3.2.10 Ensure rate limiting measures are set
function sysctl_settings() {
  local ConfigBase="/etc/sysctl.d/99-stig"
  # all 0 values
  for sysctl in \
    net.ipv4.conf.all.accept_redirects \
    net.ipv4.conf.all.secure_redirects \
    net.ipv4.conf.all.send_redirects \
    net.ipv4.conf.default.accept_redirects \
    net.ipv4.conf.default.secure_redirects \
    net.ipv4.conf.default.send_redirects \
    net.ipv6.conf.all.accept_ra \
    net.ipv6.conf.all.accept_redirects \
    net.ipv6.conf.default.accept_ra \
    net.ipv6.conf.default.accept_redirects \
    ; do
    echo "Current value for $sysctl: $(cat /proc/sys/"$(echo $sysctl | tr '.' '/')")"
    if [[ ! -f "${ConfigBase}-${sysctl}.conf" ]]; then
      echo "${sysctl} = 0" > "${ConfigBase}-${sysctl}.conf"
    fi
  done

  # all 1 values
  for sysctl in \
    net.ipv4.conf.all.log_martians \
    net.ipv4.conf.all.rp_filter \
    net.ipv4.conf.default.log_martians \
    net.ipv4.icmp_echo_ignore_broadcasts \
    net.ipv4.icmp_ignore_bogus_error_responses \
    net.ipv4.tcp_syncookies \
    ; do
    echo "Current value for $sysctl: $(cat /proc/sys/"$(echo $sysctl | tr '.' '/')")"
    if [[ ! -f "${ConfigBase}-${sysctl}.conf" ]]; then
      echo "${sysctl} = 1" > "${ConfigBase}-${sysctl}.conf"
    fi
  done

  # all 2 values
  for sysctl in \
    kernel.randomize_va_space \
    ; do
    echo "Current value for $sysctl: $(cat /proc/sys/"$(echo $sysctl | tr '.' '/')")"
    if [[ ! -f "${ConfigBase}-${sysctl}.conf" ]]; then
      echo "${sysctl} = 2" > "${ConfigBase}-${sysctl}.conf"
    fi
  done

  # the rest
  sysctl="net.ipv4.tcp_invalid_ratelimit"
  echo "Current value for $sysctl: $(cat /proc/sys/"$(echo $sysctl | tr '.' '/')")"
  if [[ ! -f "${ConfigBase}-${sysctl}.conf" ]]; then
    echo "net.ipv4.tcp_invalid_ratelimit = 500" > "${ConfigBase}-${sysctl}.conf"
  fi

  # enable all sysctl settings
  sysctl --system
}

# 2.2.1.3 Ensure chrony is configured
function chrony_options() {
  local Config="/etc/sysconfig/chronyd"
  local Regex1="^OPTIONS=\".*-u chrony.*\""
  local Regex2="s/^OPTIONS=\"(.*)\"$/OPTIONS=\"\1 -u chrony\"/"
  local Success="Ensured chrony is configured, per Tenable 2.2.1.3."
  local Failure="Failed to ensure chrony is configured, not in compliance with Tenable 2.2.1.3."

  if ! rpm -q chrony > /dev/null; then
    echo "Chrony is not installed. Skipping this check."
    return
  fi

  if [[ ! -f "${Config}" ]]; then
    echo "OPTIONS=\"-u chrony\"" >> "${Config}"
  elif ! grep -E -q "${Regex1}" "${Config}"; then
    sed -i -r -e "${Regex2}" "${Config}"
  fi
  (grep -E -q "${Regex1}" "${Config}" && systemctl restart chronyd.service && echo "${Success}") || {
        echo "${Failure}"
    }
}

# 2.2.8 Ensure NFS and RPC are not enabled
function disable_nfs_rpc() {
  local Services="nfs nfs-server rpcbind rpcbind.socket rpc-statd-notify rpc-statd-notify.socket"
  local Success="Ensured NFS and RPC are not enabled, per Tenable 2.2.8."
  local Failure="Failed to ensure NFS and RPC are not enabled, not in compliance with Tenable 2.2.8."

  for service in ${Services}; do
    if systemctl is-enabled "${service}" > /dev/null; then
      echo "Disabling ${service}."
      systemctl disable "${service}"
      systemctl stop "${service}"
    fi
  done

  failures=0
  for service in ${Services}; do
    if systemctl is-enabled "${service}" > /dev/null; then
      failures=$((failures + 1))
      echo "Failed to disable ${service}."
    fi
  done
  ( [[ "${failures}" -eq 0 ]] && echo "${Success}" ) || echo "${Failure}"
}

# 2.2.25 Ensure unrestricted mail relaying is prevented.
# https://www.stigviewer.com/stig/red_hat_enterprise_linux_7/2017-12-14/finding/V-72297
function V72297_restrict_mail_relay() {
  local Config="/etc/postfix/main.cf"
  local Regex1="^smtpd_client_restrictions\s*=\s*permit_mynetworks\s*,\s*reject"
  local Success="Ensured unrestricted mail relaying is prevented, per Tenable 2.2.25 / STIG V-72297."
  local Failure="Failed to ensure unrestricted mail relaying is prevented, not in compliance with Tenable 2.2.25 / STIG V-72297."

  if ! rpm -q postfix > /dev/null; then
    echo "Postfix is not installed. Skipping this check."
    return
  fi

  if ! grep -E -q "${Regex1}" "${Config}"; then
    echo "smtpd_client_restrictions = permit_mynetworks,reject" >> "${Config}"
  fi
  (grep -E -q "${Regex1}" "${Config}" && systemctl restart postfix.service && echo "${Success}") || {
        echo "${Failure}"
    }
}

# 2.3.4 Ensure telnet client is not installed
# https://www.stigviewer.com/stig/red_hat_enterprise_linux_7/2017-12-14/finding/V-72077
function V72077_remove_telnet() {
  local Success="Ensured telnet client is not installed, per Tenable 2.3.4 / STIG V-72077."
  local Failure="Failed to ensure telnet client is not installed, not in compliance with Tenable 2.3.4 / STIG V-72077."

  if rpm -q telnet > /dev/null; then
    yum -y remove telnet
  fi

  (rpm -q telnet > /dev/null && {
    echo "${Failure}"
  }) || echo "${Success}"
}

# 4.1.4 Ensure auditing for processes that start prior to auditd is enabled
# Also verify that FIPS is enabled
function update_kernel_flags() {
  local Regex1="args=.*(fips|audit)=1.*(fips|audit)=1"
  local Success="Ensured auditing for processes that start prior to auditd is enabled, per Tenable 4.1.4."
  local Failure="Failed to ensure auditing for processes that start prior to auditd is enabled, not in compliance with Tenable 4.1.4."

  local Config
  Config="$(grubby --info=DEFAULT)"
  if ! echo "${Config}" | grep -Eq "${Regex1}"; then
    echo -e "Adding \"fips=1 audit=1\" to grub, current config:\n${Config}."
    grubby --update-kernel=ALL --args="fips=1 audit=1"
    echo "After:"
    grubby --info=DEFAULT
  fi

  (grubby --info=DEFAULT | grep -Eq "${Regex1}" && echo "${Success}") || {
    echo "${Failure}"
  }
}

# 4.1.*
function common_auditd_rules() {
  local Config="/etc/audit/rules.d/10-stig.rules"
  local Rules
  Rules=$(cat <<EOF
# DO NOT EDIT
# THIS FILE IS MANAGED BY STIG SCRIPT
# ANY CHANGES WILL BE OVERWRITTEN

# 4.1.2.13 Ensure audit of kmod command
-w /usr/bin/kmod -p x -F auid!=4294967295 -k module-change

# 4.1.2.17 Ensure audit of the create_module syscall
-a always,exit -F arch=b64 -S create_module -k module-change
-a always,exit -F arch=b32 -S create_module -k module-change

# 4.1.2.18 Ensure audit of the finit_module syscall
-a always,exit -F arch=b64 -S finit_module -k module-change
-a always,exit -F arch=b32 -S finit_module -k module-change

# 4.1.2.1 Ensure all uses of the passwd command are audited.
# 4.1.2.2 Ensure auditing of the unix_chkpwd command
# 4.1.2.3 Ensure audit of the gpasswd command
# 4.1.2.4 Ensure audit all uses of chage
# 4.1.2.5 Ensure audit all uses of the newgrp command.
# 4.1.2.6 Ensure audit all uses of the chsh command.
# 4.1.2.7 Ensure audit the umount command
# 4.1.2.8 Ensure audit of postdrop command
# 4.1.2.9 Ensure audit of postqueue command.
# 4.1.2.10 Ensure audit ssh-keysign command.
# 4.1.2.11 Ensure audit of crontab command
# 4.1.2.12 Ensure audit pam_timestamp_check command
# 4.1.2.19 Ensure audit of semanage command
# 4.1.2.20 Ensure audit of the setsebool command.
# 4.1.2.21 Ensure audit of the chcon command
# 4.1.2.22 Ensure audit of setfiles command
# 4.1.2.23 Ensure audit of the userhelper command
# 4.1.2.24 Ensure audit of the su command
# 4.1.2.25 Ensure audit of the mount command
# 4.1.13 Ensure use of privileged commands is collected
# generated on adhoc-1.us-gov-west-1.aws.cloud-gov-qa.10gen.cc and combined with the 4.1.2.x rules,
# removed the -F perm=x filter to log any interaction with any paths explicitly listed rather than only executions
-a always,exit -F path=/usr/bin/wall -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/chage -F auid>=1000 -F auid!=4294967295 -k privileged-passwd
-a always,exit -F path=/usr/bin/gpasswd -F auid>=1000 -F auid!=4294967295 -k privileged-passwd
-a always,exit -F path=/usr/bin/newgrp -F auid>=1000 -F auid!=4294967295 -k privileged-priv_change
-a always,exit -F path=/usr/bin/su -F auid>=1000 -F auid!=4294967295 -k privileged-priv_change
-a always,exit -F path=/usr/bin/crontab -F auid>=1000 -F auid!=4294967295 -k privileged-cron
-a always,exit -F path=/usr/bin/mount -F auid>=1000 -F auid!=4294967295 -k privileged-mount
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/umount -F auid>=1000 -F auid!=4294967295 -k privileged-mount
-a always,exit -F path=/usr/bin/write -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/at -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/passwd -F auid>=1000 -F auid!=4294967295 -k privileged-passwd
-a always,exit -F path=/usr/bin/ssh-agent -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/locate -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/staprun -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/screen -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/sbin/unix_chkpwd -F auid>=1000 -F auid!=4294967295 -k privileged-passwd
-a always,exit -F path=/usr/sbin/pam_timestamp_check -F auid>=1000 -F auid!=4294967295 -k privileged-pam
-a always,exit -F path=/usr/sbin/netreport -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/sbin/usernetctl -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/sbin/userhelper -F auid>=1000 -F auid!=4294967295 -k privileged-passwd
-a always,exit -F path=/usr/sbin/mount.nfs -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-mount
-a always,exit -F path=/usr/sbin/postdrop -F auid>=1000 -F auid!=4294967295 -k privileged-postfix
-a always,exit -F path=/usr/sbin/postqueue -F auid>=1000 -F auid!=4294967295 -k privileged-postfix
-a always,exit -F path=/usr/libexec/utempter/utempter -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/libexec/dbus-1/dbus-daemon-launch-helper -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/libexec/openssh/ssh-keysign -F auid>=1000 -F auid!=4294967295 -k privileged-ssh
-a always,exit -F path=/usr/bin/chsh -F auid>=1000 -F auid!=4294967295 -k privileged-priv_change
-a always,exit -F path=/usr/sbin/semanage -F auid>=1000 -F auid!=4294967295 -k privileged-priv_change
-a always,exit -F path=/usr/sbin/setsebool -F auid>=1000 -F auid!=4294967295 -k privileged-priv_change
-a always,exit -F path=/usr/bin/chcon -F auid>=1000 -F auid!=4294967295 -k privileged-priv_change
-a always,exit -F path=/usr/sbin/setfiles -F auid>=1000 -F auid!=4294967295 -k privileged-priv_change

# 4.1.2.25 Ensure audit of the mount syscall
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k privileged-mount
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k privileged-mount

# mdb: This rule suppresses the time-change event when chrony or node_exporter perform time updates
-a never,exit -F arch=b64 -S adjtimex -F auid=unset -F uid=chrony -F exe=/usr/sbin/chronyd
-a never,exit -F arch=b32 -S adjtimex -F auid=unset -F uid=chrony -F exe=/usr/sbin/chronyd
-a never,exit -F arch=b64 -S adjtimex -F auid=4294967295 -F euid=65534 -F sessionid=4294967295
-a never,exit -F arch=b32 -S adjtimex -F auid=4294967295 -F euid=65534 -F sessionid=4294967295

# mdb: This rule suppresses the iptables (/usr/sbin/xtables-legacy-multi) activity on kubernetes nodes
-a never,exit -F arch=b32 -S setsockopt -F auid=4294967295 -F euid=0 -F sessionid=4294967295
-a never,exit -F arch=b64 -S setsockopt -F auid=4294967295 -F euid=0 -F sessionid=4294967295
-a exclude,never -F msgtype=NETFILTER_CFG -F auid=4294967295 -F uid=0 -F gid=0

# 4.1.5 Ensure events that modify date and time information are collected
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# 4.1.6 Ensure events that modify user/group information are collected
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# 4.1.7 Ensure events that modify the system's network environment are collected
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale

# 4.1.8 Ensure events that modify the system's Mandatory Access Controls are collected
-w /etc/selinux/ -p wa -k MAC-policy
-w /usr/share/selinux/ -p wa -k MAC-policy

# 4.1.9 Ensure login and logout events are collected
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins

# 4.1.10 Ensure session initiation information is collected
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# 4.1.11 Ensure discretionary access control permission modification events are collected
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod

# 4.1.12 Ensure unsuccessful unauthorized file access attempts are collected
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

# 4.1.14 Ensure successful file system mounts are collected
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# 4.1.15 Ensure file deletion events by users are collected
# 4.1.2.14 Ensure audit of the rmdir syscall
# 4.1.2.15 Ensure audit of unlink syscall
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -S rmdir -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -S rmdir -F auid>=1000 -F auid!=4294967295 -k delete

# 4.1.16 Ensure changes to system administration scope (sudoers) is collected
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# 4.1.17 Ensure system administrator actions (sudolog) are collected
-w /var/log/sudo.log -p wa -k actions

# 4.1.19 Ensure kernel module loading and unloading is collected
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules

# 4.1.21 Ensure auditing of all privileged functions
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k setuid
-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k setuid
-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k setgid
-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k setgid
EOF
)

  if [[ ! -f "${Config}" || "$(echo "${Rules}" | sha256sum)" != "$(sha256sum < "${Config}")" ]]; then
    echo "Writing common auditd rules to ${Config}."
    echo "${Rules}" > "${Config}"
    auditd_rules_changed=1
  else
    echo "Common auditd rules up to date."
  fi
}

# 4.1.18 Ensure the audit configuration is immutable
function finalize_auditd_rules() {
  # write rule that makes auditd config immutable
  # any further changes to auditd require a reboot for them to take effect
  local Config="/etc/audit/rules.d/zz-stig-final.rules"
  local Rules
  Rules=$(cat <<EOF
# DO NOT EDIT
# THIS FILE IS MANAGED BY STIG SCRIPT
# ANY CHANGES WILL BE OVERWRITTEN

# 4.1.18 Ensure the audit configuration is immutable
# THIS MUST GO AT THE VERY END OF ALL AUDIT RULES
-e 2
EOF
)

  if [[ ! -f "${Config}" || "$(echo "${Rules}" | sha256sum)" != "$(sha256sum < "${Config}")" ]]; then
    echo "Writing finalizing auditd rules in ${Config}."
    echo "${Rules}" > "${Config}"
    auditd_rules_changed=1
  else
    echo "Configuration to make auditd rules immutable is up to date."
  fi

  if [[ "${auditd_rules_changed}" -gt 0 ]]; then
    echo "Restarting auditd to apply rule changes."
    if ! service auditd restart; then
      echo "Failed to restart auditd, a reboot is required to apply the new rules."
    fi
  fi
}

# 4.2.4 Ensure permissions on all logfiles are configured
function configure_log_permissions() {
    # just perform a one-shot of this as part of EKS image building
    echo -n "Configuring permissions on log files: removing group write permissions and other read/write permissions..."
    find /var/log -type f -exec chmod g-wx,o-rwx '{}' + -o -type d -exec chmod g-w,o-rwx '{}' +
    echo "done."
}

# 5.1.* Ensure permissions on various cron files are configured
function configure_cron_permissions() {
  rm -f /etc/at.deny
  rm -f /etc/cron.deny
  touch /etc/at.allow
  touch /etc/cron.allow

  for file in \
    /etc/at.allow \
    /etc/crontab \
    /etc/cron.allow \
    /etc/cron.hourly \
    /etc/cron.daily \
    /etc/cron.weekly \
    /etc/cron.monthly \
    /etc/cron.d \
  ; do
    if [[ ! -e "${file}" ]]; then
      echo "Skipping ${file}, does not exist."
      continue
    fi
    if stat -c %a "${file}" | grep -qE '[0-7]00'; then
      echo "Permissions on ${file} already configured."
      continue
    fi
    echo "Configuring permissions on ${file}."
    chmod og-rwx "${file}"
    chown root:root "${file}"
  done
}

# 5.2.4 Ensure permsissions on /etc/ssh/sshd_config are configured
function configure_ssh_host_key_permissions() {
  # just perform a one-shot of this as part of EKS image building
  echo -n "Configuring permissions on SSH host key files: making readable only by root..."
  find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chown root:root {} \;
  find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chmod 0600 {} \;
  echo "done."
}

# 5.2.* Ensure ssh is configured and hardened
function configure_sshd() {
    local Config="/etc/ssh/sshd_config"
    local Success="Ensured SSH is configured and hardened, per Tenable 5.2.*"
    local Failure="Failed to ensure SSH is configured and hardened, not in compliance with Tenable 5.2.*"
    local Contents
    Contents=$(cat <<EOF
# DO NOT EDIT
# THIS FILE IS MANAGED BY STIG SCRIPT
# ANY CHANGES WILL BE OVERWRITTEN

AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv XMODIFIERS
AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f
AuthorizedKeysCommandUser ec2-instance-connect
AuthorizedKeysFile .ssh/authorized_keys
Banner /etc/issue.net
ChallengeResponseAuthentication no
Ciphers aes128-ctr,aes192-ctr,aes256-ctr
ClientAliveCountMax 0
ClientAliveInterval 600
Compression delayed
GssapiAuthentication no
HostbasedAuthentication no
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
IgnoreRhosts yes
IgnoreUserKnownHosts yes
KerberosAuthentication no
KexAlgorithms diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
LoginGraceTime 60
LogLevel INFO
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
MaxAuthTries 4
PasswordAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
PermitUserEnvironment no
PrintLastLog yes
Protocol 2
PubkeyAcceptedKeyTypes +ssh-ed25519-cert-v01@openssh.com,ssh-ed25519
RhostsRSAAuthentication no
StrictModes yes
Subsystem sftp /usr/libexec/openssh/sftp-server
SyslogFacility AUTHPRIV
UseDNS no
UsePAM yes
UsePrivilegeSeparation sandbox
X11Forwarding no
EOF
)

  # ensure /etc/issue and /etc/issue.net are configured
  cat <<EOF > /etc/issue.net
Authorized uses only. All activity may be monitored and reported.

  * This computer system is the property of the MongoDB Cloud for Government. It is for authorized use only by its employees and customers. By using this system, all users acknowledge notice of and agree to comply with applicable governing laws and privacy policy. Unauthorized or improper use of this system may result in administrative, disciplinary and/or legal action, civil charges/criminal penalties and/or other sanctions as set forth in the MongoDB Cloud for Government Information Security Policy. By continuing to use this system you indicate your awareness of and consent to these terms and conditions of use.
  * Users are accessing a U.S. Government information system;
  * Information system usage may be monitored, recorded, and subject to audit;
  * Unauthorized use of the information system is prohibited and subject to criminal and civil penalties; and
  * Use of the information system indicates consent to monitoring and recording.
EOF
  cp /etc/issue.net /etc/issue
  chown root:root /etc/issue.net /etc/issue
  chmod 644 /etc/issue.net /etc/issue
    
  if [[ "$(echo "${Contents}" | sha256sum)" != "$(sha256sum < "${Config}")" ]]; then
    echo "Writing sshd configuration to ${Config}."
    echo "${Contents}" > "${Config}"
  fi

  (grep -q "${Regex1}" "${Config}" && systemctl restart sshd.service && echo "${Success}") || {
    echo "${Failure}"
  }
}

# 5.4.1.10 Ensure delay between logon prompts on failure
function V71951_delay_logon_failures() {
  local Config="/etc/login.defs"
  local Regex1="^ *FAIL_DELAY *4"
  local Contents="FAIL_DELAY 4"
  local Success="Ensured delay between logon prompts on failure, per STIG V-71951 / Tenable 5.4.1.10."
  local Failure="Failed to ensure delay between logon prompts on failure, not in compliance with STIG V-71951 / Tenable 5.4.1.10."

  if ! grep -q "${Regex1}" "${Config}"; then
    echo "Setting FAIL_DELAY to 4 in ${Config}."
    echo "${Contents}" >> "${Config}"
  fi

  (grep -q "${Regex1}" "${Config}" && echo "${Success}") || {
    echo "${Failure}"
  }
}

# 5.4.4 Ensure default user umask is 027 or more restrictive
function set_default_user_umask() {
  local SystemConfigs="/etc/bashrc /etc/profile"
  # specific to EKS iamges
  local UserConfigs="/home/ec2-user/.bashrc /home/ec2-user/.bash_profile"
  local Regex1="^ *umask 027"
  local Regex2="^ *umask 077"
  local Regex3="^ *umask 0[27]7"
  local Success="Ensured default user umask is 027 or more restrictive, per STIG V-72049 / Tenable 5.4.4."
  local Failure="Failed to ensure default user umask is 027 or more restrictive, not in compliance with STIG V-72049 / Tenable 5.4.4."

  for config in ${SystemConfigs}; do
    if ! grep -q "${Regex1}" "${config}"; then
      echo "Setting default umask to 027 in ${config}."
      echo "umask 027" >> "${config}"
    fi
  done

  for config in ${UserConfigs}; do
    if ! grep -q "${Regex2}" "${config}"; then
      echo "Setting user umask to 077 in ${config}."
      echo "umask 077" >> "${config}"
    fi
  done

  local failures=0
  for config in ${SystemConfigs} ${UserConfigs}; do
    if ! grep -q "${Regex3}" "${config}"; then
      failures=$((failures + 1))
      echo "Failed to set umask properly in ${config}."
    fi
  done
  ( [[ "${failures}" -eq 0 ]] && echo "${Success}" ) || echo "${Failure}"
}

# 5.4.11 Ensure default user shell timeout is 600 seconds or less
function V72223_shell_timeout() {
  local Config="/etc/profile.d/timeout.sh"
  local Contents
  Contents=$(cat <<EOF
#!/bin/bash

# DO NOT EDIT
# THIS FILE IS MANAGED BY STIG SCRIPT
# ANY CHANGES WILL BE OVERWRITTEN

TMOUT=600
readonly TMOUT
export TMOUT
EOF
)

  if [[ ! -f "${Config}" || "$(echo "${Contents}" | sha256sum)" != "$(sha256sum < "${Config}")" ]]; then
    echo "Writing shell timeout configuration to ${Config}."
    echo "${Contents}" > "${Config}"
    chmod 644 /etc/profile.d/timeout.sh
  fi
}

# 6.1.6 Ensure permissions on /etc/passwd- are configured
function passwd_permissions() {
  local Success="Ensured permissions on /etc/passwd- are configured, per Tenable 6.1.6."
  local Failure="Failed to ensure permissions on /etc/passwd- are configured, not in compliance with Tenable 6.1.6."

  if stat -c '%u:%g:%a' /etc/passwd- | grep -q '0:0:600'; then
    echo "Permissions on /etc/passwd- already configured."
  else
    echo "Configuring permissions on /etc/passwd-."
    chown root:root /etc/passwd-
    chmod 600 /etc/passwd-
  fi

  (stat -c '%u:%g:%a' /etc/passwd- | grep -q '0:0:600' && echo "${Success}") || {
    echo "${Failure}"
  }
}

# functions to run on all VMs
function apply_stigs() {
  disable_unwanted_kernel_modules
  V72065_configure_tmp
  configure_dev_shm
  V71979_local_yum_signed
  sysctl_settings
  chrony_options
  disable_nfs_rpc
  V72297_restrict_mail_relay
  V72077_remove_telnet
  update_kernel_flags
  common_auditd_rules
  configure_log_permissions
  configure_cron_permissions
  configure_ssh_host_key_permissions
  configure_sshd
  V71951_delay_logon_failures
  set_default_user_umask
  V72223_shell_timeout
  passwd_permissions
}

# execute above functions
apply_stigs

finalize_auditd_rules

# we know in kube this is just for image building - don't return a non-zero exit code
exit 0