[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [String]$computerName = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"

Write-Verbose "Try to get and remove WinRM HTTP listener"
try
{
    $listener = Get-ChildItem wsman:\localhost\Listener\ | Where-Object -Property Keys -eq 'Transport=HTTP'
    if ($listener) {
        Write-Verbose "WinRM HTTP listener found. Removing.."
        $listener | Remove-Item -Recurse
        Write-Verbose "WinRM HTTP listener removed succesfully"
    }
    else {
        Write-Verbose "WinRM HTTP listener does not exist"
    }
}
catch
{
    Write-Warning "Exception for WinRM HTTP listener $($_.Exception.Message)"
}

Write-Verbose "Try to get and remove WinRM HTTP Firewall rule"
try
{
    $netFirewallRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
    if ($netFirewallRule) {
        Write-Verbose "WinRM HTTP Firewall rule found. Removing.."
        Remove-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"
        Write-Verbose "WinRM HTTP Firewall rule removed succesfully"
    }
    else {
        Write-Verbose "Firewall rule Windows Remote Management (HTTP-In) does not exist"
    }
}
catch
{
    Write-Warning "Exception for WinRM HTTP Firewall $($_.Exception.Message)"
}

Write-Verbose "Creating Self-Signed certificate for WinRM over HTTPS"
try
{
    $serverCertificate = New-SelfSignedCertificate -DnsName $ComputerName -CertStoreLocation Cert:\LocalMachine\My
    Write-Verbose "Self-Signed certificate created"
}
catch
{
    Write-Warning "Failed to create a new self siogned certificate: $($_.Exception.Message)"
}

Write-Verbose "Configuring WS MAN"
try
{
    $null = Set-WSManInstance -ResourceURI winrm/config/client/auth -ValueSet @{Basic = "true"}
    $null = Set-WSManInstance -ResourceURI winrm/config/service/auth -ValueSet @{Basic = "true"}
    Write-Verbose "Basic auth settings applied for service and client"
}
catch
{
    Write-Error "Exception changing auth parameters: $($_.Exception.Message)"
}

Write-Verbose "Create WS MAN HTTPS listener"
try
{
    $newListener = Get-ChildItem wsman:\localhost\Listener\ | Where-Object -Property Keys -eq 'Transport=HTTPS'
    if ($newListener) {
        Write-Verbose "HTTPS Listener already present. Overwritting.."
        $null = $newListener | Remove-Item -Recurse -Force
        $null = New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address = '*'; Transport = 'HTTPS' } -ValueSet @{Hostname = "$($computerName)"; CertificateThumbprint = "$($serverCertificate[0].ThumbPrint)" }
        Write-Verbose "WinRM HTTPS listener created"
    }
    else {
        $null = New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address = '*'; Transport = 'HTTPS' } -ValueSet @{Hostname = "$($computerName)"; CertificateThumbprint = "$($serverCertificate[0].ThumbPrint)" }
        Write-Verbose "WinRM HTTPS listener created"
    }
}
catch
{
    Write-Error "Exception creating WS MAN listener $($_.Exception.Message)"
}

Write-Verbose "Create WinRM over HTTPS firewall rule"
try
{
    $newNetFirewallRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -ErrorAction SilentlyContinue
    if ($newNetFirewallRule) {
        Write-Verbose "Firewall rule Windows Remote Management (HTTPS-In) already exist"
    }
    else {
        $null = New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986
        Write-Verbose "Firewall rule Windows Remote Management (HTTPS-In) created"
    }
}
catch
{
    Write-Error "Exception creating firewall rule $($_.Exception.Message)"
}
