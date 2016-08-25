$scope = "CurrentUser"


function is-admin() {
    $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $prp=new-object System.Security.Principal.WindowsPrincipal($wid)
    $adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
    $IsAdmin=$prp.IsInRole($adm)
    return $IsAdmin
}

if (Is-Admin) { $scope = "AllUsers" }

$requireVer = "1.0.5"

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

ipmo require -erroraction ignore -MinimumVersion $requireVer
if ((gmo require) -eq $null) {
    #try import any version       
    ipmo require
    if ((gmo require) -eq $null) {       
        install-module require -scope $scope -MinimumVersion $requireVer -erroraction stop
    } else {
        update-module require -erroraction stop
    }
} 
ipmo require -MinimumVersion $requireVer
