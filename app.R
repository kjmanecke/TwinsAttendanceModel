library(shiny)
library(tidyverse)
library(randomForest)

# load data and model
attendance_model_data <- readRDS("attendance_model_data.rds")
rf_model <- readRDS("rf_model.rds")

var_labels <- c(
  "month" = "Month",
  "day_of_week" = "Day of Week",
  "Temperature_F" = "Temperature (F)",
  "Twins_win_percentage" = "Twins Win Percentage",
  "Twins_podds" = "Twins Playoff Odds",
  "Opp_win_percentage" = "Opponent Win Percentage",
  "promo_flag" = "Promotion",
  "theme_flag" = "Theme Night"
)

ui <- fluidPage(
  titlePanel("Twins Attendance Predictor"),
  
  tabsetPanel(
    tabPanel("Attendance Predictor",
             h4("Enter game conditions below to predict attendance using a tuned random forest model."),
      sidebarLayout(
        sidebarPanel(
          selectInput("month", "Month", 
                      choices = c("April" = "Apr", "May" = "May", "June" = "Jun", 
                                  "July" = "Jul", "August" = "Aug", "September" = "Sep")),
          selectInput("day_of_week","Day Of Week",
                      choices = c("Sunday" = 1, "Monday" = 2, "Tuesday" = 3, "Wednesday" = 4, "Thursday" = 5, "Friday" = 6, "Saturday" = 7)),
          selectInput("opp_category", "Opponent Category",
                      choices = c("Divisional", "High Attendance" = "High_Attendance", "Other")),
          helpText("High Attendance: Red Sox, Yankees, Brewers, Phillies, Blue Jays, Cubs, Dodgers"),
          selectInput("promo_flag", "Promotion",
                      choices = c("Yes" = 1, "No" = 0)),
          selectInput("theme_flag", "Theme Night",
                      choices = c("Yes" = 1, "No" = 0)),
          selectInput("is_night_game", "Night Game",
                      choices = c("Yes" = 1, "No" = 0)),
          numericInput("Twins_win_percentage", "Twins Win Percentage", 
                       value = 0.500, min = 0, max = 1, step = 0.001),
          numericInput("Opp_win_percentage", "Opponent Win Percentage", 
                       value = 0.500, min = 0, max = 1, step = 0.001),
          numericInput("Twins_podds", "Twins Playoff Odds", 
                       value = 0.500, min = 0, max = 1, step = 0.001),
          actionButton("predict", "Predict Attendance")
        ),
        mainPanel(
          h3("Predicted Attendance"),
          textOutput("prediction"), 
          helpText("Predicted attendance is based on a tuned random forest model trained on 562 Twins home games from 2017-2025.")
        )
      )       
    ),
    
    tabPanel("Explore the Data",
             h4("Explore the relationship between attendance and key variables from the dataset."),
      sidebarLayout(
        sidebarPanel(
          selectInput("plot_type", "Plot Type", 
                      choices = c("Scatter Plot", "Box Plot")),
          selectInput("x_var", "X Variable",
                      choices = c("Month" = "month",
                                  "Day of Week" = "day_of_week",
                                  "Temperature" = "Temperature_F",
                                  "Twins Win Percentage" = "Twins_win_percentage",
                                  "Twins Playoff Odds" = "Twins_podds",
                                  "Opponent Win Percentage" = "Opp_win_percentage",
                                  "Promo Flag" = "promo_flag",
                                  "Theme Flag" = "theme_flag")),
          selectInput("color", "Color",
                      choices = c("None" = "none",
                                  "Month" = "month",
                                  "Day of Week" = "day_of_week",
                                  "Promo Flag" = "promo_flag",
                                  "Theme Flag" = "theme_flag",
                                  "Night Game" = "is_night_game")),
          conditionalPanel(
            condition = "input.plot_type == 'Scatter Plot'",
            checkboxInput("show_smooth", "Add Trend Line", value = FALSE)
          )
        ),
        mainPanel(
          plotOutput("eda_plot")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  observeEvent(input$predict, {
    
    new_data <- data.frame(
      month = factor(input$month, levels = c("Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct")),
      day_of_week = factor(input$day_of_week, levels = 1:7),
      opp_category = input$opp_category,
      promo_flag = as.numeric(input$promo_flag),
      theme_flag = as.numeric(input$theme_flag),
      is_night_game = as.numeric(input$is_night_game),
      Twins_win_percentage = input$Twins_win_percentage,
      Twins_podds = input$Twins_podds,
      Opp_win_percentage = input$Opp_win_percentage
    )
    
    prediction <- predict(rf_model, new_data)
    
    output$prediction <- renderText({
      paste("Predicted Attendance:", format(round(prediction), big.mark = ","))
    })
  })
  observeEvent(input$plot_type, {
    if(input$plot_type == "Box Plot") {
      updateSelectInput(session, "x_var",
                        choices = c("Month" = "month",
                                    "Day of Week" = "day_of_week",
                                    "Promo Flag" = "promo_flag",
                                    "Theme Flag" = "theme_flag",
                                    "Night Game" = "is_night_game"))
    } else {
      updateSelectInput(session, "x_var",
                        choices = c("Temperature" = "Temperature_F",
                                    "Twins Win Percentage" = "Twins_win_percentage",
                                    "Twins Playoff Odds" = "Twins_podds",
                                    "Opponent Win Percentage" = "Opp_win_percentage"))
    }
  })
  output$eda_plot <- renderPlot({
    
    plot_data <- attendance_model_data
    
    if (input$x_var == "Twins_win_percentage") {
      plot_data <- plot_data |> filter(Twins_Wins + Twins_Losses >= 10)
    } else if (input$x_var == "Opp_win_percentage") {
      plot_data <- plot_data |> filter(Opp_Wins + Opp_Losses >= 10)
    }
    
    p <- ggplot(plot_data, aes_string(x = input$x_var, y = "TotalPaidAttendance"))
    
    if(input$plot_type == "Scatter Plot") {
      p <- p + geom_point()
      if(input$show_smooth) {
        p <- p + geom_smooth(method = "loess", se = FALSE)
      }
    } else {
      p <- p + geom_boxplot()
    }
    
    if(input$color != "none") {
      p <- p + aes_string(color = input$color)
    }
    
    p + labs(x = var_labels[input$x_var], y = "Total Paid Attendance") + theme_minimal()
    
  })
}

shinyApp(ui = ui, server = server)
