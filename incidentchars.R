# Adding incident characteristics.

#### 0. Preamble ####

if (!require("pacman")) install.packages("pacman")
pacman::p_load('rvest', 'RSelenium', 'tidyr', 'plyr', 'data.table', 'lubridate', 'anytime', 'httr', 'robotstxt')

if (Sys.getenv("HOME") == "/Users/gforte") {
  setwd(paste0(Sys.getenv("HOME"),'/Dropbox/git/GunViolenceArchiveR'))
} else {
  setwd(dirname(file.choose()))
}

missinginc <- c() #Logs eventual incidents without dedicated page.

#### 0.1 Functions ####

declutter <- 
  function(x) {
    
    x %>% gsub("<div>|</div>", "", .) %>% gsub("</span>|<span>", "",.) %>% gsub("<p>|</p>", "", .) %>%
    gsub("\n|<br>", " ", .) %>% gsub("<ul> <li>|</li> </ul>", "", .) %>%  gsub("<br>", "", .) %>% 
    trimws(.) %>% gsub("</li> <li>", " | ", .) %>% gsub("<h2>", "", .) %>% unique(.) %>%
    gsub(".*Geolocation: ","Geoloc</h2> ",.) %>% .[!grepl("href=", .)] %>% .[grepl("</h2>", .)]
    
  }

getCharacteristics <- 
  function(incident, inclist) {

    cat("row ", which(grepl(incident, inclist)), "/", length(inclist), ":", incident, "\n")
  
    result <- try({
                    url    <- paste0("https://www.gunviolencearchive.org/incident/", incident) %>% 
                              read_html() %>% html_nodes(css='#block-system-main div') %>% declutter(.) %>%
                              strsplit(., "</h2> ")})

    if (!grepl('HTTP error 404', result)) {
    ifelse(any(grepl("Geoloc", url)),       geoloc <- url[[which(grepl("Geoloc", url))[1]]][2], geoloc <- NA)
    ifelse(any(grepl("Participants", url)), parts  <- url[[which(grepl("Participants", url))[1]]][2] %>% trimws(.), parts <- NA)
    ifelse(any(grepl("Incident Cha", url)), chars  <- url[[which(grepl("Incident Cha", url))]][2], chars <- NA)
    ifelse(any(grepl("Guns Involved", url)),guns   <- url[[which(grepl("Guns Involved", url))]][2], guns <- NA)
    ifelse(any(grepl("Notes", url)),        notes  <- url[[which(grepl("Notes", url))]][2], notes <- NA)
    ifelse(any(grepl("District", url)),     dstrt  <- url[[which(grepl("District:", url))]][2], dstrt <- NA)
    
    allch <- data.table(incidentno = incident, geolocation = geoloc, participants = parts,
                        characteristics = chars, guns = guns, notes = notes, district = dstrt)
    
    } else {
    allch <- dt_inc <- data.table(incidentno=double(), geolocation=character(), participants=character(),
                                        characteristics=character(), guns=character(), notes=character(), 
                                        district=character(), stringsAsFactors=FALSE)
    
    missinginc <- paste0(incident, " lacks a dedicated webpage.")
    write(missinginc, file="missinginc.txt")
    }
    return(allch)
  }

giveCharacteristics <- function(csvfile) {
    
    dt_inc <- data.table(incidentno=double(), geolocation=character(), participants=character(),
                         characteristics=character(), guns=character(), notes=character(), 
                         district=character(), stringsAsFactors=FALSE)
    dayincidents <- dt_inc
    data <- read.csv(csvfile) %>% subset(., select = -X)

    for (item in data$incidentno[1:10]) {
      allch <- getCharacteristics(item, data$incidentno)
      dayincidents <- rbind.fill(allch, dayincidents)
    }
    
  
    data <- merge(dayincidents, data, by = 'incidentno', all = T)
    write.csv(data, file = csvfile)
    message("file saved: ", csvfile)
  }

#### 1. Execute ####

filelist <- lapply((2014:2018), function(x) {paste0(x, '/', list.files(paste0(x, '/')))}) %>% unlist(.) #%>% .[2:length(.)]

robotstxt::robotstxt('https://www.gunviolencearchive.org/incident/')

for (file in filelist) giveCharacteristics(file)
      
