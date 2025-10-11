# Using PowerShell to Run Background R Jobs in Positron

This guide explains how to use the provided PowerShell functions to execute R scripts as background jobs from a PowerShell terminal, which is particularly useful when working within the Positron IDE.

## Loading the Functions

Before you can use the functions, you need to load them into your PowerShell session. This is done by "dot-sourcing" the `Invoke-Rscript.ps1` file. From your PowerShell terminal, navigate to the root of this project and run the following command:

```powershell
. .\commands\Invoke-Rscript.ps1
```

This command loads the `Invoke-RCode` and `Invoke-RCode-Renv` functions, making them available in your current terminal session.

## Executing R Code

There are two main functions you can use to execute R code:

### 1. `Invoke-RCode`: Specify the R Version Manually

This function allows you to execute R code with a specific version of R that you define.

**Example:**

```powershell
Invoke-RCode -Version "4.5.0" -Code "print('Hello from R!')"
```

You can also run multi-line scripts:

```powershell
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

### 2. `Invoke-RCode-Renv`: Use the R Version from `renv.lock`

This function is useful when you are working in a project that uses `renv` for package management. It automatically finds the `renv.lock` file in your project, reads the R version specified within it, and executes your R code using that version.

**Example:**

```powershell
Invoke-RCode-Renv -Code @'
print("Hello from R, using the version specified in renv.lock!")
print(R.version.string)
'@
```

## Running R Scripts as Background Jobs

The real power of using these functions in a PowerShell terminal within Positron is the ability to run long-running R scripts as background jobs. This frees up the R console in Positron for other tasks while your script processes in the background.

To run any of the above commands as a background job, you can use the `Start-Job` cmdlet in PowerShell.

**Example:**

```powershell
Start-Job -ScriptBlock {
    # First, load the functions within the job's scope
    . .\commands\Invoke-Rscript.ps1

    # Now, call the function
    Invoke-RCode-Renv -Code @'
    # This is a long-running script
    Sys.sleep(30) # Simulate a 30-second task
    print("Background job finished!")
    '@
}
```

You can check the status of your background jobs with `Get-Job` and retrieve the output with `Receive-Job`.

```powershell
# See the status of all jobs
Get-Job

# Get the output of a specific job (e.g., with Id 1)
Receive-Job -Id 1
```

This approach allows you to maintain an interactive R session in Positron while offloading heavy computations to the background, improving your workflow and productivity.
