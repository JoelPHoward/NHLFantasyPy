library(ggplot2)

setwd("~/Desktop/")

f <- gtools::mixedsort(list.files()[grep('team_[0-9]+_summary.csv', list.files())])

df_lst <- lapply(f, read.csv)

team_info <- read.csv("team_info.csv")

for(i in 1:length(df_lst)){
    colnames(df_lst[[i]])[1] <- "Week"
    df_lst[[i]]$Week <- as.character(1:15)
    
    df_lst[[i]]$fanpts_per_game <- df_lst[[i]]$fanpts/df_lst[[i]]$ngames
    df_lst[[i]]$benchpts_per_game <- ifelse(df_lst[[i]]$nbench == 0, 0, df_lst[[i]]$benchpts/df_lst[[i]]$nbench)
    df_lst[[i]]$fppg_to_bppg <- df_lst[[i]]$fanpts_per_game - df_lst[[i]]$benchpts_per_game
    df_lst[[i]] <- reshape2::melt(df_lst[[i]][,c(1,8)])
}
for(i in 1:length(df_lst)) df_lst[[i]]$team <- team_info$name[i]

names(df_lst) <- team_info$name

df <- do.call(rbind, df_lst)
df$Week <- factor(df$Week, levels = as.character(1:15))
ggplot(df, aes(x = Week)) +
    geom_bar(aes(y = value, fill = value), position = 'dodge', stat = "identity") +
    scale_fill_continuous(name = "fppg - bppg") +
    facet_wrap(~team)

