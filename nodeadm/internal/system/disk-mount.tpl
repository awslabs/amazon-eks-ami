[Unit]
Description=Mount EC2 Instance Store NVMe disk {{.Index}}
[Mount]
What={{.What}}
Where={{.Where}}
Type=xfs
Options=defaults,noatime
[Install]
WantedBy=multi-user.target
