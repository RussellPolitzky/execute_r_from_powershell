# 1. Load the functions from the script
. .\commands\Invoke-Rscript.ps1

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

# 4. Example using renv.lock
Invoke-RCode-Renv -Code @'
print("Hello from R, using the version specified in renv.lock!")
print(R.version.string)
'@