. .\Invoke-Rscript.ps1

Invoke-RCode -Version "4.5.0" -Code "1+1" 

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