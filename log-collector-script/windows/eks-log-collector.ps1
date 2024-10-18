<#
    Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
    Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

        http://aws.amazon.com/apache2.0/

    or in the "license" file accompanying this file.
    This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

.SYNOPSIS
    Collects EKS Logs
.DESCRIPTION
    Run the script to gather basic operating system, Docker daemon, and kubelet logs.

.NOTES
    You need to run this script with Elevated permissions to allow for the collection of the installed applications list
.EXAMPLE
    eks-log-collector.ps1
    Gather basic operating system, Docker daemon, and kubelet logs.

#>

param(
    [Parameter(Mandatory=$False)][string]$RunMode = "Collect"
    )

# Common options
$basedir="C:\log-collector"
$token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "5"} -Method PUT -Uri http://169.254.169.254/latest/api/token
$instanceId = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
$curtime = Get-Date -Format FileDateTimeUniversal
$outfilename = "eks_" + $instanceid + "_" + $curtime + ".zip"
$infodir="$basedir\collect"
$info_system="$infodir\system"


# Common functions
# ---------------------------------------------------------------------------------------

Function is_elevated{
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-warning "This script requires elevated privileges to copy registry keys to the EKS logs collector folder."
        Write-Host "Please re-launch as Administrator." -foreground "red" -background "black"
        break
    }
}


Function create_working_dir{
    try {
        Write-Host "Creating temporary directory"
        New-Item -type directory -path $info_system -Force >$null
        New-Item -type directory -path $info_system\eks -Force >$null
        New-Item -type directory -path $info_system\docker -Force >$null
        New-Item -type directory -path $info_system\containerd -Force >$null
        New-Item -type directory -path $info_system\firewall -Force >$null
        New-Item -type directory -path $info_system\kubelet -Force >$null
        New-Item -type directory -path $info_system\kube-proxy -Force >$null
        New-Item -type directory -path $info_system\cni -Force >$null
        New-Item -type directory -path $info_system\docker_log -Force >$null
        New-Item -type directory -path $info_system\containerd_log -Force >$null
        New-Item -type directory -path $info_system\network -Force >$null
        New-Item -type directory -path $info_system\network\hns -Force >$null
        New-Item -type directory -path $info_system\events -Force >$null
        Write-Host "OK" -ForegroundColor "green"
    }
    catch {
        Write-Host "Unable to create temporary directory"
        Write-Host "Please ensure you have enough permissions to create directories"
        Write-Error "Failed to create temporary directory"
        Break
    }
}

Function check_service_installed_and_running {
    <#
    .SYNOPSIS
    This method checks if the specified service is installed and in running state.
    #>
    [CmdletBinding()]
    Param (
      [Parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string]$ServiceName
    )

    Write-Host ("Checking status of service: {0}" -f $ServiceName)
    try {
        if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
            Write-Host ("Service {0} not found" -f $ServiceName)
            return 0
        }

        if ((Get-Service -Name $ServiceName).Status -eq "Running") {
            Write-Host ("Service {0} is running." -f $ServiceName)
            return 1
        }
        Write-Host ("Service {0} is not running." -f $ServiceName)
        return 0
    }
    catch {
        Write-Error "Unable to check if service is installed and running"
        break
    }
}

Function get_sysinfo{
    try {
        Write-Host "Collecting System information"
        systeminfo.exe > $info_system\sysinfo
        Write-Host "OK" -ForegroundColor "green"
    }
    catch {
        Write-Error "Unable to collect system information"
        Break
    }

}

Function is_diskfull{
    $threshold = 30
    try {
        Write-Host "Checking free disk space"
        $drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
        $percent = ([math]::round($drive.FreeSpace/1GB, 0) / ([math]::round($drive.Size/1GB, 0)) * 100)
        Write-Host "C: drive has $percent% free space"
        Write-Host "OK" -ForegroundColor "green"
    }
    catch {
        Write-Error "Unable to Determine Free Disk Space"
        Break
    }
    if ($percent -lt $threshold){
        Write-Error "C: drive only has $percent% free space, please ensure there is at least $threshold% free disk space to collect and store the log files"
        Break
    }
}

Function get_system_logs{
    try {
        Write-Host "Collecting System Logs"
        Get-WinEvent -LogName System | Select-Object timecreated,leveldisplayname,machinename,message | export-csv -Path $info_system\system-eventlogs.csv
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to Collect System Logs"
        break
    }
}

Function get_application_logs{
    try {
        Write-Host "Collecting Application Logs"
        Get-WinEvent -LogName Application | Select-Object timecreated,leveldisplayname,machinename,message | export-csv -Path $info_system\application-eventlogs.csv
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to Collect Application Logs"
        break
    }
}

Function get_volumes_info{
    try {
        Write-Host "Collecting Volume info"
        Get-psdrive -PSProvider 'FileSystem' | Out-file $info_system\volumes
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to Collect Volume information"
        break
    }
}

Function get_firewall_info{
    try {
        Write-Host "Collecting Windows Firewall info"
        $fw = Get-NetFirewallProfile
        foreach ($f in $fw){
            if ($f.Enabled -eq "True"){
                $file = $f.name
                Write-Host "Collecting Rules for" $f.name "profile"
                Get-NetFirewallProfile -Name $f.name | Get-NetFirewallRule | Out-file $info_system\firewall\firewall-$file
                }
            }
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to Collect Windows Firewall information"
        break
    }
}

Function get_softwarelist{
    try {
        Write-Host "Collecting installed applications list"
        gp HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |Select DisplayName, DisplayVersion, Publisher, InstallDate, HelpLink, UninstallString | out-file $info_system\installed-64bit-apps.txt
        gp HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |Select DisplayName, DisplayVersion, Publisher, InstallDate, HelpLink, UninstallString | out-file $info_system\installed-32bit-apps.txt
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to collect installed applications list"
        break
    }
}

Function get_system_services{
    try {
        Write-Host "Collecting Services list"
        get-service | fl | out-file $info_system\services
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to collect Services list"
        break
    }
}

Function get_containerd_info{
    Write-Host "Collecting Containerd information"
    if (check_service_installed_and_running "containerd") {
        try {
            ctr version > $info_system\containerd\containerd-version.txt 2>&1
            ctr namespaces list > $info_system\containerd\containerd-namespaces.txt 2>&1
            ctr --namespace k8s.io images list > $info_system\containerd\containerd-images.txt 2>&1
            ctr --namespace k8s.io containers list > $info_system\containerd\containerd-containers.txt 2>&1
            ctr --namespace k8s.io tasks list > $info_system\containerd\containerd-tasks.txt 2>&1
            ctr --namespace k8s.io plugins list > $info_system\containerd\containerd-plugins.txt 2>&1
            Write-Host "OK" -foregroundcolor "green"
        }
        catch{
            Write-Error "Unable to collect Containerd information"
            Break
        }
    }
}

Function get_docker_info{
    Write-Host "Collecting Docker daemon information"
    if (check_service_installed_and_running "docker") {
        try {
            docker info > $info_system\docker\docker-info.txt 2>&1
            docker ps --all --no-trunc > $info_system\docker\docker-ps.txt 2>&1
            docker images > $info_system\docker\docker-images.txt 2>&1
            docker version > $info_system\docker\docker-version.txt 2>&1
            Write-Host "OK" -foregroundcolor "green"
        }
        catch {
            Write-Error "Unable to collect Docker daemon information"
            Break
        }
    }
}

Function get_eks_logs{
    try {
        Write-Host "Collecting EKS logs"
        copy C:\ProgramData\Amazon\EKS\logs\* $info_system\eks\
        Write-Host "OK" -foregroundcolor "green"
    }
    catch{
        Write-Error "Unable to collect ECS Agent logs"
        Break
    }
}

Function get_k8s_info{
    try {
        Write-Host "Collecting Kubelet logs"
        Get-WinEvent -ProviderName kubelet | Export-CSV $info_system/kubelet/kubelet-service.csv
        Write-Host "OK" -foregroundcolor "green"
    }
    catch{
        Write-Error "Unable to collect Kubelet logs"
        Break
    }

    try {
        Write-Host "Collecting Kube-proxy logs"
        Get-WinEvent -ProviderName kube-proxy | Export-CSV $info_system/kube-proxy/kube-proxy-service.csv
        Write-Host "OK" -foregroundcolor "green"
    }
    catch{
        Write-Error "Unable to collect Kube-proxy logs"
        Break
    }

    try {
        Write-Host "Collecting kubelet information"
        copy C:\ProgramData\kubernetes\kubeconfig $info_system\kubelet\
        copy C:\ProgramData\kubernetes\kubelet-config.json $info_system\kubelet\
        copy C:\ProgramData\Amazon\EKS\cni\config\* $info_system\cni\
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to collect kubelet information"
        Break
    }
}

Function get_docker_logs{
    Write-Host "Collecting Docker daemon logs"
    if (check_service_installed_and_running "docker") {
        try {
            Get-WinEvent -ProviderName Docker | Export-CSV $info_system/docker_log/docker-daemon.csv
            Write-Host "OK" -foregroundcolor "green"
        }
        catch {
            Write-Error "Unable to collect Docker daemon logs"
            Break
        }
    }
}

Function get_containerd_logs{
    Write-Host "Collecting containerd logs"
    if (check_service_installed_and_running "containerd") {
        try {
            copy C:\ProgramData\containerd\root\panic.log $info_system\containerd_log\
            Write-Host "OK" -foregroundcolor "green"
        }
        catch {
            Write-Error "Unable to collect containerd logs"
            Break
        }
    }
}

Function get_network_info{
    try {
        Write-Host "Collecting network Information"
        Get-HnsNetwork | Select Name, Type, Id, AddressPrefix > $info_system\network\hns\network.txt
        Get-hnsnetwork | Convertto-json -Depth 20 >> $info_system\network\hns\network.txt
        Get-hnsnetwork | % { Get-HnsNetwork -Id $_.ID -Detailed } | Convertto-json -Depth 20 >> $info_system\network\hns\networkdetailed.txt

        Get-HnsEndpoint | Select IpAddress, MacAddress, IsRemoteEndpoint, State > $info_system\network\hns\endpoint.txt
        Get-hnsendpoint | Convertto-json -Depth 20 >> $info_system\network\hns\endpoint.txt

        Get-hnspolicylist | Convertto-json -Depth 20 > $info_system\network\hns\policy.txt

        vfpctrl.exe /list-vmswitch-port > $info_system\network\ports.txt
        ipconfig /allcompartments /all > $info_system\network\ip.txt
        route print > $info_system\network\routes.txt
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to collect network information"
        Break
    }
}

Function get_windows_events{
    try {
        Write-Host "Collecting Windows events"
        Copy-Item "$env:SystemDrive\Windows\System32\Winevt\Logs\Application.evtx" -Destination $info_system\events
        Copy-Item "$env:SystemDrive\Windows\System32\Winevt\Logs\EKS.evtx" -Destination $info_system\events
        Copy-Item "$env:SystemDrive\Windows\System32\Winevt\Logs\System.evtx" -Destination $info_system\events
        Copy-Item "$env:SystemDrive\Windows\System32\Winevt\Logs\\Microsoft-Windows-Containers*.evtx" -Destination $info_system\events
        Copy-Item "$env:SystemDrive\Windows\System32\Winevt\Logs\\Microsoft-Windows-Host-Network-Service*.evtx" -Destination $info_system\events
        Copy-Item "$env:SystemDrive\Windows\System32\Winevt\Logs\\Microsoft-Windows-Hyper-V-Compute*.evtx" -Destination $info_system\events

        Write-Host "OK" -ForegroundColor "green"
    }
    catch {
        Write-Error "Unable to collect Windows events"
        Break
    }

}

Function cleanup{
    Write-Host "Cleaning up directory"
    Remove-Item -Recurse -Force $basedir -ErrorAction Ignore
    Write-Host "OK" -foregroundcolor green
}

Function pack{
    try {
        Write-Host "Archiving gathered data"
        Compress-Archive -Path $infodir\* -CompressionLevel Optimal -DestinationPath $basedir\$outfilename
        Remove-Item -Recurse -Force $infodir -ErrorAction Ignore
        Write-Host "Done... your bundled logs are located in " $basedir\$outfilename
    }
    catch {
        Write-Error "Unable to archive data"
        Break
    }
}

Function init{
    is_elevated
    create_working_dir
    get_sysinfo
}

Function collect{
    init
    is_diskfull
    get_system_logs
    get_application_logs
    get_volumes_info
    get_firewall_info
    get_softwarelist
    get_system_services
    get_docker_info
    get_containerd_info
    get_k8s_info
    get_docker_logs
    get_containerd_logs
    get_eks_logs
    get_network_info
    get_windows_events
}

#--------------------------
#Main-function
Function main {
    Write-Host "Running Default(Collect) Mode" -foregroundcolor "blue"
    cleanup
    collect
    pack
}

#Entry point
main
