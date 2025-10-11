function Find-Rscript {
    <#
    .SYNOPSIS
        Finds Rscript.exe for a specified R version (64-bit only).
    
    .DESCRIPTION
        Searches for Rscript.exe in environment variables, registry, and common 
        installation locations. Throws an error if not found.
    
    .PARAMETER Version
        The R version to find (e.g., "4.5.1")
    
    .EXAMPLE
        Find-Rscript -Version "4.5.1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    $searchPaths = @()
    
    # 1. Check PATH environment variable
    Write-Verbose "Checking PATH environment variable..."
    $pathDirs = $env:PATH -split ';' | Where-Object { $_ -match 'R' }
    foreach ($dir in $pathDirs) {
        if (Test-Path $dir) {
            # Only add if it's the x64 bin directory
            if ($dir -match 'bin\\x64$') {
                $searchPaths += $dir
            }
        }
    }
    
    # 2. Check R_HOME environment variable
    if ($env:R_HOME) {
        Write-Verbose "Checking R_HOME environment variable: $env:R_HOME"
        $searchPaths += Join-Path $env:R_HOME "bin\x64"
    }
    
    # 3. Check Windows Registry
    Write-Verbose "Checking Windows Registry..."
    $registryPaths = @(
        "HKLM:\\SOFTWARE\\R-core\\R\$Version",
        "HKCU:\\SOFTWARE\\R-core\\R\$Version"
    )
    
    foreach ($regPath in $registryPaths) {
        try {
            if (Test-Path $regPath) {
                $installPath = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).InstallPath
                if ($installPath) {
                    Write-Verbose "Found registry entry: $installPath"
                    $searchPaths += Join-Path $installPath "bin\x64"
                }
            }
        } catch {
            # Silently continue if registry key doesn't exist
        }
    }
    
    # 4. Check common installation directories
    Write-Verbose "Checking common installation locations..."
    $commonPaths = @(
        "C:\\Program Files\\R\\R-$Version",
        "$env:ProgramFiles\\R\\R-$Version",
        "$env:LOCALAPPDATA\\Programs\\R\\R-$Version",
        "C:\\R\\R-$Version"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $searchPaths += Join-Path $path "bin\x64"
        }
    }
    
    # 5. Search for any R installation matching the version
    Write-Verbose "Searching for R installations..."
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
    foreach ($drive in $drives) {
        $possiblePaths = @(
            "$($drive.Root)Program Files\\R\\R-$Version",
            "$($drive.Root)R\\R-$Version"
        )
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $searchPaths += Join-Path $path "bin\x64"
            }
        }
    }
    
    # Remove duplicates and search for Rscript.exe
    $searchPaths = $searchPaths | Select-Object -Unique
    
    foreach ($path in $searchPaths) {
        $rscriptPath = Join-Path $path "Rscript.exe"
        Write-Verbose "Checking: $rscriptPath"
        
        if (Test-Path $rscriptPath) {
            # Verify this is the correct version
            try {
                $versionOutput = & $rscriptPath --version 2>&1
                if ($versionOutput -match $Version) {
                    Write-Verbose "Found Rscript.exe at: $rscriptPath"
                    return $rscriptPath
                }
            } catch {
                # Continue searching if version check fails
            }
        }
    }
    
    # If not found, throw an error
    throw "Rscript.exe for R version $Version not found. Searched in environment variables, registry, and common installation locations."
}

function Invoke-RCode {
    <#
    .SYNOPSIS
        Executes R code using a specified R version.
    
    .DESCRIPTION
        Finds Rscript.exe for the specified R version and executes the provided R code.
    
    .PARAMETER Code
        The R code to execute.
    
    .PARAMETER Version
        The R version to use (e.g., "4.5.1")
    
    .EXAMPLE
        Invoke-RCode -Code "print('Hello from R')" -Version "4.5.1"
    
    .EXAMPLE
        Invoke-RCode -Code "cat(R.version.string)" -Version "4.5.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Code,
        
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    try {
        # Find Rscript.exe for the specified version
        $rscriptPath = Find-Rscript -Version $Version
        
        # Write R code to a temporary file to avoid argument parsing issues
        $tempRFile = [System.IO.Path]::GetTempFileName()
        $tempRFile = [System.IO.Path]::ChangeExtension($tempRFile, '.R')
        
        try {
            # Write the R code to the temp file with UTF8 encoding without BOM
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($tempRFile, $Code, $utf8NoBom)
            
            # Execute the R script file and capture output
            $output = & $rscriptPath --vanilla $tempRFile 2>&1
            
            # Display output
            $output | ForEach-Object { Write-Host $_ }
            
            if ($LASTEXITCODE -ne 0) {
                throw "R code execution failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            # Clean up temp file
            if (Test-Path $tempRFile) {
                Remove-Item $tempRFile -ErrorAction SilentlyContinue
            }
        }
        
    } catch {
        Write-Error "Failed to execute R code: $($_.Exception.Message)"
        throw
    }
}

function FindRVersionFromRenv {
    <#
    .SYNOPSIS
        Finds the R version from a renv.lock file.
    
    .DESCRIPTION
        Searches for a renv.lock file in the parent directory, parses it, 
        and returns the R version. Throws an error if the file is not found.
    
    .EXAMPLE
        FindRVersionFromRenv
    #>
    [CmdletBinding()]
    param()

    $renvLockPath = Join-Path (Get-Location) "renv.lock"

    if (-not (Test-Path $renvLockPath)) {
        throw "renv.lock not found at $renvLockPath"
    }

    try {
        $renvLockContent = Get-Content $renvLockPath -Raw | ConvertFrom-Json
        $rVersion = $renvLockContent.R.Version
        return $rVersion
    }
    catch {
        throw "Failed to parse renv.lock or find R version: $($_.Exception.Message)"
    }
}

function Invoke-RCode-Renv {
    <#
    .SYNOPSIS
        Executes R code using the R version specified in renv.lock.
    
    .DESCRIPTION
        Finds the R version from renv.lock and executes the provided R code.
    
    .PARAMETER Code
        The R code to execute.
    
    .EXAMPLE
        Invoke-RCode-Renv -Code "print('Hello from R')"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Code
    )

    try {
        $rVersion = FindRVersionFromRenv
        Invoke-RCode -Version $rVersion -Code $Code
    }
    catch {
        Write-Error "Failed to execute R code using renv version: $($_.Exception.Message)"
        throw
    }
}
