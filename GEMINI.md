# Project Overview

This project consists of a PowerShell script that provides a function to find the installation path of R executables on a Windows system. It is designed to locate specific versions of R by searching common installation directories and the Windows Registry.

## Key Files

*   `find-r-exes.ps1`: This is the main script containing the core logic. It defines the function `Find-RScriptExecutable` which takes an R version string as input and returns the path to the 64-bit `RScript.exe` if found.
*   `example_use.ps1`: This script provides a practical example of how to load and use the `Find-RScriptExecutable` function from `find-r-exes.ps1`.

## Usage

To use the functionality provided by this project, you need to dot-source the `find-r-exes.ps1` script into your PowerShell session. This will load the `Find-RScriptExecutable` function and make it available to be called.

### Example

```powershell
# 1. Load the function from the script
. .\find-r-exes.ps1

# 2. Call the function with the desired R version
$r_path = Find-RScriptExecutable -RVersion "4.5.1"

# 3. Use the returned path
if ($r_path) {
    Write-Host "Found RScript.exe at: $r_path"
    # & $r_path -e "print('Hello from R!')"
} else {
    Write-Host "Could not find the specified R version."
}
```
