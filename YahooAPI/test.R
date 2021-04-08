library(shiny)
library(reticulate)
setwd("/Users/joelhoward/Documents/Fantasy_Hockey/YahooAPI")
use_virtualenv("/Users/joelhoward/.NHLFantasyPy")
yahoo <- import("yahoo_connect")

ui <- fluidPage(
  actionButton("get_code", label = "Get authorization code to connect to Yahoo"),
  textOutput("code_url"),
  textInput("code", "Enter code provided by Yahoo here"),
  actionButton("connect_to_yahoo", label = "Connect to Yahoo"),
  textOutput("connected"),
  actionButton("get_all_rostered_players", label = "Get all players on existing fantasy rosters"),
  tableOutput("all_rostered_players")
)

server <- function(input, output){
  con <- NULL
  link <- NULL
  observeEvent(input$get_code,{
    out <- yahoo$get_code()
    con <<- out[[1]]
    link <<- out[[2]]
    output$code_url <- renderText(link)
  })
  
  observeEvent(input$connect_to_yahoo,{
    con <<- yahoo$connect_to_yahoo(con = con, code = input$code, authorization_url = link)
    output$connected <- renderText(con$authorized)
  })
  
  observeEvent(input$get_all_rostered_players,{
    output$all_rostered_players <- renderTable(yahoo$get_all_rostered_players(con = con, team_ids = yahoo$get_teams(con)$id))
  })
  
}

shinyApp(ui, server)