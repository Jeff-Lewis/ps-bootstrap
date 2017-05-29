<#
    .PARAM userScope - do not elevate. do everything that can be done in user scope
#>
[CmdletBinding()]
param(
    [switch][bool]$force = $false, 
    [switch][bool] $userScope = $true,
    [switch][bool] $elevate
)

if ($elevate) { $userScope = $false }

$version = "1.1.4"
$repoUrl = "https://raw.githubusercontent.com/qbikez/ps-bootstrap"
$branch = "master"

function _is-admin() {
 $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
 $prp=new-object System.Security.Principal.WindowsPrincipal($wid)
 $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 $IsAdmin=$prp.IsInRole($adm)
 return $IsAdmin
}

function test-executionPolicy() {
   $execPolicy = get-executionpolicy

    if ($execPolicy -ne "Unrestricted" -and $execPolicy -ne "Bypass") {
        return $false
    } else {
        return $true
    }
}

function enable-execution() {
    if (test-executionPolicy) { return $true }
    
    # try to set global execution policy
    if (_is-admin) {
        Set-ExecutionPolicy Unrestricted -Force -ErrorAction continue
        if (test-executionPolicy) { return $true }
    }
    
    # set user policy
    $userpolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($userpolicy -ne "Unrestricted" -and $userpolicy -ne "Bypass") {
        Set-ExecutionPolicy Unrestricted -Force -Scope CurrentUser -ErrorAction stop 
    }
    
    if (test-executionPolicy) { 
        return $true 
    }
    else {
        throw "failed to set ExecuctionPolicy to Unrestricted"
    }
    
}

function test-stagelock($stagefile) {
    $dir = (get-item .).FullName
    $lockfile = "$stagefile.lock"
    $lockvalid = $false
    if (test-path $lockfile) {
        $lockname = $stagefile
        $lockfile = (get-item $lockfile).FullName
        write-verbose "lockfile '$lockname': location='$lockfile'"
        $c =  get-content $lockfile 
        $lockversion = $c | select -first 1
        $waselevated = $c | % { if($_ -match "elevated:\s*(.*)") { $matches[1] } }
        #$c | write-verbose
        if ($lockversion -ne $version) {
            write-verbose "lockfile '$lockname': version '$lockversion' is older than current '$version'"
            $lockvalid = $false
        }
        else {
            write-verbose "lockfile '$lockname': version '$lockversion' is current '$version'"
            Write-Verbose "lockfile '$lockname': elevated: $waselevated; current elevation: $(_is-admin)"
            if ($waselevated -eq $null -or $waselevated -eq 'false') {
                if (_is-admin) {
                    write-verbose "lockfile '$lockname': considered invalid, because it was run without elevation"
                    $lockvalid = $false
                } else {
                    $lockvalid = $true
                }
            } else {
                Write-Verbose "lockfile '$lockname': elevated: TRUE"
                $lockvalid = $true
            }

        }
    } else {
        write-verbose "lockfile '$dir/$lockfile' does not exist"
    }
    return $lockvalid
}

function write-stagelock($stagefile) {
    $lockfile = "$stagefile.lock"
    $fullpath = join-path (get-item .).FullName $lockfile
    write-verbose "writing lockfile '$fullpath': version=$version"
    $version | out-file $lockfile -force
    get-date | out-string | Out-File $lockfile -append
    "elevated: $(_is-admin)" | out-file $lockfile -append
}

function Invoke-UrlScript(
    [Parameter(Mandatory=$true)]$url, 
    [Parameter(Mandatory=$true)]$outfile
) {    
    $outdir = split-path -Parent $outfile
    if ([string]::isnullorempty($outdir)) { $outdir = "." }
    $name = Split-Path -Leaf $outfile
    if (!(test-path $outdir)) { $null = mkdir $outdir }

    pushd 
    cd $outdir
    try {
        $lockvalid = test-stagelock $outfile
        if (!$lockvalid -or $force) {
            #init build tools        
            $bootstrap = "$outdir/$name"
            $shouldDownload = $true
            if ((test-path "$psscriptroot/.git") -and (test-path "$psscriptroot/$stage.ps1")) {
                write-verbose "using stage file '$stage.ps1' from source"
                copy-item "$psscriptroot/$stage.ps1" $bootstrap -Force
                $shouldDownload = $false
            } elseif ((test-path $bootstrap) -and (get-command Invoke-WebRequest -erroraction SilentlyContinue) -ne $null) {
	            $ts = (Get-Item $bootstrap).LastWriteTime
                $h = Invoke-WebRequest $url -Method Head -UseBasicParsing
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
                ((New-Object System.Net.WebClient).DownloadString("$url")) | out-file $bootstrap -Encoding utf8
            }
            $r = & $bootstrap
     
            if ($r) {
                write-stagelock $outfile
            } else {
                Write-Warning "stage $outfile completed, but reports some actions were not executed. Not writing lock file"
            }
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
        $invocation | out-string | write-verbose
        $invocation.MyCommand | out-string | write-verbose
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
            $p = Start-Process cmd -Verb runAs -ArgumentList "/C powershell $args > $env:TEMP/bootstrap.log" -wait
            gc "$env:TEMP/bootstrap.log" | write-host
        } else {
            $p = Start-Process powershell -Verb runAs -ArgumentList $args -wait
        }        
        return $false
    } else {
        return $true
    }
}



$wd = "$env:localappdata/ps-bootstrap"

    if (!(test-executionPolicy)) {
        enable-execution
        $force = $true                
    }


if (!(test-path $wd)) { mkdir $wd }
pushd 
try {
    cd $wd
 
    $stages = "stage0","stage1","stage2"
    foreach($stage in $stages) {
        if (!(test-stagelock ".$stage.ps1")) {
            $allvalid = $false
            write-verbose ".$stage.ps1: PENDING"
        } else {
            write-verbose ".$stage.ps1: READY"
        }
    }

    if ($allvalid) {
        if (!$force) { 
            write-verbose "all stages READY"
            return 
        } else {
            write-verbose "all stages are READY, but -force specified - proceeding"
        }
    }
    
    if (!$userScope) {    
        if (!(ElevateMe $MyInvocation -usecmd)) { return }
    }

    foreach($stage in $stages) {
            Invoke-UrlScript "$repoUrl/$branch/$stage.ps1" ".$stage.ps1"
    }
} finally {
    popd
}
