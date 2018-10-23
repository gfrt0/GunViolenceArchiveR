# Web-scraping Gun Violence Archive data (2014-).

#### 0. Preamble ####

if (!require("pacman")) install.packages("pacman")
pacman::p_load('rvest', 'seleniumPipes', 'tidyr', 'data.table', 'lubridate', 'anytime', 'plyr')

if (Sys.getenv("HOME") == "/Users/gforte") {
setwd(paste0(Sys.getenv("HOME"),'/Dropbox/git/GunViolenceArchiveR'))
}
tryCatch(lapply(c("2014", "2015", "2016", "2017", "2018"), dir.create))

halt       <- FALSE #Used to break out of loop once today is reached. 
colnm      <- c("date", "state", "location", "address", "killed", "injured", "incidentno", "source")

#### 1. Functions ####

decluttertable <- function(x) {
  
  x <- x %>% gsub("\"","", .) %>% gsub("<tr class=odd>|<tr class=even>", "", .) %>%
              gsub("<td>", "", .) %>% gsub("</td>", "<sep>",.) %>% gsub("\n", "", .) %>%
              gsub("<ul class=links inline links-new-lines>\n<li class=0 first><a href=/incident/", "",.) %>%
              gsub(" target=_blank>View Source</a></li>\n</ul></td> </tr>", "", .) %>%
              gsub(" target=_blank>View Source</a></li></ul><sep> </tr>", "",.) %>%
              gsub("<ul class=links inline links-new-lines><li class=0 first last><a href=/incident/", "",.) %>%
              gsub("<ul class=links inline links-new-lines><li class=0 first><a href=/incident/","", .) %>%
              gsub(">View Incident</a></li>\n<li class=1 last><a href=", "<sep>",.) %>%
              gsub(">View Incident</a></li><li class=1 last><a ", "<sep>",.) %>%
              gsub(">View Incident</a></li></ul><sep> </tr>", "",.) %>%
              gsub("href=", "",.)
  
     return(x)
  }

htmltotable <- function(file) {
                                table <-  read_html(file) %>% html_nodes(css='tr') %>% .[-1] %>% 
                                          decluttertable(.) %>% as.data.table %>% 
                                          separate(".", colnm, sep = "<sep>") 
                                
     return(table)
  }

readtables <- function(pages) {
  
              table <- lapply(pages, htmltotable) %>% rbindlist(.)
            
              if (grepl("no incidents available.", toString(table$date[1]))) {
                    table <- data.table(date=character(), state=character(), location=character(),
                                    address=character(), killed=character(), injured=character(),
                                    incidentno=character(), source=character(), stringsAsFactors=FALSE)
                    missinglog <- c(missinglog, paste0(date," contains no gun-related incidents."))
                 }
            
     return(table)
  }

crawling   <- function(mmddyyyy) {
            # daily search 
            remDr %>% go("http://www.gunviolencearchive.org/query")
            webElem <- remDr %>% findElement(using = "css selector", ".filter-dropdown-trigger") %>%
              elementClick #Add a rule...
            webElem <- remDr %>% findElement(using = "link text", "Date") %>%
              elementClick #Selecting Date refinement
            Sys.sleep(1)
            
            # date input
            datefrom <- remDr %>% findElement(using = "css selector", "input[id$='filter-field-date-from']") #Date from...
            dateto   <- remDr %>% findElement(using = "css selector", "input[id$='filter-field-date-to']")   #...Date to
            message(mmddyyyy)
            datescript <- paste0("arguments[0].value = \"", mmddyyyy, "\"; arguments[1].value = \"", mmddyyyy, "\";")

            remDr %>% executeScript(datescript, list(datefrom, dateto))
            
            remDr %>% findElement(using = "css selector", "#edit-actions-execute") %>%
              elementClick #Search
            Sys.sleep(1)
            
            # search results 
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
  
    return(pagelist)
}

#### 2. Scraping (note: requires Docker) ####

# In running RSelenium, the answer to this post was helpful:
# https://stackoverflow.com/questions/45395849/cant-execute-rsdriver-connection-refused

#### 2.0 Setup ####

system('docker pull selenium/standalone-chrome')
system('docker run -d -p 4445:4444 selenium/standalone-chrome')

remDr <- remoteDr(browserName = "chrome", port = 4445L)
remDr

#### 2.1 Loop ####

for (year_n in (2014:2018))  {

  for (month_n in (1:12)) {

    # Refresh the month and accumulation data.table
      dt_month <- data.table(date=character(), state=character(), location=character(),
                          address=character(), killed=character(), injured=character(),
                          incidentno=character(), source=character(), stringsAsFactors=FALSE)
      
      days     <- data.table(date=character(), state=character(), location=character(),
                           address=character(), killed=character(), injured=character(),
                           incidentno=character(), source=character(), stringsAsFactors=FALSE)
      
    for (day_n in (1:days_in_month(month_n))) {
      
      dt_day <- data.table(date=character(), state=character(), location=character(),
                           address=character(), killed=character(), injured=character(),
                           incidentno=character(), source=character(), stringsAsFactors=FALSE)
      
      mmddyyyy <- paste0(month_n, '/', day_n, '/', year_n)
      
        datevar <- ifelse(nchar(mmddyyyy)<10, format(as.Date(mmddyyyy,format="%m/%d/%Y")), mmddyyyy)
        if (anydate(datevar) == anytime(Sys.Date())) {
            halt <- TRUE
            break
          }
        
        pagelist <- crawling(mmddyyyy)
        table    <- readtables(pagelist) %>% as.data.table(.) 
        days     <- rbind.fill(days, table)
      } 

      dt_month <- dt_month %>% rbind.fill(.,days) %>% unique(.)
      filename <- paste0("m",month_n,"y",year_n)
      write.csv(dt_month, file = paste0(toString(year_n), '/', filename,".csv"))
      rm(dt_month)
      }
    if (halt){break}
  }

#### 3.0 Incident characteristics ####


source(incidentchars.R)