<#
    .SYNOPSIS
    Get security policy settings being read from Local Security Policy using secedit.exe

    .DESCRIPTION
    Get security policy settings being read from Local Security Policy using secedit.exe

    .EXAMPLE
    Get-SecurityPolicy
#>
function Get-SecurityPolicy {
    [CmdletBinding()]
    param (
        # Specifies the path and file name of the log file to be used in the process
        [Parameter()]
        [System.String]
        $LogPath
    )

    try {
        $filePath = (New-TemporaryFile -ErrorAction Stop).FullName
        $seceditArgs = @(
            '/export'
            '/cfg "{0}"' -f $filePath
        )
        if ($LogPath) {
            $seceditArgs += '/log "{0}"' -f $LogPath
        }

        $pinfo = [System.Diagnostics.ProcessStartInfo]::new()
        $pinfo.FileName = 'secedit.exe'
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = $seceditArgs -join ' '
        $proc = [System.Diagnostics.Process]::new()
        $proc.StartInfo = $pinfo
        $null = $proc.Start()
        $proc.WaitForExit()
        $output = $proc.StandardOutput.ReadToEnd().Trim()

        if ($output -notlike '*task has completed successfully*') {
            throw $output
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