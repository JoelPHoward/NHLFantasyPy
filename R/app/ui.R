library(shiny)
library(shinycssloaders)
library(htmltidy)
library(shinythemes)

slider_css <- "
.irs-bar,
.irs-bar-edge,
.irs-single,
.irs-grid-pol {
  background: red;
  border-color: red;
}
"

ui <- navbarPage(
  theme = shinytheme('yeti'),
  "FANTASY HOCKEY",
  tabPanel(
    "Connect",
    sidebarPanel(
      h1("Connect to Yahoo:"),
      fluidRow(
        style = "padding: 10px 0px",
        actionButton("yahoo_code_btn", "Get authorization code to connect to Yahoo"),
        div(
          style = "overflow-x:scroll; max-height: 200px; background: white;",
          textOutput("yahoo_code_url")
        ),
        textInput("yahoo_code", "Enter code provided by Yahoo here"),
        actionButton("connect_to_yahoo_btn", label = "Connect to Yahoo"),
        textOutput("yahoo_con_success")
      )
    ),
    mainPanel(
      imageOutput("yahoo_logo")
    )
  ),
  tabPanel(
    "Player Trends",
    sidebarPanel(
      fluidRow(
        uiOutput("player_select_1"),
        uiOutput("vs_team"),
        radioButtons("by_time", label = "Show data by:", choices = c("Season", "Month", "Date"), selected = "Season"),
        div(
          tags$style(HTML(".js-irs-2 .irs-single, .js-irs-2 .irs-bar-edge, .js-irs-2 .irs-bar {background: green}")),
          uiOutput("between_time")
        ),
        actionButton("get_all_rostered_players", label = "Get all players on existing fantasy rosters")
      ),
      fluidRow(
        style='padding:10px;',
        column(width = 12,
          DT::dataTableOutput("all_rostered_players"),
          style = "overflow-y: scroll;overflow-x: scroll;"
        )
      ),
      fluidRow(
        uiOutput("which_season")
      )
    ),
    mainPanel(
      fluidRow(
        plotOutput("plot_t1", height = "700px")
      ),
      fluidRow(
        style='padding:10px;',
        column(width = 12,
          DT::dataTableOutput("table1_2"),
          style = "overflow-y: scroll;overflow-x: scroll;"
        )
      )
    )
  ),
  tabPanel(
    "Optimize Roster"
  ),
  tabPanel(
    "Player Classifier"
  ),
  tabPanel(
    "Team Summary",
    sidebarPanel(
      uiOutput("select_team"),
      uiOutput("select_date_range"),
      actionButton("get_summary", "Get Summary"),
      br(),
      checkboxGroupInput("filters", "Filters", choices = c("C", "LW", "RW", "D", "G"), selected = c("C", "LW", "RW", "D", "G"))
    ),
    mainPanel(
      plotOutput("team_summary_plot")
    )
  ),
  tabPanel(
    "Yahoo Endpoint Viewer",
    # modify css style here: /Library/Frameworks/R.framework/Versions/4.0/Resources/library/htmltidy/htmlwidgets/lib/xml-viewer
    fluidRow(
      column(
        width = 10,
        textInput("endpoint", "Enter Endpoint")
      ),
      column(
        width = 2,
        actionButton("try_endpoint", "Try Endpoint")
      )
    ),
    fluidRow(
      xmltreeviewOutput("xml")
    )
  )
)
