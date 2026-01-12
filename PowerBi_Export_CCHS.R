# 1) Data cleaning
make_cchs_adults <- function(cchs) {
  cchs %>%
    filter(DHHGAGE %in% c(2,3,4,5)) %>%
    mutate(
      obese = case_when(
        HWTDGBCC == 2 ~ 1,
        HWTDGBCC == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      pa_cat = case_when(
        PAADVACV == 1 ~ "Active",
        PAADVACV == 2 ~ "Moderately active",
        PAADVACV == 3 ~ "Inactive",
        TRUE ~ NA_character_
      ),
      age_group = factor(
        DHHGAGE,
        levels = c(2,3,4,5),
        labels = c("18–34","35–49","50–64","65+")
      ),
      sex = factor(
        DHH_SEX,
        levels = c(1,2),
        labels = c("Male","Female")
      ),
      smoking = case_when(
        SMKDVSTY %in% c(1,2) ~ "Current smoker",
        SMKDVSTY %in% c(3,4,5,6) ~ "Non-smoker",
        TRUE ~ NA_character_
      ),
      income = factor(
        INCDGHH,
        levels = c(1,2,3,4,5,9),
        labels = c("<20k","20–39k","40–59k","60–79k","80k+","Not stated")
      ),
      inactive = case_when(
        pa_cat == "Inactive" ~ 1,
        pa_cat %in% c("Active","Moderately active") ~ 0,
        TRUE ~ NA_real_
      )
    ) %>%
    filter(
      !is.na(obese),
      !is.na(pa_cat),
      !is.na(smoking),
      !is.na(inactive),
      income != "Not stated"
    )
}

# 2) Apply cleaning function
cchs_adults <- make_cchs_adults(cchs)

# 3) Create Power BI respondent-level dataset
cchs_bi_respondent <- cchs_adults %>%
  transmute(
    respondent_id = row_number(),
    obese = obese,
    inactive = inactive,
    pa_cat = as.character(pa_cat),
    age_group = as.character(age_group),
    sex = as.character(sex),
    smoking = as.character(smoking),
    income = as.character(income),
    weight = if ("WTS_M" %in% names(cchs_adults)) WTS_M else NA_real_
  )

# 4) Basic validation checks
cat("Rows in BI extract:", nrow(cchs_bi_respondent), "\n")
cat("Obesity prevalence (unweighted):", mean(cchs_bi_respondent$obese), "\n")
cat("Inactivity rate (unweighted):", mean(cchs_bi_respondent$inactive), "\n")
cat("Missing weight proportion:", mean(is.na(cchs_bi_respondent$weight)), "\n")

# 5) Weighted validation (if survey weights exist)
if (!all(is.na(cchs_bi_respondent$weight))) {
  w <- cchs_bi_respondent$weight
  cat("Obesity prevalence (weighted):",
      weighted.mean(cchs_bi_respondent$obese, w, na.rm = TRUE), "\n")
  cat("Inactivity rate (weighted):",
      weighted.mean(cchs_bi_respondent$inactive, w, na.rm = TRUE), "\n")
}

# 6) Segment-level KPIs for monitoring
cchs_bi_kpis <- cchs_bi_respondent %>%
  group_by(age_group, sex, income, smoking, pa_cat) %>%
  summarise(
    n = n(),
    obese_rate_unw = mean(obese),
    inactive_rate_unw = mean(inactive),
    obese_rate_w = if (!all(is.na(weight))) weighted.mean(obese, weight, na.rm = TRUE) else NA_real_,
    inactive_rate_w = if (!all(is.na(weight))) weighted.mean(inactive, weight, na.rm = TRUE) else NA_real_,
    .groups = "drop"
  )

# 7) Export datasets for Power BI
write_csv(cchs_bi_respondent, "cchs_powerbi_respondent.csv")
write_csv(cchs_bi_kpis, "cchs_powerbi_segment_kpis.csv")

table(cchs_bi_respondent$pa_cat)
table(cchs_bi_respondent$age_group)
table(cchs_bi_respondent$sex)

