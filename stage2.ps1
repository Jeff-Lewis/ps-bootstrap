$scope = "CurrentUser"
if (_Is-Admin) { 
    write-verbose "user is Admin. Setting install scope to AllUsers."
    $scope = "AllUsers" 
} else {
    write-verbose "user is not Admin. Setting install scope to CurrentUser."
    $scope = "CurrentUser"
}



$usrModules = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
$usrModulesPath = [system.environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) 
if (!($env:PSModulePath.Contains($usrModules))) {
    if ($usrModulesPath -eq $null -or !($usrModulesPath.Contains($usrModules))) {
        if ($usrModulesPath -eq $null) { $usrModulesPath = "" } 
        [system.environment]::SetEnvironmentVariable("PSModulePath",
          "$usrModulesPath;$usrModules", 
          [System.EnvironmentVariableTarget]::User);
    }
    $env:PSModulePath = [system.environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) `
        + ";" + [system.environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::Machine) 
}

#(get-command install-module)
#(get-command install-module).Parameters

function _install-module($name, $version) {
    ipmo $name -erroraction Continue -MinimumVersion $version
    if ((gmo $name -ErrorAction Ignore) -eq $null) {        
        #try import any version       
        ipmo $name -ErrorAction Continue
        if ((gmo $name -ErrorAction Ignore) -eq $null) {                   
            write-verbose "module $name min-version $version not found on any of module loading paths: $env:PSModulePath"
            $a = @{
                Scope = $scope
                MinimumVersion = $version
                ErrorAction = "stop"            
            }
            if ((get-command install-module).parameters["allowclobber"] -ne $null) {
                $a += @{ allowClobber = $true }
            }
            install-module $name @a -Verbose
        } else {
            write-verbose "module $name found, but has lower version than $version. "
            update-module $name -erroraction stop -Verbose
        }
    } 
    ipmo $name -MinimumVersion $version
}

_install-module require -version "1.0.5"

return $true

