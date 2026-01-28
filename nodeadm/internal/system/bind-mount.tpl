[Unit]
Description=Mount {{.Where}} on EC2 Instance Store NVMe RAID{{.Level}}
[Mount]
What={{.What}}
Where={{.Where}}
Type=none
Options=bind
[Install]
WantedBy=multi-user.target
