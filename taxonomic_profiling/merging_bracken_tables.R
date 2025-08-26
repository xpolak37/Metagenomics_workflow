suppressMessages(suppressWarnings({library(data.table)
library(dplyr)}))

# Get command-line arguments (excluding default R arguments)
args <- commandArgs(trailingOnly = TRUE)

# Assign arguments to variables
path_bracken_output  <- args[1]
output_file <- args[2]

# Get all tsv files in the folder
files <- list.files(path_bracken_output,pattern = "\\.tsv$",full.names = TRUE)

# Initialize an empty list to store data
df_list_counts <- list()
df_list_abundances <- list()

# Loop through files
for (f in files) {
  # Derive sample name from filename (remove extension)
  sample_name <- gsub("_L\\d+_.+_db1.bracken\\.tsv$","",(basename(f)))
  
  # Read file
  tmp <- fread(f) %>%
    select(name, new_est_reads, fraction_total_reads) %>%
    rename(!!sample_name := new_est_reads)
  
  df_list_counts[[sample_name]] <- tmp %>% select(name, !!sample_name)
  
  tmp <- tmp %>%
    select(name, fraction_total_reads) %>%
    rename(!!sample_name := fraction_total_reads)
  
  df_list_abundances[[sample_name]] <- tmp %>% select(name, !!sample_name)
}

# Merge all dfs by "name"
merged_df_counts <- Reduce(function(x, y) full_join(x, y, by = "name"), df_list_counts)
merged_df_abundances <- Reduce(function(x, y) full_join(x, y, by = "name"), df_list_abundances)

# Replace NAs with 0 (in case some taxa don’t appear in all samples)
merged_df_counts[is.na(merged_df_counts)] <- 0
merged_df_abundances[is.na(merged_df_abundances)] <- 0

# Write output
write.table(merged_df_counts, file.path(output_file,"BRACKEN_counts.tsv"),
            sep = "\t",row.names = FALSE,quote = FALSE)
write.table(merged_df_abundances, file.path(output_file,"BRACKEN_abundances.tsv"),
            sep = "\t",row.names = FALSE,quote = FALSE)