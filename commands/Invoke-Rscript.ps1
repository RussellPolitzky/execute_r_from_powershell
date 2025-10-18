function Find-Rscript {
    <#
    .SYNOPSIS
        Finds the Rscript.exe executable for a specified R version.
    
    .DESCRIPTION
        This function locates the full path to Rscript.exe for a given R version.
        It searches a series of locations in the following order:
        1. Directories in the system's PATH environment variable.
        2. The path specified in the R_HOME environment variable.
        3. Windows Registry entries for R installations (both HKLM and HKCU).
        4. Common installation directories (e.g., C:\Program Files\R).
        5. A broader search across system drives.

        The function is designed to find 64-bit versions of R and will throw an
        error if a matching version cannot be found.
    
    .PARAMETER Version
        The R version to find (e.g., "4.5.1"). This must be a specific version string.
    
    .EXAMPLE
        Find-Rscript -Version "4.5.1"
        # Returns the full path to Rscript.exe for R version 4.5.1 if found.

    .OUTPUTS
        System.String. The full, absolute path to the Rscript.exe executable.

    .NOTES
        This function is intended to locate 64-bit R installations only.
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
        "HKLM:\\SOFTWARE\R-core\R\$Version",
        "HKCU:\\SOFTWARE\R-core\R\$Version"
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
        Executes a block of R code using a specified R version.
    
    .DESCRIPTION
        This function first uses Find-Rscript to locate the required R version,
        then executes the provided R code. The code is written to a temporary .R
        file to ensure proper execution and avoid command-line argument parsing
        issues, especially with multi-line scripts. The output from the R script
        is written to the host.
    
    .PARAMETER Code
        A string containing the R code to be executed. This can be a single line
        or a multi-line script block.
    
    .PARAMETER Version
        The R version to use for executing the code (e.g., "4.5.1").
    
    .EXAMPLE
        Invoke-RCode -Version "4.5.1" -Code "print('Hello from R!')"

    .EXAMPLE
        $RCode = @'
        data <- data.frame(x = 1:10, y = rnorm(10))
        summary(data)
        '@
        Invoke-RCode -Version "4.5.0" -Code $RCode
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
            
            # Execute the R script file and stream output directly to the console
            & $rscriptPath --vanilla $tempRFile 2>&1 | ForEach-Object { Write-Host $_ }
            
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
        Finds the R version from a renv.lock file in the current directory.
    
    .DESCRIPTION
        Searches for a renv.lock file in the current working directory. If found,
        it parses the file as JSON to extract and return the R version string
        specified under the "R.Version" key. Throws an error if the file is not
        found or cannot be parsed.
    
    .EXAMPLE
        # Assuming renv.lock is in the current directory:
        $version = FindRVersionFromRenv
        Write-Host "R Version from renv.lock: $version"

    .OUTPUTS
        System.String. The R version specified in the renv.lock file.

    .NOTES
        This function uses Get-Location to determine the search path, making it
        compatible with being dot-sourced into a PowerShell session, where it
        will use the caller's working directory.
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
        Executes R code using the R version specified in the project's renv.lock file.
    
    .DESCRIPTION
        This is a convenience function that automates R code execution in an renv
        project. It calls FindRVersionFromRenv to get the R version from the
        renv.lock file in the current directory, then passes that version and the
        provided R code to the Invoke-RCode function for execution.
    
    .PARAMETER Code
        A string containing the R code to be executed. This can be a single line
        or a multi-line script block.
    
    .EXAMPLE
        # Executes a simple command using the R version from renv.lock
        Invoke-RCode-Renv -Code "print(R.version.string)"

    .EXAMPLE
        # Executes a multi-line script
        $RCode = @'
        # This code will run with the project's specified R version
        data <- data.frame(x = 1:10, y = rnorm(10))
        print(summary(data))
        '@
        Invoke-RCode-Renv -Code $RCode
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