# stage1 - chocolatey

<#
# package provider
get-packageprovider -name chocolatey -Force | out-string | write-host
set-PackageSource chocolatey -ProviderName Chocolatey -Trusted
#>

######## chocolatey helpers

function test-command([string] $cmd) {
    return Get-Command $cmd -ErrorAction Ignore
}
function test-choco() {
    return test-command "choco"
}

function install-chocolatey ($version = $null) {
	if (!(test-choco)) {
			Write-Warning "chocolatey not found, installing"

            #$version = "0.9.8.33"
            $s = (new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')
            if ($version -ne $null) {
                $s = $s -replace "https://chocolatey.org/api/v2/package/chocolatey","https://chocolatey.org/api/v2/package/chocolatey/$version"
			    $s = $s -replace "https://packages.chocolatey.org/.*\.nupkg","https://chocolatey.org/api/v2/package/chocolatey/$version"
            }
			iex $s
			cmd /c "SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
            $env:Path = [System.Environment]::GetEnvironmentVariable("PATH",[System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH",[System.EnvironmentVariableTarget]::User) 
			if (!(test-choco)) {
				write-error "chocolatey still not found! Installation failed?"
			}
            $path = "$env:ChocolateyInstall\chocolateyinstall\chocolatey.config"
            if (test-path $path) {
                write-host "setting chocolatey config 'ksMessage' to 'false'  in config file '$path'"
                $xml = [xml](Get-Content $path)
                $xml.chocolatey.ksMessage = "false"
                $xml.Save($path)
            }
	} 
	else 
	{
		write-host "chocolatey is already installed"       
	}
}

function ensure-choco() {
    if (!( test-command "choco")) {
        install-chocolatey 
    }
}


function get-installedChoco() {
    ensure-choco
    $installed = @{}
    $chocoList = (choco list -localonly) 
    if (!($chocoList[0] -match "No packages found")) {
        $chocoList | % { 
            $splits = $_.Split(' ')
            if ($splits.length -eq 2 -and -not [string]::IsNullOrWhiteSpace($splits[0])) {
                try {
                    $installed.Add($splits[0], $splits[1]) 
                } catch {
                }
            }
        }
    }
    $global:installed = $installed
    return $installed
}

function check-package([string] $name) {
    if ($global:installed -eq $null -or  $global:installed.Count -eq 0) {
		$global:installed = get-installedChoco
	}
    return $global:installed.ContainsKey($name)
}

function check-install(
[string] $prog, 
[scriptblock] $configAction = $null,
[string] $source = $null,
[switch] $verbose = $false,
[switch] $forceConfig = $false,
[string] $params = $null) 
{
	if ($global:installed -eq $null -or  $global:installed.Count -eq 0) {
		$global:installed = get-installedChoco
	}
    if (! $global:installed.ContainsKey($prog)) {
        $srcArgs = @()
        $otherArgs= @()
        if (![string]::IsNullOrEmpty($source)) { 
            write-host "installing $prog from source $source"
            $srcArgs += "-Source" 
            $srcArgs += $source
        }
        else {
            write-host "installing $prog"
        }
        if ($verbose) {
            $otherArgs += "-Verbose"
        }
        if (![string]::IsNullOrEmpty($params)) { 
            $otherArgs += "-params"
            $otherArgs += $params
        }
        & "choco" install -y $prog $srcArgs $otherArgs --allow-empty-checksums
        _refresh-env
        
        $global:installed = get-installedChoco

        if ($configAction -ne $null) {
            $configAction.Invoke()
        }
        else {
        }
    }
    else 
    {
        write-host "$prog is already installed"

         if ($configAction -ne $null -and $forceConfig) {
            $configAction.Invoke()
        }
        else {
        }
    }
}

function _Refresh-Env() {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    $env:PSModulePath =  [System.Environment]::GetEnvironmentVariable("PSModulePath","User") + ";" + [System.Environment]::GetEnvironmentVariable("PSModulePath","Machine")
}


ensure-choco