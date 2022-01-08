
weeks <- list(week1 = c('2021-01-13', '2021-01-24'))

week_start = seq(from = as.Date('2021-01-25'), to = as.Date('2021-04-26'), by = 'week')
week_end = seq(from = as.Date('2021-01-31'), to = as.Date('2021-05-2'), by = "week")
for(i in 1:length(week_start)){
	weeks[[paste0('week',i+1)]] <- c(week_start[i], week_end[i])
}

start_date = '2021-01-13'
end_date = NULL
team = 1
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

	player_name = tolower(player)
	if(grepl("'", player_name)){
		player_name <- sub("'", "''", player_name)
	}
	if(grepl("sebastian aho", player_name)){
		print(0)
		## get fanpts for current player from games played in date range
		x <- odbc::dbGetQuery(conn = db_con, statement = paste0(
			"SELECT
			game_logs.date,
			game_logs.fanpts,
			player_info.name,
			game_logs.team_id
			FROM game_logs JOIN player_info
			ON game_logs.player_id = player_info.player_id
			WHERE LOWER(player_info.name) = '", player_name, "' AND game_logs.date >= '", start_date,"' AND player_info.team_name = 'Carolina Hurricanes'
			ORDER BY date;"
			))

	}else{
		print(1)
		## get fanpts for current player from games played in date range
		x <- odbc::dbGetQuery(conn = db_con, statement = paste0(
			"SELECT
			game_logs.date,
			game_logs.fanpts,
			player_info.name,
			game_logs.team_id
			FROM game_logs JOIN player_info
			ON game_logs.player_id = player_info.player_id
			WHERE LOWER(player_info.name) = '", player_name, "' AND game_logs.date >= '", start_date,"'
			ORDER BY date;"
			))
	}
	x$team_name <- team_info$name[unlist(lapply(paste0("^", x$team_id, "$"), grep, team_info$team_id))]

	## remove rows on dates that player didn't play
	shared_dates <- intersect(tmp$date, as.character(x$date))
	tmp <- tmp[which(tmp$date %in% shared_dates),]
	tmp$fanpts <- x$fanpts[which(as.character(x$date) %in% shared_dates)]

	my_players_2 <- rbind(my_players_2, tmp)
}
df <- my_players_2

df2 <- do.call(rbind, lapply(weeks, function(week){
	tmp <- df[which(df$date >= week[1] & df$date <= week[2]),]
	if(any(tmp$selected_position %in% c("BN", "IR+"))){
		x <- c(ngames = nrow(tmp[-which(tmp$selected_position %in% c("BN", "IR+")),]), fanpts = sum(tmp$fanpts[-which(tmp$selected_position %in% c("BN", "IR+"))]))
	}else{
		x <- c(ngames = nrow(tmp), fanpts = sum(tmp$fanpts))
	}
	c(x, nbench = nrow(tmp[which(tmp$selected_position == "BN"),]), benchpts = sum(tmp$fanpts[which(tmp$selected_position == "BN")]))
}))

write.csv(df2, "~/Desktop/team_1_summary.csv")


