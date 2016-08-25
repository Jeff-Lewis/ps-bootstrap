# Powershell Bootstrap

## Usage

Add this piece of code to your script (if running elevated):

    iex ((New-Object System.Net.WebClient).DownloadString('https://bit.ly/psbootstrap'))
    
Or:

    Start-Process powershell -Verb runAs -wait -ArgumentList "-Command ""iex ((New-Object System.Net.WebClient).DownloadString('https://bit.ly/psbootstrap'))"""

This will download [`Bootstrap.ps1`](https://github.com/qbikez/ps-bootstrap/blob/master/bootstrap.ps1), which in turn will download and invoke all other stages, which are:

* `stage0.ps1` - ensures PowerShellGet is present
* `stage1.ps1` - ensures chocolatey is present
* `stage2.ps1` - installs [Require](https://www.powershellgallery.com/packages/require) module that facilitates other module import and download
