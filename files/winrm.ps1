function New-WinrmHttpsListener {
    <#
    .SYNOPSIS
    Configure WinRM HTTPS listener

    .DESCRIPTION
    New-WinrmHttpsListener function configures WinRM HTTPS listener with self-signed certificate and basic authentication.

    .PARAMETER Force
    Add -Force parameter to reconfigure WinRM HTTPS listener with new self-signed certificate.

    .PARAMETER Verbose
    Add -Verbose parameter to display detailed information about the operation done by the function.

    .NOTES
        Version History:
            0.1 - Initial script

    .EXAMPLE
    New-WinrmHttpsListener

    .EXAMPLE
    New-WinrmHttpsListener -Verbose 
    
    .EXAMPLE
    New-WinrmHttpsListener -Force

    .EXAMPLE
    New-WinrmHttpsListener -Force -Verbose *> c:\windows\temp\WinrmHttpsListener.log
    
    #>

    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [switch]$Force
    )

    begin {
        Write-Verbose "Begin - Set error action preference = stop"
        $ErrorActionPreference = "stop"
    }

    process {
        try {
            Write-Verbose "Remove WinRM HTTP listener"
            $listener = Get-ChildItem wsman:\localhost\Listener\ | Where-Object -Property Keys -eq 'Transport=HTTP'
            if ($listener) {
                $listener | Remove-Item -Recurse
                Write-Verbose "WinRM HTTP listener removed"
            }
            else {
                Write-Verbose "WinRM HTTP listener does not exist"
            }

            Write-Verbose "Remove firewall rule Windows Remote Management (HTTP-In)"
            $netFirewallRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
            if ($netFirewallRule) {
                Remove-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"
                Write-Verbose "Firewall rule Windows Remote Management (HTTP-In) removed"
            }
            else {
                Write-Verbose "Firewall rule Windows Remote Management (HTTP-In) does not exist"
            }

            Write-Verbose "Remove firewall rule Windows Remote Management - Compatibility Mode (HTTP-In)"
            $netFirewallRule = Get-NetFirewallRule -DisplayName "Windows Remote Management - Compatibility Mode (HTTP-In)" -ErrorAction SilentlyContinue
            if ($netFirewallRule) {
                Remove-NetFirewallRule -DisplayName "Windows Remote Management - Compatibility Mode (HTTP-In)"
                Write-Verbose "Firewall rule Windows Remote Management - Compatibility Mode (HTTP-In) removed"
            }
            else {
                Write-Verbose "Firewall rule Windows Remote Management - Compatibility Mode (HTTP-In) does not exist"
            }

            Write-Verbose "Change winrm/config/client/auth settings"
            $null = Set-WSManInstance -ResourceURI winrm/config/client/auth -ValueSet @{Basic = "true"; Digest = "false"; Kerberos = "false"; Negotiate = "true"; Certificate = "false"; CredSSP = "false" }
            Write-Verbose "winrm/config/client/auth settings changed"

            Write-Verbose "Change winrm/config/service/auth settings"
            $null = Set-WSManInstance -ResourceURI winrm/config/service/auth -ValueSet @{Basic = "true"; Kerberos = "false"; Negotiate = "true"; Certificate = "false"; CredSSP = "false" }
            Write-Verbose "winrm/config/service/auth settings changed"

            Write-Verbose "Create firewall rule Windows Remote Management (HTTPS-In)"
            $netFirewallRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -ErrorAction SilentlyContinue
            if ($netFirewallRule) {
                Write-Verbose "Firewall rule Windows Remote Management (HTTPS-In) already exist"
            }
            else {
                $null = New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986
                Write-Verbose "Firewall rule Windows Remote Management (HTTPS-In) created"
            }

            Write-Verbose "Create ServerCertificate for WinRM"
            $ServerCertificate = Get-ChildItem Cert:\LocalMachine\My -Recurse | Where-Object { $_.Subject -eq "CN=$($env:COMPUTERNAME)" } | Sort-Object -Property @{Expression = "notbefore"; Descending = $true }
            if ($ServerCertificate) {
                if ($Force) {
                    $ServerCertificate = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")
                    Write-Verbose "ServerCertificate for WinRM created"
                }
                else {
                    Write-Verbose "ServerCertificate for WinRM already exist"
                }

            }
            else {
                $ServerCertificate = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")
                Write-Verbose "ServerCertificate for WinRM created"
            }

            Write-Verbose "Create WinRM HTTPS listener"
            $listener = Get-ChildItem wsman:\localhost\Listener\ | Where-Object -Property Keys -eq 'Transport=HTTPS'
            if ($listener) {
                if ($Force) {
                    $null = $listener | Remove-Item -Recurse -Force
                    $null = New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address = '*'; Transport = 'HTTPS' } -ValueSet @{Hostname = "$env:COMPUTERNAME"; CertificateThumbprint = "$($ServerCertificate[0].ThumbPrint)" }
                    Write-Verbose "WinRM HTTPS listener created"
                }
                else {
                    Write-Verbose "WinRM HTTPS listener already exist"
                }
            }
            else {
                $null = New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address = '*'; Transport = 'HTTPS' } -ValueSet @{Hostname = "$env:COMPUTERNAME"; CertificateThumbprint = "$($ServerCertificate[0].ThumbPrint)" }
                Write-Verbose "WinRM HTTPS listener created"
            }

        }
        catch {
            Write-Host "Create WinRM HTTPS listener failed: $($_.Exception.Message)"
        }
    }

    end {
        Write-Verbose "Finally"
    }

}

New-WinrmHttpsListener