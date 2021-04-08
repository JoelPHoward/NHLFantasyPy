library(shiny)
library(odbc)
library(reticulate)
library(ggplot2)
library(ggthemes)
library(grid)
library(magick)
library(gtable)
library(DT)
library(htmltidy)
library(xml2)
library(dplyr)

setwd("~/repos/NHLFantasyPy/")
yahoo_connect <- import("YahooAPI.yahoo_connect")

PSQL_CREDENTIALS = fromJSON(file = "~/repos/NHLFantasyPy/PSQL_CREDENTIALS.json")

db_con <- DBI::dbConnect(odbc::odbc(),
                         Driver   = "/usr/local/lib/psqlodbcw.so",
                         Database = PSQL_CREDENTIALS$dbname,
                         UID      = PSQL_CREDENTIALS$user,
                         PWD      = PSQL_CREDENTIALS$password,
                         Port     = 5432)

server <- function(input, output, session){
  
  session$onSessionEnded(function() {
    try(dbDisconnect(conn = db_con))
    stopApp()
  })
  
  rvals <- reactiveValues()
  rvals$yahoo <- NULL
  rvals$yahoo_link <- NULL
  rvals$data_df <- NULL
  
  output$yahoo_logo <- renderImage({
    list(src = "~/repos/NHLFantasyPy/R/app/www/yahoo.png", alt = paste("Image number", input$n))
  }, deleteFile=FALSE)
  
  #--------------------------Connect to Yahoo-----------------------#
  observeEvent(input$yahoo_code_btn, { 
    rvals$yahoo <- yahoo_connect$YahooCon()
    output$yahoo_code_url <- renderText(rvals$yahoo$authorization_url)
  })
  
  observeEvent(input$connect_to_yahoo_btn, {
    rvals$yahoo$connect_to_yahoo(code = input$yahoo_code)
    if(rvals$yahoo$con$authorized){
      success <- "Successful connection to Yahoo."
    }else{
      success <- "Connection to Yahoo not successful."
    }
    output$yahoo_con_success <- renderText(success)
  })
  
  observeEvent(input$get_all_rostered_players, ignoreNULL = FALSE, {
    req(rvals$yahoo)
    output$all_rostered_players <- DT::renderDataTable(rvals$yahoo$get_all_rostered_players()[,c(2,3,4,5,8)])
  })
  #--------------------------------------------------------------------#
  
  output$player_select_1 <- renderUI({
    players <- dbGetQuery(conn = db_con, statement = paste0("SELECT name FROM player_info;"))[,1,drop=TRUE]
    selectInput("player_select_1", "Select a Player", choices = players, selected = sample(players, 1), multiple = TRUE)
  })
  output$vs_team <- renderUI({
    selectInput("vs_team", "Versus", choices = c("All Teams", dbGetQuery(conn = db_con, statement = paste0("SELECT name FROM team_info;"))[,1,drop=TRUE]), selected = "All Teams", multiple = FALSE)
  })
  
  
  get_player_data <- function(players){
    id <- dbGetQuery(conn = db_con, statement = paste0("SELECT player_id FROM player_info WHERE ", sub(" OR$", "", paste("name =", sQuote(players, "'"), "OR", collapse = " ")), ";"))[,1,drop=TRUE]
    df <- dbGetQuery(conn = db_con, statement = paste0(
      "SELECT game_logs.split, 
      game_logs.date, 
      game_logs.player_id, 
      player_info.name, 
      player_info.position, 
      player_info.team_id, 
      player_info.team_name, 
      game_logs.opp_id, 
      game_logs.fanpts, 
      player_info.name || ' - ' || player_info.position || ' - ' || player_info.status AS label 
      FROM game_logs JOIN player_info
      ON game_logs.player_id = player_info.player_id 
      WHERE ", sub(" OR$", "", paste("game_logs.player_id =", id, "OR", collapse = " ")), ";"
    ))
    df$month <- gsub("-","",stringr::str_match(df$date, "-..-")[,1])
    return(df)
  }
  
  observeEvent(input$player_select_1, {
    if(all(!is.null(input$player_select_1))){
      to_update <- input$player_select_1[which(input$player_select_1 %in% names(rvals$data_df) == FALSE)]
      if(!is.null(rvals$data_df)){
        keep <- rvals$data_df[which(names(rvals$data_df) %in% input$player_select_1),]
      }else{
        keep <- NULL
      }
      add <- get_player_data(to_update)
      rvals$data_df <- rbind(keep, add)
    }else{
      rvals$data_df <- NULL
    }
  })
  
  output$between_time <- renderUI({
    req(rvals$data_df)
    sliderInput("between_time", label = "Between:", min = min(rvals$data_df$date), max = max(rvals$data_df$date), value = c(min(rvals$data_df$date), max(rvals$data_df$date)))
  })
  
  output$plot_t1 <- renderPlot({
    req(input$between_time)
    if(is.null(rvals$data_df)){
      return(NULL)
    }
    if(length(input$player_select_1) == 0){
      return(NULL)
    }
    df <- rvals$data_df[which(rvals$data_df$date>=input$between_time[1] & rvals$data_df$date<=input$between_time[2]),]
    if(input$vs_team != "All Teams"){
      df <- df[which(df$opp_id == input$vs_team),]
      if(nrow(df) == 0){
        showModal(modalDialog(p("No Data found that matches specified filters"), title = "Warning"), session = getDefaultReactiveDomain())
        return(NULL)
      }
    }
    players_in_data <- input$player_select_1[which(input$player_select_1%in%unique(df$name))]
    df$name <- factor(df$name, levels = players_in_data)
    df$label <- factor(df$label, levels = df$label[match(levels(df$name), sub(" -.*","",df$label))])
    df$split <- factor(df$split, levels = sort(unique(df$split)))
    if(input$by_time == "Season"){
      p <- ggplot(df, aes(x = split, y = fanpts)) + 
        geom_boxplot(colour = "red", fill = "white", outlier.shape = NA) +
        geom_jitter(colour = "black", alpha = 0.5)
    }else if(input$by_time == "Month"){
      p <- ggplot(df, aes(x = month, y = fanpts)) + 
        geom_boxplot(colour = "red", fill = "white", outlier.shape = NA) +
        geom_jitter(colour = "black", alpha = 0.5)
    }else{
     p <- ggplot(df, aes(x = date, y = fanpts)) +
        geom_point(aes(color = fanpts), alpha = 0.3) + 
        geom_line(aes(color = fanpts))
    }
    p <- p + 
      facet_wrap(~label, ncol = 3) +
      geom_hline(yintercept = 5) + 
      scale_shape_identity() + 
      theme_base() +
      theme(strip.background = element_rect(colour="black", fill="white", size = 1), 
            strip.text = element_text(size= ifelse(length(unique(df$label))==1,20,15)), 
            plot.background = element_blank(),
            axis.text.x = element_text(angle = 45, hjust = 1))
    
    g <- ggplot_gtable(ggplot_build(p))
  
    logos <- unlist(lapply(unique(as.character(df$name))[match(players_in_data, as.character(unique(df$name)))], function(x){
      image_read(paste0("~/repos/NHLFantasyPy/R/app/www/team_logos/",df$team_id[which(df$name == x)][1],".gif"))
    }))
    
    n_plots <- length(unique(df$player_id))
    strips <- grep("strip", g$layout$name)
    names(strips) <- g$layout$name[strips]
    strip_order <- c("strip-t-1-1", "strip-t-2-1", "strip-t-3-1")
    if(n_plots>3){
      n_row <- ceiling(n_plots / 3)
      for(i in 1:(n_row-1)){
        strip_order <- c(strip_order, paste0("strip-t-", 1:3, "-", i+1))
      }
      strips <- strips[match(strip_order, names(strips))]
    }
    
    new_grobs <- lapply(logos, function(x){
      rasterGrob(x, x = 0.1, height=0.7)
    })
    
    g <- with(g$layout[strips[1:n_plots],], gtable_add_grob(g, new_grobs, t=t, l=l, b=b, r=r, name="strip_logos"))      
    grid.draw(g)
  })

  output$which_season <- renderUI({
    choices <- dbGetQuery(conn = db_con, statement = "SELECT DISTINCT split FROM game_logs;")[,1,drop=TRUE]
    selectInput("which_season", "Select a season", choices = sort(choices), selected = max(choices), multiple = FALSE)
  })

  observeEvent(input$which_season, {
    df <- dbGetQuery(
      conn = db_con,
      statement = paste0(
        "SELECT game_logs.player_id,
        (SELECT player_info.name
        FROM player_info
        WHERE player_info.player_id = game_logs.player_id),
        ROUND(CAST(AVG(game_logs.fanpts) AS NUMERIC), 3) AS average, 
        ROUND(CAST(STDDEV(game_logs.fanpts) AS NUMERIC), 3) AS stdev, 
        ROUND(CAST(SUM(game_logs.fanpts) AS NUMERIC), 3) AS total
        FROM game_logs
        WHERE game_logs.split = ", input$which_season, "
        GROUP BY game_logs.player_id;"
      )
    ) %>% arrange(desc(total))
    output$table1_2 <- DT::renderDataTable(df)
  })

  #------- custom endpoint explorer -------#
  observeEvent(input$try_endpoint, {
    req(rvals$yahoo, input$endpoint)
    endpoint <- isolate(input$endpoint)
    if(rvals$yahoo$con$authorized){
      output$xml <- renderXmltreeview(xml_tree_view(doc = XML::xmlParse(rvals$yahoo$endpoint_xml(endpoint = endpoint)), mode = "modern"))
    }else{
      print('Not authorized. Reconnect.')
    }
  })
}


