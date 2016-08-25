$version = "1.0.0"

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
        if (!(test-path ".scripts")) { mkdir ".scripts" }
        $lockfile = "$outdir\$name.lock"
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
     
            #Install-Module pathutils
            #refresh-env
            $version | out-file $lockfile -force
            get-date | out-string | Out-File $lockfile -append
        }
    }
    catch {
        throw
    }
    finally {
	    popd
    }
}


function ElevateMe() {
    if (!(test-isadmin)) {
        Write-Host "You need to be Administrator in order to do installation."
        write-warning "starting this script as Administrator..."
        $i = $myinvocation
        $args = "$($i.scriptname)"
        #$args = "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))"
		write-host "starting as admin:"
        write-host "powershell -Verb runAs -ArgumentList $args"
        Start-Process powershell -Verb runAs -ArgumentList $args -wait
        return $false
    } else {
        return $true
    }
}

$wd = "$env:appdata/ps-bootstrap"

if (!(test-path $wd)) { mkdir $wd }
pushd 
try {
    cd $wd
    if (!(ElevateMe)) { return }

    $stages = "stage0","stage1","stage2"

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