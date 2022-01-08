suppressWarnings(library(odbc))
suppressWarnings(library(reticulate))
suppressWarnings(library(XML))
suppressWarnings(library(rjson))

PSQL_CREDENTIALS = fromJSON(file = "~/repos/NHLFantasyPy/PSQL_CREDENTIALS.json")
YAHOO_CREDENTIALS = fromJSON(file = "~/repos/NHLFantasyPy/YAHOO_CREDENTIALS.json")

db_con <- DBI::dbConnect(odbc::odbc(),
                         Driver   = "/usr/local/lib/psqlodbcw.so",
                         Database = PSQL_CREDENTIALS$dbname,
                         UID      = PSQL_CREDENTIALS$user,
                         PWD      = PSQL_CREDENTIALS$password,
                         Port     = 5432)

setwd("~/repos/NHLFantasyPy/")
source_python("get_best_roster.py")

yahoo_connect <- import("YahooAPI.yahoo_connect")

yahoo <- yahoo_connect$YahooCon(access_token = YAHOO_CREDENTIALS$access_token, refresh_token =  YAHOO_CREDENTIALS$refresh_token, client_id = YAHOO_CREDENTIALS$client_id, client_secret = YAHOO_CREDENTIALS$client_secret, league_id = YAHOO_CREDENTIALS$league_id)
message(yahoo$authorization_url)

cat("Enter yahoo code: ");
code = readLines("stdin", n = 1);
yahoo$connect_to_yahoo(code = code)

cat("Enter date (YYYY-MM-DD): ");
date = readLines("stdin", n = 1);

top_players <- dbGetQuery(
    conn = db_con, 
    statement = paste0(
        "SELECT game_logs.player_id,
        player_info.name,
        game_logs.fanpts
        FROM game_logs JOIN player_info
        ON game_logs.player_id = player_info.player_id
        WHERE game_logs.date ='", date, "' AND game_logs.fanpts > 0 ORDER BY game_logs.fanpts DESC;"
    ))

dbDisconnect(db_con)

quotas <- c(C = 2, LW = 2, RW = 2, D = 4, Util = 2, G = 2)
filled_pos <- rep(0,6)

pos_to_vec <- function(pos){
    (c("C","LW","RW","D","Util","G") %in% pos) * 1
}

A <- list()
B <- list()
for(i in 1:nrow(top_players)){
    # Get eligible positions
    name <- top_players$name[i]
    if(grepl("'", name)){
        spl <- strsplit(name, split = "'")[[1]]
        a <- length(strsplit(spl[1], "")[[1]])
        b <- length(strsplit(spl[2], "")[[1]])
        if(a > b){
            name <- spl[1]
        }else{
            name <- spl[2]
        }
    }
    yahoo_pos <- unlist(xmlToList(xmlParse(yahoo$endpoint_xml(endpoint = paste0("https://fantasysports.yahooapis.com/fantasy/v2/league/nhl.l.", YAHOO_CREDENTIALS$league_id, "/players;search=", name))))$league$players$player$eligible_positions)
    pos_vec <- pos_to_vec(yahoo_pos)
    
    if(pos_vec[5] == 1){
        if(all(filled_pos[which(pos_vec==1)] >= quotas[which(pos_vec==1)]) & filled_pos[5] >= 12){
            cat(top_players$name[i], ": ", yahoo_pos, " (", pos_vec,") - ",top_players$fanpts[i], " Skipping...\n")
            next
        }
    }else{
        if(filled_pos[6] >= 2){
            cat(top_players$name[i], ": ", yahoo_pos, " (", pos_vec,") - ",top_players$fanpts[i], " Skipping...\n")
            next
        }
    }
    
    cat(top_players$name[i], ": ", yahoo_pos, " (", pos_vec,") - ",top_players$fanpts[i], "\n")
    A[[i]] <- pos_vec
    B[[i]] <- top_players$fanpts[i]
    filled_pos <- filled_pos + pos_vec
    if(all(filled_pos >= quotas)){
        break
    }
}
players <- cbind(do.call(rbind, A), unlist(B))

players_lst <- list()
for(i in 1:nrow(players)){
    players_lst[[i]] <- list(idx = i, pos = players[i,1:6,drop=T], pts = players[i,7,drop=T])
}


forwards <- filter_players(players_lst, c(1,1,1,0,0,0))
defence <- filter_players(players_lst, c(0,0,0,1,0,0))
goalies <- filter_players(players_lst, c(0,0,0,0,0,1))

#cat(paste0("Number of forwards: ", length(forwards), "\n"))
#cat(paste0("Number of defence: ",  length(defence), "\n"))
#cat(paste0("Number of goalies: ",  length(goalies), "\n"))

forward_sols = list()
defence_sols = list()
# Loop through number of utils 0,1,2
for(num_util in 1:3){
    #cat(paste0("Forwards: ", num_util-1, "\n"))
    forward_sols[[num_util]] <- choose_roster(list(), c(2,2,2,0,num_util-1,0), forwards)
    #cat(paste0("Defence: ", num_util-1, "\n"))
    defence_sols[[num_util]] <- choose_roster(list(), c(0,0,0,4,num_util-1,0), defence)
}
goalie_sols = choose_roster(list(), c(0,0,0,0,0,2), goalies)

best_team <- NULL
max_pts <- 0
for(num_util in 1:3){
    #print(paste0("Forward util positions: ", num_util-1, "  -  Defence util positions: ", 3-num_util))
    forward_choice = forward_sols[[num_util]]
    defence_choice = defence_sols[[4-num_util]]
    
    tot_pts <- forward_choice[[1]]+defence_choice[[1]]+goalie_sols[[1]]
    team <- c(forward_choice[[2]], defence_choice[[2]], goalie_sols[[2]])
    #cat(paste0("    Forward Points: ", forward_choice[[1]], "\n"))
    #cat(paste0("    Defence Points: ", defence_choice[[1]], "\n"))
    #cat(paste0("    Goalie  Points: ", goalie_sols[[1]], "\n"))
    #cat(paste0("    Total Points: ", tot_pts, "\n"))
    #cat(paste0("    Player Choices: ", paste(team, collapse = ","), "\n"))
    
    if(tot_pts > max_pts){
        max_pts <- tot_pts
        best_team <- team
    }
}

df <- top_players[best_team,2:3]
df <- rbind(df[order(df[,2], decreasing = TRUE),], c("TOTAL", max_pts))
colnames(df) <- c("Player", "FanPts")
rownames(df) <- NULL
cat(paste0("\nBest Roster from ", date, ":\n"))
print(df)
