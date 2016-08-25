[CmdletBinding()]
param ($path = ".", [switch][bool]$importonly)


function get-envinfo($checkcommands) {
    $result = @{} 
    
    write-verbose "Powershell version:"    
    $result.PSVersion = $PSVersionTable.PSVersion 
    $result.PSVersion | format-table | out-string | write-verbose
    
    write-verbose "Available commands:"
    if ($checkcommands -eq $null) {
        $commands = "Install-Module"
    } else {
        $commands = $checkcommands
    }
    $result.Commands = @{}    
    $commands | % {
        $c = $_
        $cmd = $null
        try {
            $cmd = get-command $c -ErrorAction SilentlyContinue
            if ($cmd -ne $null) {
                $result.Commands[$_] = $cmd
            }
        } catch {
            write-error $_
            $cmd = $null
        }
        if ($cmd -eq $null) {
            write-warning "$($c):`t MISSING COMMAND"            
        }
        else {
             write-verbose "$($c):`t $(($cmd | format-table -HideTableHeaders | out-string) -replace ""`r`n"",'')"
        }
    }

    return $result
    
}

function download-oneget() {
    $url = "https://download.microsoft.com/download/4/1/A/41A369FA-AA36-4EE9-845B-20BCC1691FC5/PackageManagement_x64.msi"

    $tmpdir = "temp"
    if (!(test-path $tmpdir)) {
        $null = new-item -type Directory $tmpdir
    }

    $dest = "$tmpdir\PackageManagement_x64.msi"
    $log = "$tmpdir\log.txt"
    if (!(test-path $dest)) {
        write-host "downloading $dest"
        wget -Uri $url -OutFile $dest
    }
    write-host "installing $dest"
    $out = & cmd /c start /wait msiexec /i $dest /qn /passive /log "$log"
    write-host "install done"
    write-host "## log: ##"
    Get-Content $log | write-host
    write-host "## log end ##"
    fix-oneget
}

function fix-oneget {
[CmdletBinding()]
param([switch][bool]$force) 
    if ($PSVersionTable.PSVersion.Major -lt 5 -or $force) {
        $psgetmodules = @(get-module powershellget -ListAvailable)
        write-host "psget modules:"
        $psgetmodules | out-string | write-host
        
        $modulesrc = $psgetmodules[0].path
        $moduleDir = (split-path -parent $modulesrc)          
        
        $target = join-path (split-path -parent $modulesrc) "PSGet.psm1"
        $src = "https://raw.githubusercontent.com/qbikez/PowerShellGet/master/PowerShellGet/PSGet.psm1"
        #$src = "https://gist.githubusercontent.com/qbikez/d6fc3151f9702ea1aab6/raw/PSGet.psm1"

        if (!(test-path "variable:tmpdir")) { $tmpdir = $env:TEMP }       
        $tmp = "$tmpdir\PSGet.psm1" 

        write-host "downloading patched Psget.psm1 from $src to $tmp"
        wget $src -OutFile $tmp -UseBasicParsing

        write-host "overwriting $target with $tmp"
        Copy-Item $tmp $target -Force -Verbose
        
        $target = join-path (split-path -parent $modulesrc) "PowerShellGet.psd1"
        $src = "https://gist.githubusercontent.com/qbikez/d6fc3151f9702ea1aab6/raw/PowerShellGet.psd1"
        $tmp = "$tmpdir\PowerShellGet.psd1"

        write-host "downloading patched Psget.psd1 from $src to $tmp"
        wget $src -OutFile $tmp -UseBasicParsing

        write-host "overwriting $target with $tmp"
        Copy-Item $tmp $target -Force -Verbose
        
        write-host "files in $moduleDir :"
        Get-ChildItem $moduleDir -Recurse
        
        # check if it works
        
        if (get-module powershellget) { remove-module powershellget }        
        
        write-host "available powershellget modules:"
        get-module powershellget -ListAvailable
        
        import-module powershellget -ErrorAction Stop -MinimumVersion 1.0.0.1
    }
    else {
        write-host "using Powershell v$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor). no need to fix oneget"

    }
}


function is-admin() {
 $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
 $prp=new-object System.Security.Principal.WindowsPrincipal($wid)
 $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 $IsAdmin=$prp.IsInRole($adm)
 return $IsAdmin
}

if ($importonly) { return }

if (!(is-admin)) {
    $r = Start-Process powershell -Verb runAs -ArgumentList @("-ExecutionPolicy", "Unrestricted", "$psscriptroot\bootstrap.ps1") -Wait
    $r
    return
}

$execPolicy = get-executionpolicy

if ($execPolicy -ne "Unrestricted" -and $execPolicy -ne "Bypass") {
    Set-ExecutionPolicy Unrestricted -Force -ErrorAction Continue
}

$e = get-envinfo -checkcommands "Install-Module"
write-host "Env info:"
$e | out-string | write-host
write-host "" 

write-host "PSVersions:"
$PSVersionTable | out-string | write-host

if ($e.commands["Install-Module"] -eq $null) {
    download-oneget
    $e = get-envinfo -checkcommands "Install-Module"

    write-host "Env info after oneget install:"
    $e | out-string | write-host
    write-host "" 

    get-module packagemanagement -ListAvailable | out-string | write-host  
}

fix-oneget

Get-PSRepository | out-string | write-host

try {
    write-host "Nuget Package provider:"
    get-packageprovider -Name Nuget | out-string | write-host

    write-host "installing nuget package provider"
    # this isn't availalbe in the current official release of oneget (?)
    install-packageprovider -Name NuGet -Force -MinimumVersion 2.8.5.201 -verbose
}
catch {
 #ignore   
}
# this is a private function
#Install-NuGetClientBinaries -force -CallerPSCmdlet $PSCmdlet
#Install-NuGetClientBinaries -confirm:$false

Set-PSRepository -name PSGallery -InstallationPolicy Trusted -verbose 

get-packageprovider -name chocolatey -Force | out-string | write-host
set-PackageSource chocolatey -ProviderName Chocolatey -Trusted
#register-packagesource -Name chocolatey -Provider PSModule -Trusted -Location http://chocolatey.org/api/v2/ -Verbose


# install-Package -Source "chocolatey" -Name "visualstudiocode"
