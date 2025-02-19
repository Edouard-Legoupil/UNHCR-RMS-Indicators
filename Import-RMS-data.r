#####RMS Standard Scripts####

rm(list=ls()) # clear work space


## install Packages

# install.packages('robotoolbox')
# install.packages("remotes")
# remotes::install_github("dickoa/robotoolbox")


library(haven)
library(tidyverse)
library(readxl)
library(srvyr)
library(ggplot2)
library(robotoolbox)
library(labelled)
library(remotes)
library(dm)

####Data import from Kobo#####

### insert your username from kobo/UNHCR

## Or set thisup within your environement variable

#  edit directly the .Renviron file or access it by calling usethis::edit_r_environ() (assuming you have the usethis package installed)
# and entering the following two lines:
#
# KOBOTOOLBOX_URL="https://kobo.unhcr.org/"
# KOBOTOOLBOX_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxx

# kobo_token(username = "XXXX",
#            password = "XXXX",
#            url = "https://kobo.unhcr.org")
#
#
# ### enter your token
#
# kobo_setup(url = "https://kobo.unhcr.org",
#            token = "XXXXXXXXXXXXXXX")

### access data - enter name here

kobo_asset_list()

asset_list <- kobo_asset_list()
# uid <- filter(asset_list, name == "RMS CAPI v2") |>
#   pull(uid)
asset <- kobo_asset("aM4SnZ43SSxXEh8HecqUzh")
asset


df <- kobo_data(asset)
df


### merge repeat group questions into household dataset

glimpse(df$main)
glimpse(df$S1)
glimpse(df$S2)
glimpse(df$P2.S3)



main <- df$main
S1 <- df$S1 ##HH roster

##S2 <- df$S2 ##individidual
#P2 <- df$P2.S3 ##children education
#rm(list="df")

#### get dimensions of datasets above

dim(main)
dim(S1)
dim(S2)
dim(P2)

### merge all individual datasets
ind <- S1
# ind_merge <- merge(S1,S2, by=c("_index","_parent_index"))
# ind <- merge (ind_merge, P2, by=c("_index", "_parent_index"))
#
#
# ###Removed unused datasets
#
# rm(ind_merge)
# rm(P2)
# rm(S1)
# rm(S2)


###Create function that turn character values into numeric

labelled_chr2dbl <- function(x) {
  varlab <- var_label(x)
  vallab <- val_labels(x)
  vallab <- setNames(as.numeric(vallab),
                     names(vallab))
  x <- as.numeric(as.character(x))
  var_label(x) <- varlab
  val_labels(x) <- vallab
  x
}


####Calculate primary citizenship for individual dataset
ind <- ind %>%

mutate( # primary citizenship from REF01 and REF02
  citizenship_com = case_when(
    REF01 == "1" ~ "ZAF", ##here enter the country code of enumeration
    REF01 %in% c("0", "98") ~ as.character(ind$REF02),
    REF01 == "99" ~ "99"
  )
) %>%
  mutate(citizenship_com = labelled(citizenship_com,
                                labels = val_labels(ind$REF02),
                                label = var_label(ind$REF02)))

###Calculate age groups for disaggregation for ind and main dataset


ind$HH07_cat <- cut(ind$HH07,
                    breaks = c(-1, 4, 17, 59, Inf),
                    labels = c("0-4", "5-17", "18-59", "60+"))

table(ind$HH07_cat, useNA = "ifany")

### Disability for disaggregation ind dataset
####Calculated based on WG suggestions : https://www.washingtongroup-disability.com/fileadmin/uploads/wg/Documents/WG_Document__5C_-_Analytic_Guidelines_for_the_WG-SS__Stata_.pdf

##Step.1 Create variable for calculating disability
names(main)
names(ind)

ind <-  ind %>%
  mutate( # disability identifier variables according to Washington Group standards
    disaux1_234 = DIS01 %in% c("2","3","4"), # indicator variables for all 6 domains with value TRUE if SOME DIFFICULTY or A LOT OF DIFFICULTY or CANNOT DO AT ALL
    disaux2_234 = DIS02 %in% c("2","3","4"),
    disaux3_234 = DIS03 %in% c("2","3","4"),
    disaux4_234 = DIS04 %in% c("2","3","4"),
    disaux5_234 = DIS05 %in% c("2","3","4"),
    disaux6_234 = DIS06 %in% c("2","3","4"),

    disaux1_34 = DIS01 %in% c("3","4"), # indicator variables for all 6 domains with value TRUE if A LOT OF DIFFICULTY or CANNOT DO AT ALL
    disaux2_34 = DIS02 %in% c("3","4"),
    disaux3_34 = DIS03 %in% c("3","4"),
    disaux4_34 = DIS04 %in% c("3","4"),
    disaux5_34 = DIS05 %in% c("3","4"),
    disaux6_34 = DIS06 %in% c("3","4")
  ) %>%
  mutate(
    disSum234 = rowSums(select(., disaux1_234, disaux2_234 , disaux3_234 , disaux4_234 , disaux5_234 , disaux6_234)), # count number of TRUE indicator variables over 6 domains
    disSum34 = rowSums(select(., disaux1_34, disaux2_34 , disaux3_34 , disaux4_34 , disaux5_34 , disaux6_34)) # count number of TRUE indicator variables over 6 domains

  ) %>%
  mutate(
    DISABILITY1 = case_when( # : the level of inclusion is at least one domain/question is coded SOME DIFFICULTY or A LOT OF DIFFICULTY or CANNOT DO AT ALL.
      disSum234 >= 1 ~ 1,
      disSum234 == 0 & (!(DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99"))) ~ 0,
      DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99") ~ 98
    )
  ) %>%
  mutate(
    DISABILITY2 = case_when( # : the level of inclusion is at least two domains/questions are coded SOME DIFFICULTY or A LOT OF DIFFICULTY or CANNOT DO AT ALL or any 1 domain/question is coded A LOT OF DIFFICULTY or CANNOT DO AT ALL
      disSum234 >= 2 | disSum34 >=1  ~ 1,
      disSum234 < 2 & disSum34 == 0 & (!(DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99"))) ~ 0,
      DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99") ~ 98
    )
  ) %>%
  mutate(
    DISABILITY3 = case_when( # : the level of inclusion is at least one domain/question is coded A LOT OF DIFFICULTY or CANNOT DO AT ALL.
      disSum34 >= 1 ~ 1,
      disSum34 == 0 & (!(DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99"))) ~ 0,
      DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99") ~ 98
    )
  ) %>%
  mutate(
    DISABILITY4 = case_when( # : the level of inclusion is at least one domain/question is coded CANNOT DO AT ALL.
      DIS01=="4" | DIS02=="4" | DIS03=="4" | DIS04=="4" | DIS05=="4" | DIS06=="4" ~ 1,
      !(DIS01=="4" | DIS02=="4" | DIS03=="4" | DIS04=="4" | DIS05=="4" | DIS06=="4") & (!(DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99"))) ~ 0,
      DIS01 %in% c("98","99") & DIS02 %in% c("98","99") & DIS03 %in% c("98","99") & DIS04 %in% c("98","99") & DIS05 %in% c("98","99") & DIS06 %in% c("98","99") ~ 98
    )
  ) %>%
  mutate(
    DISABILITY1 = labelled(DISABILITY1,
                           labels = c(
                             "Without disability" = 0,
                             "With disability" = 1,
                             "Unknown" = 98
                           ),
                           label = "Washington Group disability identifier 1"),
    DISABILITY2 = labelled(DISABILITY2,
                           labels = c(
                             "Without disability" = 0,
                             "With disability" = 1,
                             "Unknown" = 98
                           ),
                           label = "Washington Group disability identifier 2"),
    DISABILITY3 = labelled(DISABILITY3,
                           labels = c(
                             "Without disability" = 0,
                             "With disability" = 1,
                             "Unknown" = 98
                           ),
                           label = "Washington Group disability identifier 3"),
    DISABILITY4 = labelled(DISABILITY4,
                           labels = c(
                             "Without disability" = 0,
                             "With disability" = 1,
                             "Unknown" = 98
                           ),
                           label = "Washington Group disability identifier 4"))
###Calculate having at least one disability identifier among 4 categories
ind <- ind %>%
  mutate(disab=
           case_when(DISABILITY1==1 | DISABILITY2==1 | DISABILITY3==1 | DISABILITY4==1 ~ 1,
                               DISABILITY1==0 | DISABILITY2==0 | DISABILITY3==0 | DISABILITY4==0 ~ 0,
                               TRUE ~ NA_real_)
   ) %>%
  mutate(disab = labelled(disab,
                           labels = c(
                             "Without disability" = 0,
                             "With disability" = 1)
                           ))
## Merge for below variables for disaggregation

##citizenship_com : Citizenship
##HH07_CAT : Age categories
##HH04 : Gender
##disab : Disability status
##pop_groups:Population group


####Merge datasets to have variables above in both datasets

## Import individual level variables to HH dataset to analyse sampled adult question


###Create similar variable names for merging with the individual dataset

main$HH02 <- main$name_selectedadult18
main$HH07 <- main$name_selectedadult18_age
main$"_parent_index" <- main$"_index"

##Select indicators for merge

ind_m <- ind %>%
  select("_parent_index", "HH07_cat", "disab", "citizenship_com","HH02", "HH07", "HH04") ##ADD VARIABLES FOR MERGING
main <- merge(ind_m, main, by=c("HH02", "HH07", "_parent_index"))

rm(ind_m)

## Import HH level variables from individual dataset

main_m <- main %>%
  select("_parent_index", "pop_groups", "end_result") ## ADD VARIABLES FOR MERGING

ind <- merge(main_m, ind, by = "_parent_index")

rm(main_m)

### Household head in main dataset is HH07 for age and HH04 for gender

main$HH07_cat <- cut(main$HH07,
                     breaks = c(-1, 4, 17, 59, Inf),
                     labels = c("0-4", "5-17", "18-59", "60+"))

