# Project Overview

This project consists of a PowerShell script that provides functions to find and execute R code using a specific version of R.

## Key Files

*   `Invoke-Rscript.ps1`: This is the main script containing the core logic. It defines two functions:
    *   `Find-Rscript`: This function locates the `Rscript.exe` executable for a specified R version by searching common installation directories, environment variables, and the Windows Registry.
    *   `Invoke-RCode`: This function executes a block of R code using the specified R version. It uses `Find-Rscript` to find the required `Rscript.exe`.
*   `Example_Use.ps1`: This script provides a practical example of how to load and use the `Invoke-RCode` function from `Invoke-Rscript.ps1`.

## Usage

To use the functionality provided by this project, you need to dot-source the `Invoke-Rscript.ps1` script into your PowerShell session. This will load the `Find-Rscript` and `Invoke-RCode` functions and make them available to be called.

### Example

```powershell
# 1. Load the functions from the script
. .\Invoke-Rscript.ps1

# 2. Call the function with the desired R version and code
Invoke-RCode -Version "4.5.0" -Code "print('Hello from R!')"

# 3. Example with a multi-line script
Invoke-RCode -Version "4.5.0" -Code @'
# Create a data frame
df <- data.frame(
    name  = c("Alice", "Bob", "Charlie"),
    age   = c(25, 30, 35),
    score = c(85, 90, 95)
)

# Calculate and display statistics
cat("Data Summary:\n")
cat("Average age:", mean(df$age), "\n")
cat("Average score:", mean(df$score), "\n")
cat("Total rows:", nrow(df), "\n")
'@
```