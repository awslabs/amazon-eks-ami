#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

tmpfs_and_mount() {
  FOLDER_PATH=$1

  mkdir -p ${FOLDER_PATH}
  echo "tmpfs ${FOLDER_PATH} tmpfs mode=1777,strictatime,noexec,nodev,nosuid 0 0" >> /etc/fstab
  mount -a
}

unload_module() {
  local fsname=$1

  rmmod "${fsname}" || true
  mkdir -p /etc/modprobe.d/
  echo "install ${fsname} /bin/true" > "/etc/modprobe.d/${fsname}.conf"
}

systemd_disable() {
  local service_name=$1

  if systemctl is-enabled $service_name; then
    systemctl disable $service_name
  fi
}

yum_remove() {
  local package_name=$1

  if rpm -q $package_name; then
    yum remove -y $package_name
  fi
}

sysctl_entry() {
  local entry=$1

  echo "$entry" >> /etc/sysctl.d/cis.conf
}

set_conf_value() {
  local key=$1
  local value=$2
  local file=$3

  sed -i "s/^\(${key}\s*=\s*\).*$/\1${value}/" $file
}

# install epel
amazon-linux-extras install -y epel
yum update -y

echo "1.1.1.1 - ensure mounting of cramfs filesystems is disabled"
unload_module cramfs

echo "1.1.1.2 - ensure mounting of hfs filesystems is disabled"
unload_module hfs

echo "1.1.1.3 - ensure mounting of hfsplus filesystems is disabled"
unload_module hfsplus

echo "1.1.1.4 - ensure mounting of squashfs filesystems is disabled"
unload_module squashfs

echo "1.1.1.5 - ensure mounting of udf filesystems is disabled"
unload_module udf

echo "1.1.2 - 1.1.5 - ensure /tmp is configured nodev,nosuid,noexec options set on  /tmp partition"
systemctl unmask tmp.mount && systemctl enable tmp.mount

cat > /etc/systemd/system/local-fs.target.wants/tmp.mount <<EOF
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

# Make 'systemctl enable tmp.mount' work:
[Install]
WantedBy=local-fs.target
EOF

systemctl daemon-reload && systemctl restart tmp.mount

echo "1.1.6 - ensure separate partition exists for /var"

echo "1.1.7 - 1.1.10 - ensure separate partition exists for /var/tmp nodev, nosuid, noexec option set"
tmpfs_and_mount /var/tmp

echo "1.1.11 - ensure separate partition exists for /var/log"

echo "1.1.12 - ensure separate partition exists for /var/log/audit"

echo "1.1.13 - ensure separate partition exists for /home"

echo "1.1.15 - 1.1.17 - ensure nodev,nosuid,noexec option set on /dev/shm"
echo "tmpfs  /dev/shm  tmpfs  defaults,nodev,nosuid,noexec  0 0" >> /etc/fstab
mount -a

echo "1.1.19 - disable automounting"
systemd_disable autofs

echo "1.2.1 - ensure package manager repositories are configured"
yum repolist

echo "1.2.2 - ensure GPG keys are configured"
rpm -q gpg-pubkey --qf '%{name}-%{version}-%{release} --> %{summary}\n'

echo "1.2.3 - ensure gpgcheck is globally activated"
grep ^gpgcheck /etc/yum.conf
grep ^gpgcheck /etc/yum.repos.d/*

echo "1.3.1 - ensure AIDE is installed"
yum install -y aide
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

echo "1.3.2 - ensure filesystem integrity is regularly checked"
echo "0 5 * * * /usr/sbin/aide --check" > /etc/cron.d/aide

echo "1.4.1 - ensure permissions on bootloader config are configured"
chown root:root /boot/grub2/grub.cfg
chmod og-rwx /boot/grub2/grub.cfg

echo "1.4.2 - ensure authentication required for single user mode"
cat > /usr/lib/systemd/system/rescue.service <<EOF
[Unit]
Description=Rescue Shell
Documentation=man:sulogin(8)
DefaultDependencies=no
Conflicts=shutdown.target
After=sysinit.target plymouth-start.service
Before=shutdown.target

[Service]
Environment=HOME=/root
WorkingDirectory=/root
ExecStartPre=-/bin/plymouth quit
ExecStartPre=-/bin/echo -e 'Welcome to emergency mode! After logging in, type "journalctl -xb" to view\\nsystem logs, "systemctl reboot" to reboot, "systemctl default" or ^D to\\nboot into default mode.'
ExecStart=-/bin/sh -c "/usr/sbin/sulogin; /usr/bin/systemctl --fail --no-block default"
Type=idle
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
KillMode=process
IgnoreSIGPIPE=no
SendSIGHUP=yes
EOF

cat > /usr/lib/systemd/system/emergency.service <<EOF
[Unit]
Description=Emergency Shell
Documentation=man:sulogin(8)
DefaultDependencies=no
Conflicts=shutdown.target
Conflicts=rescue.service
Before=shutdown.target

[Service]
Environment=HOME=/root
WorkingDirectory=/root
ExecStartPre=-/bin/plymouth quit
ExecStartPre=-/bin/echo -e 'Welcome to emergency mode! After logging in, type "journalctl -xb" to view\\nsystem logs, "systemctl reboot" to reboot, "systemctl default" or ^D to\\ntry again to boot into default mode.'
ExecStart=-/bin/sh -c "/usr/sbin/sulogin; /usr/bin/systemctl --fail --no-block default"
Type=idle
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
KillMode=process
IgnoreSIGPIPE=no
SendSIGHUP=yes
EOF

systemctl daemon-reload

echo "1.5.1 - ensure core dumps are restricted"
echo "* hard core 0" > /etc/security/limits.d/cis.conf
sysctl_entry "fs.suid_dumpable = 0"

echo "1.5.2 - ensure address space layout randomization (ASLR) is enabled"
sysctl_entry "kernel.randomize_va_space = 2"

echo "1.5.3 - ensure prelink is disabled"
yum_remove prelink

echo "1.7.1.1 - ensure message of the day is configured properly"
rm -f /etc/cron.d/update-motd
cat > /etc/update-motd.d/30-banner <<"OUTEREOF"
#!/bin/sh
cat <<"EOF"
Use of this system is restricted to authorized users only. All information
and communications on this system are subject to auditing and monitoring without
notice. Unautorized access is subject to prosecution.
EOF
OUTEREOF

echo "1.7.1.2 - ensure local login warning banner is configured properly"
cat > /etc/issue <<EOF
Use of this system is restricted to authorized users only. All information
and communications on this system are subject to auditing and monitoring without
notice. Unautorized access is subject to prosecution.
EOF

echo "1.7.1.3 - ensure remote login warning banner is configured properly"
cat > /etc/issue.net <<EOF
Use of this system is restricted to authorized users only. All information
and communications on this system are subject to auditing and monitoring without
notice. Unautorized access is subject to prosecution.
EOF

echo "1.7.1.4 - ensure permissions on /etc/motd are configured"
chown root:root /etc/motd
chmod 644 /etc/motd

echo "1.7.1.5 - ensure permissions on /etc/issue are configured"
chown root:root /etc/issue
chmod 644 /etc/issue

echo "1.7.1.6 - ensure permissions on /etc/issue.net are configured"
chown root:root /etc/issue.net
chmod 644 /etc/issue.net

echo "1.8 - ensure updates, patches, and additional security software are installed"
yum update -y

echo "2.1.2 - ensure X Window System is not installed"
yum_remove xorg-x11*

echo "2.1.3 - ensure Avahi Server is not enabled"
systemd_disable avahi-daemon

echo "2.1.4 - ensure CUPS is not enabled"
systemd_disable cups

echo "2.1.5 - ensure DHCP Server is not enabled"
systemd_disable dhcpd

echo "2.1.6 - ensure LDAP Server is not enabled"
systemd_disable slapd

echo "2.1.7 - ensure NFS and RPC are not enabled"
systemd_disable nfs
systemd_disable nfs-server
systemd_disable rpcbind

echo "2.1.8 - ensure DNS Server is not enabled"
systemd_disable named

echo "2.1.9 - ensure FTP Server is not enabled"
systemd_disable vsftpd

echo "2.1.10 - ensure HTTP Server is not enabled"
systemd_disable httpd

echo "2.1.11 - ensure IMAP and POP3 Server is not enabled"
systemd_disable dovecot

echo "2.1.12 - ensure Samba is not enabled"
systemd_disable smb

echo "2.1.13 - ensure HTTP Proxy Server is not enabled"
systemd_disable squid

echo "2.1.14 - ensure SNMP Server is not enabled"
systemd_disable snmpd

echo "2.1.15 - ensure mail transfer agent is configured for local-only mode"
netstat -an | grep LIST | grep ":25[[:space:]]"

echo "2.1.16 - ensure NIS Server is not enabled"
systemd_disable ypserv

echo "2.1.17 - ensure rsh Server is not enabled"
systemd_disable rsh.socket
systemd_disable rlogin.socket
systemd_disable rexec.socket

echo "2.1.18 - ensure telnet Server is not enabled"
systemd_disable telnet.socket

echo "2.1.19 - ensure tftp Server is not enabled"
systemd_disable tftp.socket

echo "2.1.20 - ensure rsync service is not enabled"
systemd_disable rsyncd

echo "2.1.21 - ensure talk service is not enabled"
systemd_disable ntalk

echo "2.2.1 - ensure NIS Client is not installed"
yum_remove ypbind

echo "2.2.2 - ensure rsh client is not installed"
yum_remove rsh

echo "2.2.3 - ensure talk client is not installed"
yum_remove talk

echo "2.2.3 - ensure telnet client is not installed"
yum_remove telnet

echo "2.2.4 - ensure LDAP client is not installed"
yum_remove openldap-clients

echo "3.1.1 - ensure IP forwarding is disabled"
sysctl_entry "net.ipv4.ip_forward = 0"
sysctl_entry "net.ipv6.conf.all.forwarding = 0"

echo "3.1.2 - ensure packet redirect sending is disabled"
sysctl_entry "net.ipv4.conf.all.send_redirects = 0"
sysctl_entry "net.ipv4.conf.default.send_redirects = 0"

echo "3.3.1 - ensure TCP Wrappers is installed"
yum install -y tcp_wrappers

echo "3.4.1 - ensure DCCP is disabled"
unload_module dccp

echo "3.4.2 - ensure SCTP is disabled"
unload_module sctp

echo "3.4.3 - ensure RDS is disabled"
unload_module rds

echo "3.4.4 - ensure TIPC is disabled"
unload_module tipc

echo "4.1.1.1 - ensure audit log storage size is configured"
yum install -y audit
set_conf_value max_log_file 10 /etc/audit/auditd.conf

echo "4.1.1.2 - ensure system is disabled when audit logs are full"
set_conf_value space_left_action email /etc/audit/auditd.conf
set_conf_value action_mail_acct root /etc/audit/auditd.conf
set_conf_value admin_space_left_action halt /etc/audit/auditd.conf

echo "4.1.1.3 - ensure audit logs are not automatically deleted"
set_conf_value max_log_file_action keep_logs /etc/audit/auditd.conf

echo "4.1.2 - ensure auditd service is enabled"
systemctl enable auditd && systemctl start auditd

echo "4.1.3 - ensure auditing for processes that start prior to auditd is enabled"
sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)"$/\1 audit=1"/' /etc/default/grub
grub2-mkconfig -o /etc/grub2.cfg

echo "4.1.4 - ensure events that modify date and time information are collected"
echo "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b64 -S clock_settime -k time-change" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S clock_settime -k time-change" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/localtime -p wa -k time-change" >> /etc/audit/rules.d/cis.rules

echo "4.1.5 - ensure events that modify user/group information are collected"
echo "-w /etc/group -p wa -k identity" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/passwd -p wa -k identity" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/gshadow -p wa -k identity" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/shadow -p wa -k identity" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/security/opasswd -p wa -k identity" >> /etc/audit/rules.d/cis.rules

echo "4.1.6 - ensure events that modify the system's network environment are collected"
echo "-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/issue -p wa -k system-locale" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/issue.net -p wa -k system-locale" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/hosts -p wa -k system-locale" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/sysconfig/network -p wa -k system-locale" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/sysconfig/network-scripts/ -p wa -k system-locale" >> /etc/audit/rules.d/cis.rules

echo "4.1.6 - ensure events that modify the system's network environment are collected"
echo "-w /etc/selinux/ -p wa -k MAC-policy" >> /etc/audit/rules.d/cis.rules
echo "-w /usr/share/selinux/ -p wa -k MAC-policy" >> /etc/audit/rules.d/cis.rules

echo "4.1.8 - ensure login and logout events are collected"
echo "-w /var/log/lastlog -p wa -k logins" >> /etc/audit/rules.d/cis.rules
echo "-w /var/run/faillock/ -p wa -k logins" >> /etc/audit/rules.d/cis.rules

echo "4.1.9 - ensure session initiation information is collected"
echo "-w /var/run/utmp -p wa -k session" >> /etc/audit/rules.d/cis.rules
echo "-w /var/log/wtmp -p wa -k logins" >> /etc/audit/rules.d/cis.rules
echo "-w /var/log/btmp -p wa -k logins" >> /etc/audit/rules.d/cis.rules

echo "4.1.10 - ensure discretionary access control permission modification events are collected"
echo "-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/rules.d/cis.rules

echo "4.1.11 - ensure unsuccessful unauthorized file access attempts are collected"
echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/rules.d/cis.rules

echo "4.1.12 - ensure use of privileged commands is collected"
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print \
"-a always,exit -F path=" $1 " -F perm=x -F auid>=1000 -F auid!=4294967295 \
-k privileged" }' >> /etc/audit/rules.d/cis.rules

echo "4.1.13 - ensure successful file system mounts are collected"
echo "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >> /etc/audit/rules.d/cis.rules

echo "4.1.14 - ensure file deletion events by users are collected"
echo "-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >> /etc/audit/rules.d/cis.rules

echo "4.1.15 - ensure changes to system administration scope (sudoers) is collected"
echo "-w /etc/sudoers -p wa -k scope" >> /etc/audit/rules.d/cis.rules
echo "-w /etc/sudoers.d/ -p wa -k scope" >> /etc/audit/rules.d/cis.rules

echo "4.1.16 - ensure system administrator actions (sudolog) are collected"
echo "-w /var/log/sudo.log -p wa -k actions" >> /etc/audit/rules.d/cis.rules

echo "4.1.17 - ensure kernel module loading and unloading is collected"
echo "-w /sbin/insmod -p x -k modules" >> /etc/audit/rules.d/cis.rules
echo "-w /sbin/rmmod -p x -k modules" >> /etc/audit/rules.d/cis.rules
echo "-w /sbin/modprobe -p x -k modules" >> /etc/audit/rules.d/cis.rules
echo "-a always,exit -F arch=b64 -S init_module -S delete_module -k modules" >> /etc/audit/rules.d/cis.rules

echo "4.1.18 - ensure the audit configuration is immutable"
echo "-e 2" >> /etc/audit/rules.d/cis.rules

echo "4.2.1.1 - ensure rsyslog Service is enabled"
yum install -y rsyslog
systemctl enable rsyslog

echo "4.2.1.2 - ensure logging is configured"
echo "*.emerg                                  :omusrmsg:*" >> /etc/rsyslog.d/cis.conf
echo "mail.*                                  -/var/log/mail" >> /etc/rsyslog.d/cis.conf
echo "mail.info                               -/var/log/mail.info" >> /etc/rsyslog.d/cis.conf
echo "mail.warning                            -/var/log/mail.warn" >> /etc/rsyslog.d/cis.conf
echo "mail.err                                 /var/log/mail.err" >> /etc/rsyslog.d/cis.conf
echo "news.crit                               -/var/log/news/news.crit" >> /etc/rsyslog.d/cis.conf
echo "news.err                                -/var/log/news/news.err" >> /etc/rsyslog.d/cis.conf
echo "news.notice                             -/var/log/news/news.notice" >> /etc/rsyslog.d/cis.conf
echo "*.=warning;*.=err                       -/var/log/warn" >> /etc/rsyslog.d/cis.conf
echo "*.crit                                   /var/log/warn" >> /etc/rsyslog.d/cis.conf
echo "*.*;mail.none;news.none                 -/var/log/messages" >> /etc/rsyslog.d/cis.conf
echo "local0,local1.*                         -/var/log/localmessages" >> /etc/rsyslog.d/cis.conf
echo "local2,local3.*                         -/var/log/localmessages" >> /etc/rsyslog.d/cis.conf
echo "local4,local5.*                         -/var/log/localmessages" >> /etc/rsyslog.d/cis.conf
echo "local6,local7.*                         -/var/log/localmessages" >> /etc/rsyslog.d/cis.conf

echo "4.2.1.3 - ensure rsyslog default file permissions configured"
echo "\$FileCreateMode 0640" >> /etc/rsyslog.d/cis.conf

echo "4.2.1.4 - ensure rsyslog is configured to send logs to a remote log host"
echo "[not scored] - customer responsible for this configuration"

echo "4.2.1.5 - ensure remote rsyslog messages are only accepted on designated log hosts."
echo "[not scored] - customer responsible for this configuration"

echo "4.2.2.1 - ensure syslog-ng service is enabled"
yum install -y syslog-ng
systemctl enable syslog-ng && systemctl start syslog-ng

echo "4.2.2.2 - Ensure logging is configured"
echo "log { source(src); source(chroots); filter(f_console); destination(console); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_console); destination(xconsole); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_newscrit); destination(newscrit); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_newserr); destination(newserr); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_newsnotice); destination(newsnotice); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_mailinfo); destination(mailinfo); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_mailwarn); destination(mailwarn); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_mailerr);  destination(mailerr); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_mail); destination(mail); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_acpid); destination(acpid); flags(final); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_acpid_full); destination(devnull); flags(final); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_acpid_old); destination(acpid); flags(final); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_netmgm); destination(netmgm); flags(final); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_local); destination(localmessages); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_messages); destination(messages); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_iptables); destination(firewall); };" >> /etc/syslog-ng/conf.d/cis.conf
echo "log { source(src); source(chroots); filter(f_warn); destination(warn); };" >> /etc/syslog-ng/conf.d/cis.conf
pkill -HUP syslog-ng

echo "4.2.2.3 - ensure syslog-ng default file permissions configured"
echo "options { chain_hostnames(off); flush_lines(0); perm(0640); stats_freq(3600); threaded(yes); };" >> /etc/syslog-ng/conf.d/cis.conf

echo "4.2.2.4 - ensure syslog-ng is configured to send logs to a remote log host"
echo "[not scored] - customer responsible for this configuration"

echo "4.2.2.5 - ensure remote syslog-ng messages are only accepted on designated log hosts"
echo "[not scored] - customer responsible for this configuration"

echo "4.2.3 - ensure rsyslog or syslog-ng is installed"
echo "[not scored] - handled by previous steps"

echo "4.2.4 - ensure permissions on all logfiles are configured"
# Update the systemd unit that produces the dmesg log to have a corrected umask,
# which results in correct permissions.
cp /usr/lib/systemd/system/rhel-dmesg.service /etc/systemd/system/rhel-dmesg.service
sed -i -e '/[Service]/a UMask=0027' /etc/systemd/system/rhel-dmesg.service
# Update tmpfiles settings to correct the permissions on the wtmp file:
cp /usr/lib/tmpfiles.d/var.conf /etc/tmpfiles.d/var.conf
sed -i -e 's|/var/log/wtmp 0664|/var/log/wtmp 0660|' /etc/tmpfiles.d/var.conf
systemctl daemon-reload
find /var/log -type f -exec chmod g-wx,o-rwx {} +

echo "4.3 - ensure logrotate is configured"
echo "[not scored] - customer responsible for this configuration"

echo "5.1.1 - ensure cron daemon is enabled"
systemctl enable crond

echo "5.1.2 - ensure permissions on /etc/crontab are configured"
chown root:root /etc/crontab
chmod og-rwx /etc/crontab

echo "5.1.3 - ensure permissions on /etc/cron.hourly are configured"
chown root:root /etc/cron.hourly
chmod og-rwx /etc/cron.hourly

echo "5.1.4 - ensure permissions on /etc/cron.daily are configured"
chown root:root /etc/cron.daily
chmod og-rwx /etc/cron.daily

echo "5.1.5 - ensure permissions on /etc/cron.weekly are configured"
chown root:root /etc/cron.weekly
chmod og-rwx /etc/cron.weekly

echo "5.1.6 - ensure permissions on /etc/cron.monthly are configured"
chown root:root /etc/cron.monthly
chmod og-rwx /etc/cron.monthly

echo "5.1.7 - ensure permissions on /etc/cron.d are configured"
chown root:root /etc/cron.d
chmod og-rwx /etc/cron.d

echo "5.1.8 - ensure at/cron is restricted to authorized users"
rm -f /etc/cron.deny
rm -f /etc/at.deny
touch /etc/cron.allow
touch /etc/at.allow
chmod og-rwx /etc/cron.allow
chmod og-rwx /etc/at.allow
chown root:root /etc/cron.allow
chown root:root /etc/at.allow

echo "5.2.1 - ensure permissions on /etc/ssh/sshd_config are configured"
chown root:root /etc/ssh/sshd_config
chmod og-rwx /etc/ssh/sshd_config

echo "5.2.2 - ensure permissions on SSH private host key files are configured"
find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chown root:ssh_keys {} \;
find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chmod 0640 {} \;

echo "5.2.3 - ensure permissions on SSH public host key files are configured"
find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chmod 0644 {} \;
find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chown root:root {} \;

echo "5.2.3 - 5.2.17, 5.2.19 - SSH Server Configuration"
cat > /etc/ssh/sshd_config <<EOF
# Default Configuration
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
GSSAPIAuthentication yes
GSSAPICleanupCredentials no
UsePAM yes
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem sftp	/usr/libexec/openssh/sftp-server
AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f
AuthorizedKeysCommandUser ec2-instance-connect

# CIS Benchmark Configuration
Protocol 2
LogLevel INFO
X11Forwarding no
MaxAuthTries 4
IgnoreRhosts yes
HostbasedAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
PermitUserEnvironment no
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
ClientAliveInterval 300
ClientAliveCountMax 0
LoginGraceTime 60
Banner /etc/issue.net
EOF

echo "5.2.18 - ensure SSH access is limited"
echo "[not scored] - customer responsible for this configuration"

echo "5.3.1 - ensure password creation requirements are configured"
cat > /etc/security/pwquality.conf <<EOF
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF

echo "5.3.2 - 5.3.4 - Configure PAM"
cat > /etc/pam.d/password-auth <<EOF
auth        required      pam_env.so
auth        sufficient    pam_unix.so try_first_pass nullok
auth        required      pam_deny.so

account     required      pam_unix.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow remember=5
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
auth     required pam_faillock.so preauth audit silent deny=5 unlock_time=900
auth     [success=1 default=bad] pam_unix.so
auth     [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900
auth     sufficient pam_faillock.so authsucc audit deny=5 unlock_time=900
EOF

cat > /etc/pam.d/system-auth <<EOF
auth        required      pam_env.so
auth        sufficient    pam_unix.so try_first_pass nullok
auth        required      pam_deny.so

account     required      pam_unix.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow remember=5
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
auth     required pam_faillock.so preauth audit silent deny=5 unlock_time=900
auth     [success=1 default=bad] pam_unix.so
auth     [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900
auth     sufficient pam_faillock.so authsucc audit deny=5 unlock_time=900
EOF

echo "5.4.1.1 - ensure password expiration is 365 days or less"
sed -i 's/^\(PASS_MAX_DAYS\s\).*/\190/' /etc/login.defs

echo "5.4.1.2 - ensure minimum days between password changes is 7 or more"
sed -i 's/^\(PASS_MIN_DAYS\s\).*/\17/' /etc/login.defs

echo "5.4.1.3 - ensure password expiration warning days is 7 or more"
sed -i 's/^\(PASS_WARN_AGE\s\).*/\17/' /etc/login.defs

echo "5.4.1.4 - ensure inactive password lock is 30 days or less"
useradd -D -f 30

echo "5.4.1.5 - ensure all users last password change date is in the past"
cat /etc/shadow | cut -d: -f1

echo "5.4.2 - ensure system accounts are non-login"
egrep -v "^\+" /etc/passwd | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false") {print}'

echo "5.4.3 - ensure default group for the root account is GID 0"
grep "^root:" /etc/passwd | cut -f4 -d:

echo "5.4.4 - ensure default user umask is 027 or more restrictive"
echo "umask 027" >> /etc/bashrc
echo "umask 027" >> /etc/profile
# Just adding the umask isn't enough, all existing entries need to be fixed as
# well.
sed -i -e 's/\bumask\s\+\(002\|022\)/umask 027/' \
  /etc/bashrc /etc/profile /etc/profile.d/*.sh

echo "5.4.5 - ensure default user shell timeout is 900 seconds or less"
echo "TMOUT=600" >> /etc/bashrc
echo "TMOUT=600" >> /etc/profile

echo "5.5 - ensure root login is restricted to system console"
cat /etc/securetty

echo "5.6 - ensure access to the su command is restricted"
echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su

echo "6.1.2 - ensure permissions on /etc/passwd are configured"
chown root:root /etc/passwd
chmod 644 /etc/passwd

echo "6.1.3 - ensure permissions on /etc/shadow are configured"
chown root:root /etc/shadow
chmod 000 /etc/shadow

echo "6.1.4 - ensure permissions on /etc/group are configured"
chown root:root /etc/group
chmod 644 /etc/group

echo "6.1.5 - ensure permissions on /etc/gshadow are configured"
chown root:root /etc/gshadow
chmod 000 /etc/gshadow

echo "6.1.6 - ensure permissions on /etc/passwd- are configured"
chown root:root /etc/passwd-
chmod u-x,go-wx /etc/passwd-

echo "6.1.7 - ensure permissions on /etc/shadow- are configured"
chown root:root /etc/shadow-
chmod 000 /etc/shadow-

echo "6.1.8 - ensure permissions on /etc/group- are configured"
chown root:root /etc/group-
chmod u-x,go-wx /etc/group-

echo "6.1.9 - ensure permissions on /etc/gshadow- are configured"
chown root:root /etc/gshadow-
chmod 000 /etc/gshadow-

echo "6.1.10 - ensure no world writable files exist"
find / -xdev -type f -perm -0002

echo "6.1.11 - ensure no unowned files or directories exist"
find / -xdev -nouser

echo "6.1.12 - ensure no ungrouped files or directories exist"
find / -xdev -nogroup

echo "6.1.13 - audit SUID executables"
find / -xdev -type f -perm -4000

echo "6.1.14 - audit SGID executables"
find / -xdev -type f -perm -2000

echo "6.2.1 - ensure password fields are not empty"
cat /etc/shadow | awk -F: '($2 == "" ) { print $1 " does not have a password "}'
