$scope = "CurrentUser"


function is-admin() {
    $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $prp=new-object System.Security.Principal.WindowsPrincipal($wid)
    $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
    $IsAdmin=$prp.IsInRole($adm)
    return $IsAdmin
}

if (Is-Admin) { $scope = "AllUsers" }



$usrModules = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
$usrModulesPath = [system.environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) 
if (!($env:PSModulePath.Contains($usrModules))) {
    if (!($usrModulesPath.Contains($usrModules))) {
    [system.environment]::SetEnvironmentVariable("PSModulePath",
        "$usrModulesPath;$usrModules", 
        [System.EnvironmentVariableTarget]::User);
    }
    $env:PSModulePath = [system.environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) `
        + ";" + [system.environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::Machine) 
}

(get-command install-module)
(get-command install-module).Parameters

function _install-module($name, $version) {
    ipmo $name -erroraction ignore -MinimumVersion $version
    if ((gmo $name -ErrorAction Ignore) -eq $null) {
        #try import any version       
        ipmo $name -ErrorAction ignore
        if ((gmo $name -ErrorAction Ignore) -eq $null) {       
            $a = @{
                Scope = $scope
                MinimumVersion = $version
                ErrorAction = "stop"            
            }
            if ((get-command install-module).parameters["allowclobber"] -ne $null) {
                $a += @{ allowClobber = $true }
            }
            install-module $name @a
        } else {
            update-module $name -erroraction stop
        }
    } 
    ipmo $name -MinimumVersion $version
}

_install-module require -version "1.0.5"

