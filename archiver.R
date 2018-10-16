# Web-scraping Gun Violence Archive data (2014-).

#### 0. Preamble ####

if (!require("pacman")) install.packages("pacman")
pacman::p_load('rvest', 'seleniumPipes', 'tidyr', 'data.table', 'lubridate')

if (Sys.getenv("HOME") == "/Users/gforte") {
setwd(paste0(Sys.getenv("HOME"),'/Dropbox/git/GunViolenceArchiveR'))
}

missinglog <- c() #Logs days without recorded accidents.

#### 0.1 Functions ####


#### 1. Scraping (note: requires Docker) ####

# In running RSelenium, the answer to this post was helpful:
# https://stackoverflow.com/questions/45395849/cant-execute-rsdriver-connection-refused

#### 1.0 Setup ####
# This section is is pretty much a port of https://github.com/jamesqo/gun-violence-data to R.

system('docker pull selenium/standalone-chrome')
system('docker run -d -p 4445:4444 selenium/standalone-chrome')

remDr <- remoteDr(browserName = "chrome", port = 4445L)
remDr

#### 1.1 Loop ####
for (year_n in (2014:2018))  {

  for (month_n in (1:12)) {

    # Refresh the month data.table
    dt_month <- data.table(date=character(), state=character(), location=character(),
                          address=character(), killed=character(), injured=character(),
                          incidentno=character(), source=character(), stringsAsFactors=FALSE)
    # Refresh the day data.table
    dt_day <- data.table(date=character(), state=character(), location=character(),
                         address=character(), killed=character(), injured=character(),
                         incidentno=character(), source=character(), stringsAsFactors=FALSE)

    for (day_n in 1:days_in_month(month_n)) {

      #### 1.1.1 Daily loop utilities ####
      remDr %>% go("http://www.gunviolencearchive.org/query")
      webElem <- remDr %>% findElement(using = "css selector", ".filter-dropdown-trigger") %>%
                 elementClick #Add a rule...
      webElem <- remDr %>% findElement(using = "link text", "Date") %>%
                 elementClick #Selecting Date refinement
      Sys.sleep(runif(1, 1, 3))

      #### 1.1.2 Date Input ####
      datefrom <- remDr %>% findElement(using = "css selector", "input[id$='filter-field-date-from']") #Date from...
      dateto   <- remDr %>% findElement(using = "css selector", "input[id$='filter-field-date-to']")   #...Date to

      date <- paste0(month_n, "/", day_n, "/", year_n)
      datescript <- paste0("arguments[0].value = \"", date, "\"; arguments[1].value = \"", date, "\";")
      remDr %>% executeScript(datescript, list(datefrom, dateto))

      remDr %>% findElement(using = "css selector", "#edit-actions-execute") %>%
                elementClick #Search
      Sys.sleep(runif(1, 1, 3))

      #### 1.1.3 Search Results ####
      remDr %>% executeScript("window.scrollTo(0,document.body.scrollHeight);")

      landingpage    <- remDr %>% getCurrentUrl

      tryCatch(remDr %>% findElement(using = "css selector", "li.pager-last.last > a") %>% elementClick) #Last page
      npages <- remDr %>% getCurrentUrl %>% substr(., nchar(.), nchar(.)) %>%
                as.double(.) %>% ifelse(!is.na(.), ., 0) %>% + 1 #Getting the number of pages

      if (npages>1) { #Getting a list of pages
        pagelist <- remDr %>% getCurrentUrl %>% substr(., 1, nchar(.)-1) %>% paste0(.,(1:npages))
        pagelist <- c(landingpage, pagelist)
      } else {
        pagelist <- landingpage
      }

      #Making a clean table for each page
      colnm <- c("date", "state", "location", "address", "killed", "injured", "incidentno", "source")
      
      for (i in (1:npages)) {
          table <- pagelist[i] %>% read_html() %>% html_nodes(css='tr') %>% .[-1] %>% gsub("\"","", .) %>%
                   gsub("<tr class=odd>\n", "", .) %>% gsub("<tr class=even>\n", "", .) %>%
                   gsub("<td>", "", .) %>% gsub("</td>", "<sep>",.) %>% gsub("\n", "", .) %>%
                   gsub("<ul class=links inline links-new-lines>\n<li class=0 first><a href=/incident/", "",.) %>%
                   gsub(">View Incident</a></li>\n<li class=1 last><a href=", "<sep>",.) %>%
                   gsub(" target=_blank>View Source</a></li>\n</ul></td> </tr>", "", .) %>%
                   gsub("<ul class=links inline links-new-lines><li class=0 first last><a href=/incident/", "",.) %>%
                   gsub("<ul class=links inline links-new-lines><li class=0 first><a href=/incident/","", .) %>%
                   gsub(">View Incident</a></li><li class=1 last><a ", "<sep>",.) %>%
                   gsub(">View Incident</a></li></ul><sep> </tr>", "",.) %>%
                   gsub(" target=_blank>View Source</a></li></ul><sep> </tr>", "",.) %>% gsub("href=", "",.) %>%
                   as.data.table %>% separate(".", colnm, sep = "<sep>")

      if (grepl("no incidents available.", toString(table$date[1]))) {
        table <- data.table(date=character(), state=character(), location=character(),
                            address=character(), killed=character(), injured=character(),
                            incidentno=character(), source=character(), stringsAsFactors=FALSE)
        missinglog <- c(missinglog, paste0(date," contains no gunshot accidents."))
      }

           dt_day <- data.table::rbindlist(list(dt_day,table), fill = T)
        }
      dt_month <- data.table::rbindlist(list(dt_month,dt_day), fill = T)
      filename <- paste0("m",month_n,"y",year_n)
      write.csv(dt_month, file = paste0(filename,".csv"))
      rm(filename)
      }
    }
  }

write(missinglog, file="missinglog.txt")
