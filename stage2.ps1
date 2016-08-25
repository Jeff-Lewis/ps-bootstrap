$scope = "CurrentUser"
if (test-IsAdmin) { $scope = "AllUsers" }

$requireVer = 1.0.5

ipmo require -erroraction ignore -MinimumVersion $requireVer
if ((gmo require) -eq $null) { 
    install-module require -scope $scope -MinimumVersion $requireVer -erroraction stop
} else {
    update-module require -erroraction stop
}
ipmo require -MinimumVersion $requireVer
