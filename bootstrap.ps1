[CmdletBinding()]
param([switch][bool]$force = $false)
$version = "1.0.1"

function _is-admin() {
 $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
 $prp=new-object System.Security.Principal.WindowsPrincipal($wid)
 $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 $IsAdmin=$prp.IsInRole($adm)
 return $IsAdmin
}

function test-executionPolicy() {
   


}

function enable-execution() {
    $execPolicy = get-executionpolicy

    if ($execPolicy -ne "Unrestricted" -and $execPolicy -ne "Bypass") {
        $userpolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($userpolicy -ne "Unrestricted" -and $userpolicy -ne "Bypass" -and $userpolicy -ne "Undefined") {
            Set-ExecutionPolicy Unrestricted -Force -Scope CurrentUser -ErrorAction stop 
        }
        Set-ExecutionPolicy Unrestricted -Force -ErrorAction continue
    } else {
        return $true
    }
    
    $execPolicy = get-executionpolicy
    if ($execPolicy -ne "Unrestricted" -and $execPolicy -ne "Bypass") {
        throw "failed to set ExecuctionPolicy to Unrestricted"
    }
    
}

function test-stagelock($stagefile) {
    $lockfile = "$stagefile.lock"
    $lockvalid = $false
    if (test-path $lockfile) {
        $lockversion = get-content $lockfile | select -first 1
        if ($lockversion -ne $version) {
            $lockvalid = $false
        }
        else {
            $lockvalid = $true
        }
    }
    return $lockvalid
}

function write-stagelock($stagefile) {
    $lockfile = "$stagefile.lock"
    $version | out-file $lockfile -force
    get-date | out-string | Out-File $lockfile -append
}

function Invoke-UrlScript(
    [Parameter(Mandatory=$true)]$url, 
    [Parameter(Mandatory=$true)]$outfile
) {    
    pushd 
    $outdir = split-path -Parent $outfile
    if ([string]::isnullorempty($outdir)) { $outdir = "." }
    $name = Split-Path -Leaf $outfile
    if (!(test-path $outdir)) { $null = mkdir $outdir }
    cd $outdir
    try {
        $lockvalid = test-stagelock $outfile
        if (!$lockvalid) {
            #init build tools        
            $bootstrap = "$outdir/$name"
            $shouldDownload = $true
            if (test-path $bootstrap) {
	            $ts = (Get-Item $bootstrap).LastWriteTime
                $h = Invoke-WebRequest $url -Method Head
                try {
                $r = Invoke-WebRequest $url -UseBasicParsing -Headers @{"If-Modified-Since" = $ts } 
                    if ($r.StatusCode -eq 200) {
                        $shouldDownload = $true
                    } 
                } catch {
                    if ($_.Exception.Response.StatusCode -eq "NotModified") {
                        $shouldDownload = $false
                    }
                }
            }
            if ($shouldDownload) {
                Invoke-WebRequest $url -UseBasicParsing -OutFile $bootstrap
            }
            & $bootstrap
     
            write-stagelock $outfile
            #Install-Module pathutils
            #refresh-env
            
        }
    }
    catch {
        throw
    }
    finally {
	    popd
    }
}


function ElevateMe($invocation = $null, [switch][bool]$usecmd) {
    if (!(_is-admin)) {
        Write-Host "You need to be Administrator in order to do installation."
        write-warning "starting this script as Administrator..."
        if ($invocation -eq $null) { $invocation = $myinvocation }
        $cmd = $null
        $invocation | out-string | write-host
        $invocation.MyCommand | out-string | write-host
        #$cmd = "$($invocation.scriptname)"
        if ([string]::IsNullOrEmpty($cmd)) {
            $cmd = $invocation.MyCommand.Definition
        }
        $args = @($cmd)
        if ($VerbosePreference -eq "Continue") { $args += @("-verbose") }
        #$args += " > bootstrap.log"
        #$args = "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))"
		write-host "starting as admin:"
        write-host "powershell -Verb runAs -ArgumentList $args"
        if ($usecmd) {
            Start-Process cmd -Verb runAs -ArgumentList "/C powershell $args > $env:TEMP/bootstrap.log" -wait
            gc "$env:TEMP/bootstrap.log" | write-host
        } else {
            Start-Process powershell -Verb runAs -ArgumentList $args -wait
        }        
        return $false
    } else {
        return $true
    }
}

$wd = "$env:localappdata/ps-bootstrap"

if (!(test-path $wd)) { mkdir $wd }
pushd 
try {
    cd $wd
    
    if (!(test-executionPolicy)) {
        enable-execution
    }

    $stages = "stage0","stage1","stage2"
    $allvalid = $true
    foreach($stage in $stages) {
        if (!(test-stagelock ".$stage.ps1")) {
            $allvalid = $false
            write-verbose ".$stage.ps1: PENDING"
        } else {
            write-verbose ".$stage.ps1: READY"
        }
    }

    if ($allvalid -and !$force) { 
        write-verbose "all stages READY"
        return 
    }
    if (!(ElevateMe $MyInvocation -usecmd)) { return }

    foreach($stage in $stages) {
        if ((test-path ".git") -and (test-path "$stage.ps1")) {
            & ".\$stage.ps1"
        } else {
            Invoke-UrlScript "https://raw.githubusercontent.com/qbikez/ps-bootstrap/master/$stage.ps1" ".$stage.ps1"
        }
    }
} finally {
    popd
}
