# Powershell Bootstrap

## Usage

Add this piece of code to your script:

    if (!(test-path "$env:localappdata/ps-bootstrap")) { $null = mkdir "$env:localappdata/ps-bootstrap" }
    ((New-Object System.Net.WebClient).DownloadString('https://bit.ly/psbootstrap')) | out-file "$env:localappdata/ps-bootstrap/bootstrap.ps1" 
    & "$env:localappdata/ps-bootstrap/bootstrap.ps1"
    
or a shorter version:
    
    ((New-Object System.Net.WebClient).DownloadString('https://bit.ly/psbootstrap')) | iex    

or even shorter (for PowerShell v3+):

    iwr http://bit.ly/psbootstrap -UseBasicParsing | iex
 
This will download [`Bootstrap.ps1`](https://github.com/qbikez/ps-bootstrap/blob/master/bootstrap.ps1), which in turn will download and invoke all other stages, which are:

* `stage0.ps1` - ensures PowerShellGet is present
* `stage1.ps1` - ensures chocolatey is present
* `stage2.ps1` - installs [Require](https://www.powershellgallery.com/packages/require) module that facilitates other module import and download
