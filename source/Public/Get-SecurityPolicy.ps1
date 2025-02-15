<#
    .SYNOPSIS
    Get security policy settings being read from Local Security Policy using secedit.exe

    .DESCRIPTION
    Get security policy settings being read from Local Security Policy using secedit.exe

    .PARAMETER All
    Get all settings from all sections

    .PARAMETER SystemAccess
    Get specific setting from System Access section

    .PARAMETER EventAudit
    Get specific setting from Event Audit section

    .EXAMPLE
    Get-SecurityPolicy -Verbose -All

    .EXAMPLE
    Get-SecurityPolicy -SystemAccess LockoutBadCount

    .EXAMPLE
    Get-SecurityPolicy -SystemAccess MinimumPasswordLength
#>
function Get-SecurityPolicy {
    [CmdletBinding()]
    param (

    )

    try {
        $filePath = (New-TemporaryFile -ErrorAction Stop).FullName
        $pinfo = [System.Diagnostics.ProcessStartInfo]::new()
        $pinfo.FileName = 'secedit.exe'
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = '/export /cfg "{0}"' -f $filePath
        $proc = [System.Diagnostics.Process]::new()
        $proc.StartInfo = $pinfo
        $null = $proc.Start()
        $proc.WaitForExit()
        $output = $proc.StandardOutput.ReadToEnd().Trim()

        if ($output -notlike '*task has completed successfully*') {
            throw $output


            Write-Warning -Message ('Failed to export security policy: {0}' -f $output)
            return
        }

        $index = 0
        $result = [ordered]@{}
        $contents = Get-Content -LiteralPath $filePath -Raw -ErrorAction Stop
        [regex]::Matches($contents,'(?<=\[)(.*)(?=\])') | ForEach-Object {
            $title = $_
            [regex]::Matches($contents,'(?<=\]).*?((?=\[)|(\Z))',[System.Text.RegularExpressions.RegexOptions]::Singleline)[$index] | ForEach-Object {
                $section = [ordered]@{}
                $_.value -split '\r\n' | Where-Object { $_.length -gt 0 } | ForEach-Object {
                    $value = [regex]::Match($_,'(?<=\=).*').Value
                    $name = [regex]::Match($_,'.*(?=\=)').Value
                    $section[$name.ToString().Trim()] = $value.ToString().Trim()
                }
                $result[$title.Value] = $section
            }
            $index += 1
        }

        [pscustomobject]$result
    }
    catch {
        if ($PSBoundParameters.ErrorAction -eq 'Stop') {
            throw
        }
        else {
            Write-Warning -Message ('Failed to export security policy: {0}' -f $_.Exception.Message)
        }
    }
    finally {
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
    }
}