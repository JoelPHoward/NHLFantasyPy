library(reticulate)
library(odbc)
library(XML)
library(parallel)
library(rjson)

pos_to_vec <- function(pos){
    (c("C","LW","RW","D","Util","G") %in% pos) * 1
}

team_summary <- function(yahoo, db_con, team_info, team, start_date, end_date = NULL){
    
	## get all dates in psql DB between start and end dates. If end_date is NULL, get all dates after start_date
	dates <- sort(odbc::dbGetQuery(conn = db_con, statement = paste0("SELECT DISTINCT date FROM game_logs WHERE date >= '", start_date, ifelse(is.null(end_date), "'", paste0("' AND date <= '", end_date, "'")), ";"))[, 1, drop=TRUE])

	## get players on chosen team's roster for each date
	my_players <- data.frame()
	for(date in as.character(dates)){
		players <- xmlToList(yahoo$endpoint_xml(endpoint = paste0("https://fantasysports.yahooapis.com/fantasy/v2/team/nhl.l.17580.t.",team,"/roster;date=",date)))$team$roster$players
		my_players <- rbind(my_players, do.call(rbind, lapply(players[1:(length(players) - 1)], function(player){
			pos <- pos_to_vec(strsplit(player$display_position, ",")[[1]])
			c(
				date = date, 
				name = player$name$full, 
				team = player$editorial_team_full_name, 
				C_pos = pos[1],
				LW_pos = pos[2],
				RW_pos = pos[3],
				D_pos = pos[4],
				G_pos = pos[6],
				selected_position = player$selected_position$position
			)
		})))
	}
	for(i in 4:8){
	    my_players[,i] <- as.numeric(my_players[,i])
	}

	## filter for players who played on given dates and add fanpts
	my_players_2 <- data.frame()
	for(player in unique(my_players$name)){
		## subset for current player
		tmp <- my_players[which(my_players$name == player),]

		## get fanpts for current player from games played in date range
		x <- odbc::dbGetQuery(conn = db_con, statement = paste0(
			"SELECT
			game_logs.date,
			game_logs.fanpts,
			player_info.name,
			game_logs.team_id
			FROM game_logs JOIN player_info
			ON game_logs.player_id = player_info.player_id
			WHERE LOWER(player_info.name) = '", tolower(player), "' AND game_logs.date >= '", start_date,"'
			ORDER BY date;"
			))
		x$team_name <- team_info$name[unlist(lapply(paste0("^", x$team_id, "$"), grep, team_info$team_id))]

		## remove rows on dates that player didn't play
		shared_dates <- intersect(tmp$date, as.character(x$date))
		tmp <- tmp[which(tmp$date %in% shared_dates),]
		tmp$fanpts <- x$fanpts[which(as.character(x$date) %in% shared_dates)]

		my_players_2 <- rbind(my_players_2, tmp)
	}
	
	return(my_players_2)
}











