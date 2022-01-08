library(rjson)

a = list()
for(i in 0:79){
    print(i)
    a[[i+1]] <- rjson::fromJSON(file = paste0('https://api.nhle.com/stats/rest/en/skater/summary?isAggregate=true&isGame=false&sort=%5B%7B%22property%22:%22points%22,%22direction%22:%22DESC%22%7D,%7B%22property%22:%22goals%22,%22direction%22:%22DESC%22%7D,%7B%22property%22:%22assists%22,%22direction%22:%22DESC%22%7D,%7B%22property%22:%22playerId%22,%22direction%22:%22ASC%22%7D%5D&start=',(i*100)+1,'&limit=100&factCayenneExp=gamesPlayed%3E=1&cayenneExp=gameTypeId=2%20and%20seasonId%3C=20212022%20and%20seasonId%3E=19171918'))$data
}

player_ids = NULL
player_names = NULL
for(i in 1:length(a)){
    if(length(a[[i]])>0){
        for(j in 1:length(a[[i]])){
            player_ids = c(player_ids, a[[i]][[j]]$playerId)
            player_names = c(player_names, a[[i]][[j]]$skaterFullName)
        }
    }
}
write.csv(data.frame(player_id = player_ids, name = player_names), '~/repos/NHLFantasyPy/data/historical_player_ids.csv', row.names = F)