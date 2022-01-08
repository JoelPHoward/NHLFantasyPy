library(reticulate)
library(rjson)
library(XML)
library(progress)
library(shiny)

setwd("~/repos/NHLFantasyPy/")

pos_to_vec <- function(pos){
    (c("C","LW","RW","D","Util","G") %in% pos) * 1
}

draft_df <- read.csv('draft_results_2021_01_13_2021_04_11_pos.csv', row.names = 1)

ui <- fluidPage(
    sidebarPanel(
        selectInput('xaxis', "x-axis", choices = colnames(draft_df), selected = 'fanpts'),
        selectInput('yaxis', "y-axis", choices = colnames(draft_df), selected = 'player_name'),
        selectInput('fill', "Color By", choices = colnames(draft_df), selected = 'fanpts'),
        selectInput('order', "Order By", choices = colnames(draft_df), selected = 'pick'),
        checkboxGroupInput("filters", "Filters", choices = c("C", "LW", "RW", "D", "G"), selected = c("C", "LW", "RW", "D", "G"))
    ),
    mainPanel(
        plotOutput("plot", height = '2000px')
    )
)

server <- function(input, output, session){
    output$plot <- renderPlot({
        req(input$filters, input$xaxis, input$yaxis, input$fill, input$order)
        sel_pos <- pos_to_vec(input$filters)[-5]
        filt_df <- draft_df[which(rowSums(sweep(draft_df[,8:12], 2, sel_pos, "+") > 1) > 0),]
        filt_df[[input$yaxis]] <- factor(filt_df[[input$yaxis]], levels = unique(filt_df[[input$yaxis]][order(filt_df[[input$order]])]))
        ggplot(filt_df, aes_string(x = input$xaxis, y = input$yaxis)) + 
            geom_bar(aes_string(fill = input$fill), stat = 'identity') +
            #scale_fill_gradient(low = "lightgrey", high = "purple") +
            theme_base() + 
            theme(plot.background = element_blank(), text = element_text(size = 10))
    })
}

shinyApp(ui, server)

# 
# YAHOO_CREDENTIALS <- fromJSON(file = "~/repos/NHLFantasyPy/YAHOO_CREDENTIALS.json")
# 
# yahoo_connect <- import("YahooAPI.yahoo_connect")
# ET <- import("xml.etree.ElementTree")
# 
# yahoo <- yahoo_connect$YahooCon(access_token = YAHOO_CREDENTIALS$access_token, refresh_token =  YAHOO_CREDENTIALS$refresh_token, client_id = YAHOO_CREDENTIALS$client_id, client_secret = YAHOO_CREDENTIALS$client_secret, league_id = YAHOO_CREDENTIALS$league_id)
# 
# draft_df <- read.csv("draft_results_2021_01_13_2021_04_11.csv", row.names = 1)
# 
# pos_df <- data.frame()
# pg <- progress::progress_bar$new(total = nrow(draft_df))
# for(i in 1:nrow(draft_df)){
#     pg$tick()
#     positions <- xmlToList(xmlParse(yahoo$endpoint_xml(paste0('https://fantasysports.yahooapis.com/fantasy/v2/player/', draft_df$player_key[i]))))$player$eligible_positions
#     pos_vec <- pos_to_vec(unlist(positions))[-5]
#     pos_df <- rbind(pos_df, pos_vec)
# }
# colnames(pos_df) <- paste0(c("C","LW","RW","D","G"), "_pos")
# 
# draft_df <- cbind(draft_df, pos_df)
# draft_df <- draft_df[,c(1:7, 9:13, 8)]
# 
# write.csv(draft_df, 'draft_results_2021_01_13_2021_04_11_pos.csv')




