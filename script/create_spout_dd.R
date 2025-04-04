# R script to create spout formatted data dictionary from ESP original data dictionary with levels
library(dplyr)
library(purrr)
library(jsonlite)
library(digest)
library("readxl")
# Load data dictionary
# data_dict <- read.csv("data/esp_data_dictionary.csv", stringsAsFactors = FALSE)
data_dict <-read_excel("data/20-M-0166_NSRR Legend 20250404.xlsx", sheet = "DataDictionary")

# Create base table
table1 <- data_dict %>%
  group_by(QUESTION_NAME) %>%
  summarise(
    folder = first(FORM_NAME),
    display_name = first(QUESTION_TEXT),
    description = "",
    type = if_else(any(!is.na(CODEVALUE) & CODEVALUE != ""), "choices", NA_character_),
    units = "",
    domain = NA_character_,
    labels = NA_character_,
    calculation = "",
    commonly_used = "",
    forms = first(FORM_NAME)
  ) %>%
  ungroup()

# Process categorical variables
categorical_data <- data_dict %>%
  filter(!is.na(CODEVALUE) & CODEVALUE != "") %>%
  mutate(CODEVALUE = as.character(CODEVALUE)) %>%
  select(QUESTION_NAME, CODEVALUE, DISPLAY) %>%
  arrange(QUESTION_NAME, CODEVALUE)

if(nrow(categorical_data) > 0) {
  # Generate JSON objects
  json_objects <- categorical_data %>%
    group_by(QUESTION_NAME) %>%
    summarise(
      levels = list(
        pmap(list(CODEVALUE, DISPLAY), ~ list(value = ..1, display_name = ..2, description = ""))
      ),
      n_levels = n(),
      .groups = "drop"
    ) %>%
    mutate(
      json_name = paste0(tolower(gsub(" ", "_", QUESTION_NAME)), "_", n_levels),
      json_str = map_chr(levels, ~ toJSON(.x, auto_unbox = TRUE))
    )
  
  # Detect and consolidate duplicate JSONs
  json_objects <- json_objects %>%
    mutate(
      json_hash = map_chr(json_str, ~ digest(.x))
    ) %>%
    group_by(json_hash) %>%
    mutate(
      group_id = cur_group_id(),
      consolidated_name = first(json_name)
    ) %>%
    ungroup()
  
  # Update domain column in table1
  domain_mapping <- json_objects %>%
    select(QUESTION_NAME, domain = consolidated_name)
  
  table1 <- table1 %>%
    left_join(domain_mapping, by = "QUESTION_NAME") %>%
    mutate(
      domain = if_else(type == "choices", coalesce(domain.y, domain.x), domain.x)
    ) %>%
    select(-domain.x, -domain.y) %>%
    rename(domain = domain)
  
  # Create unique JSON files --------------------------------------------------
  # Create domain directory if it doesn't exist
  if(!dir.exists("domain")) dir.create("domain", recursive = TRUE)
  
  # Write JSON files for each unique code list
  json_objects %>%
    group_by(group_id) %>%
    slice(1) %>%
    ungroup() %>%
    select(consolidated_name, levels) %>%
    pwalk(function(consolidated_name, levels) {
      json_path <- file.path("domain", paste0(consolidated_name, ".json"))
      write_json(
        x = levels,
        path = json_path,
        auto_unbox = TRUE,
        pretty = TRUE
      )
    })
}

# more editing to the data dictionary
# reorder the columns in table 1
table1<-table1%>%
  dplyr::rename(id="QUESTION_NAME")%>%
  dplyr::mutate(id=tolower(id),
                type = case_when(
                  is.na(type) & grepl("score|scale|equivalent|many|long|module|number|age|sum|percentile", display_name, ignore.case = TRUE) ~ "numeric",
                  is.na(type) & grepl("time", display_name, ignore.case = TRUE) ~ "time",
                  TRUE ~ type
                ),
                folder = gsub(":", "-", folder))%>%
  select(folder,id,display_name,description,type,units,domain,labels,calculation,commonly_used,forms)
# set type of GUID to identifider, sex, race, ethnicity to string, replace spaces in "age at first date in interval" to underscore
table1[which(table1$id=="guid"),"type"]<-"identifier"
table1[which(table1$id%in%c("sex","race","ethnicity")),"type"]<-"string"
table1[which(table1$id=="age at first date in interval"),"id"]<-"age_at_first_date_in_interval"


# Write output
write.csv(table1, "esp_spout_dd.csv", row.names = FALSE, na = "")

