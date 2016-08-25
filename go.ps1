function Invoke-UrlScript(
    [Parameter(Mandatory=$true)]$url, 
    [Parameter(Mandatory=$true)]$outfile
) {    
    pushd 
    $outdir = split-path -Parent $outfile
    $name = Split-Path -Leaf $outfile
    if (!(test-path $outdir)) { $null = mkdir $outdir }
    cd $outdir
    try {
        if (!(test-path ".scripts")) { mkdir ".scripts" }
        $lockfile = "$outdir\$name.lock"
        if (!(test-path $lockfile)) {
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
            get-date | out-string | Out-File $lockfile
        }
    }
    catch {
        throw
    }
    finally {
	    popd
    }
}

#Invoke-UrlScript "http://bit.ly/qbootstrap1" "../.scripts/bootstrap.ps1"