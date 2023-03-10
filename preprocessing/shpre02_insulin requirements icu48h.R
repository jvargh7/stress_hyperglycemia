
sh48h_variables <- readxl::read_excel("data/Stress Hyperglycemia Variable List.xlsx",sheet="icu48h") %>% 
  dplyr::filter(!is.na(variable))

# read_csv(paste0(path_sh_folder,"/Glucose and Insulin Data/raw/METABOCABG-ICU days 1 and 2_12.16.22.csv")) %>% 
#   summarize_all(~sum(!is.na(.))) %>% 
#   pivot_longer(names_to="variable",values_to="value",cols=everything()) %>% 
#   write_csv(.,file="preprocessing/shpre02_icu48h.csv")


icu48h <- read_csv(paste0(path_sh_folder,"/Glucose and Insulin Data/raw/METABOCABG-ICU days 1 and 2_12.16.22.csv")) %>% 
  rename_with(~ sh48h_variables$new_var[which(sh48h_variables$variable == .x)], 
              .cols = sh48h_variables$variable) %>% 
  mutate_at(vars(date_icuadmission,date2),~lubridate::mdy(.)) %>% 
  mutate(date_icuadmission = case_when(is.na(date_icuadmission) ~ date2,
                                       TRUE ~ date_icuadmission))

demographics <- icu48h %>% 
  dplyr::filter(!is.na(age)) %>% 
  dplyr::select(record_id,age,sex,race,otherrace,bmi,weight)



icu48h_glucose <- icu48h %>%
  dplyr::filter(str_detect(event,"CABG")) %>% 
  dplyr::select(record_id,date_icuadmission,
                starts_with("time_icu"),starts_with("glucose_icu")) %>% 
  pivot_longer(cols=-one_of("record_id","date_icuadmission"),names_to=c(".value","Var"),names_sep="[0-9]+$") %>% 
  dplyr::select(-Var) %>% 
  rename(date = date_icuadmission) %>% 
  group_by(record_id) %>% 
  mutate(timepoint = 1:n()) %>% 
  dplyr::filter(!is.na(time_icu)) %>%
  mutate(date_calendar = case_when(timepoint == 1 ~ date,
                                   (time_icu < dplyr::lag(time_icu,1)) ~ date + 1,
                                    TRUE ~ NA_real_)) %>% 
  mutate(date_calendar = zoo::na.locf(date_calendar)) %>% 
  mutate(date_calendar = case_when(date_calendar < date ~ date,
                                   TRUE ~ date_calendar)) %>% 
  dplyr::select(-date)

icu48h_ivinsulin <- icu48h %>%
  dplyr::filter(str_detect(event,"CABG")) %>% 
  dplyr::select(record_id,date_icuadmission,
                starts_with("time_idr"),starts_with("insulin_idr"),starts_with("insulin_iv"))  %>% 
  pivot_longer(cols=-one_of("record_id","date_icuadmission"),names_to=c(".value","Var"),names_sep="[0-9]+$") %>% 
  dplyr::select(-Var) %>% 
  dplyr::filter(!is.na(insulin_idr)) %>%
  group_by(record_id) %>% 
  mutate(timepoint = 1:n(),
         min_date = min(date_icuadmission)) %>% 
  rename(date = date_icuadmission) %>%
  mutate(date_calendar = case_when(timepoint == 1 ~ date,
                                   (time_idrstart < dplyr::lag(time_idrstart,1)) & date == min(date) ~ date + 1,
                                   TRUE ~ NA_real_)) %>% 
  mutate(date_calendar = zoo::na.locf(date_calendar)) %>% 
  mutate(date_calendar = case_when(date_calendar < date ~ date,
                                   TRUE ~ date_calendar)) %>% 
  dplyr::select(-date,-min_date) 

icu48h_subqinsulin <- icu48h %>%
  dplyr::filter(anysq_insulin=="Yes") %>% 
  dplyr::select(record_id,date_icuadmission,
                contains("sq"),-anysq_insulin) %>% 
  pivot_longer(cols=-one_of("record_id","date_icuadmission","total_insulin_sq"),names_to=c(".value","Var"),names_sep="[0-9]+$") %>% 
  dplyr::filter(!is.na(time_sq))


icu48h_poctmeals <- icu48h %>% 
  dplyr::select(record_id,date_icuadmission,date2,
                contains("poct")) %>% 
  rename_all(~str_replace(.,"poct_","")) %>% 
  pivot_longer(cols=-one_of("record_id","date_icuadmission","date2"),names_to=c(".value","Var"),names_sep="_") %>% 
  dplyr::filter(!is.na(time)) %>% 
  rename(meal = Var) %>% 
  mutate(meal = case_when(meal == "bf" ~ "Breakfast",
                          meal == "lunch" ~ "Lunch",
                          meal == "dinner" ~ "Dinner",
                          meal == "hs" ~ "HS",
                          meal == "addl" ~ "Additional",
                          TRUE ~ NA_character_))


saveRDS(icu48h,paste0(path_sh_folder,"/Glucose and Insulin Data/working/icu48h.RDS"))
saveRDS(icu48h_glucose,paste0(path_sh_folder,"/Glucose and Insulin Data/working/icu48h_glucose.RDS"))
saveRDS(icu48h_ivinsulin,paste0(path_sh_folder,"/Glucose and Insulin Data/working/icu48h_ivinsulin.RDS"))
saveRDS(icu48h_subqinsulin,paste0(path_sh_folder,"/Glucose and Insulin Data/working/icu48h_subqinsulin.RDS"))
saveRDS(icu48h_poctmeals,paste0(path_sh_folder,"/Glucose and Insulin Data/working/icu48h_poctmeals.RDS"))
saveRDS(demographics,paste0(path_sh_folder,"/Glucose and Insulin Data/working/demographics.RDS"))
