[Unit]
Description=Mount EC2 Instance Store NVMe disk RAID{{.Level}}
[Mount]
What=UUID={{.UUID}}
Where={{.Where}}
Type=xfs
Options=defaults,noatime
[Install]
WantedBy=multi-user.target
