#Lista de paquetes necesarios
packages = c("tidyverse",
             "shiny",
             "data.table",
             "shinydashboard",
             "zoo")

#Función que instala los paquetes si no están instalados y los carga
package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
      install.packages(x, dependencies = TRUE)
      library(x, character.only = TRUE)
    }
  }
)
search()

#Unimos todos los CSVs en un único dataframe
filenames = list.files(path = "data/", full.names = TRUE)
coins <- rbindlist(lapply(filenames, fread))

#Eliminamos de columna SNo
coins <- coins[, -1]

#Almacenamos los nombres de las criptomonedas y sus símbolos
names_coins <- as.vector(coins$Name[!duplicated(coins$Name)])
symbols_coins <- as.vector(coins$Symbol[!duplicated(coins$Symbol)])

#Juntamos los nombres con sus símbolos (Ejemplo: Aave (AAVE))
symbols_and_names <- str_c(names_coins, " (", symbols_coins, ")")

#Interfaz gráfica
ui <- dashboardPage(
  dashboardHeader(title = "UPOCoin"),
  dashboardSidebar(sidebarMenu(
    menuItem(
      "Visualización",
      tabName = "dashboard",
      icon = icon("chart-line")
    ),
    menuItem(
      "Predicciones",
      tabName = "predicts",
      icon = icon("search-dollar")
    ),
    menuItem(
      "Agrupamientos",
      tabName = "groups",
      icon = icon("object-group")
    )
  )),
  
  dashboardBody(tabItems(
    #Primera pestaña
    tabItem(tabName = "dashboard",
            fluidRow(
              box(
                width = 9,
                #Selector de columnas/atributos:
                selectInput(
                  inputId = "column",
                  label = "Selecciona un atributo:",
                  #Solo seleccionamos las columnas High, Low, Open, Close, Volume y Marketcap
                  choices = names(coins)[4:9],
                  #Por defecto seleccionada la columna Close
                  selected = names(coins)[7]
                ),
                #Gráfica
                plotOutput("plot1")
              ),
              box(
                width = 3,
                title = "Criptomonedas",
                #Checkbox múltiple para seleccionar la/s criptomoneda/s
                checkboxGroupInput(
                  inputId = "coins",
                  label = "Selecciona la/s criptomoneda/s:",
                  choiceValues = names_coins,
                  choiceNames = symbols_and_names,
                  #Por defecto seleccionada Bitcoin
                  selected = names_coins[3]
                )
              )
            )),
    
    #Segunda pestaña
    tabItem(tabName = "predicts",
            fluidRow(
              h2("Pestaña de predicciones"),
              box(
                width = 9,
                #Gráfica
                plotOutput("plotPredict"),
                htmlOutput("prediccion"),
                verbatimTextOutput("summary", placeholder = FALSE)
              ),
              
              box(
                width = 3,
                title = "Criptomonedas",
                #Checkbox múltiple para seleccionar la/s criptomoneda/s
                radioButtons(
                  inputId = "coinsPredict",
                  label = "Selecciona la/s criptomoneda/s:",
                  choiceValues = names_coins,
                  choiceNames = symbols_and_names,
                  #Por defecto seleccionada Bitcoin
                  selected = names_coins[3]
                ),
                #Selector de columnas/atributos:
                selectInput(
                  inputId = "columnPredict",
                  label = "Selecciona un atributo:",
                  #Solo seleccionamos las columnas High, Low, Open, Close, Volume y Marketcap
                  choices = names(coins)[4:9],
                  #Por defecto seleccionada la columna Close
                  selected = names(coins)[7]
                ),
                #Slider con el numero de días para el aprendizaje:
                sliderInput(
                  "sliderLearner",
                  "1.Introduce el número de días para el aprendizaje",
                  min = 5,
                  max = 90,
                  value = 14
                ),
                #Slider con el numero de dias para la prediccion:
                sliderInput(
                  "sliderPredictor",
                  "1.introduce el número de días de predicción",
                  min = 1,
                  max = 5,
                  value = 1
                ),
                #Botón para lanzar la predicción:
                actionButton("executePredict", "Predecir")
              )
            )),
    #Tercera pestana
    tabItem(tabName = "groups",
            fluidRow(
              h2("Agrupamientos"),
              box(
                width = 9,
                #Gráfica
                plotOutput("plotCluster"),
                #plotPredict
                htmlOutput("cluster"),
                #prediccion
                verbatimTextOutput("summaryCluster", placeholder = FALSE)
              ),
              
              box(
                width = 3,
                title = "Criptomonedas",
                #Slider con el numero de grupos que se quiera crear:
                sliderInput(
                  "sliderCluster",
                  "1.introduce el numero de grupos que quieras crear",
                  min = 2,
                  max = 15,
                  value = 4
                ),
                #Slider con el numero de dias para la agrupacion:
                sliderInput(
                  "sliderClusterDays",
                  "2.introduce el numero de dias para la predicción",
                  min = 5,
                  max = 90,
                  value = 14
                ),
                #Selector de columnas/atributos:
                selectInput(
                  inputId = "columnCluster",
                  #columnPredict
                  label = "Selecciona un atributo:",
                  #Solo seleccionamos las columnas High, Low, Open, Close, Volume y Marketcap
                  choices = names(coins)[4:9],
                  #Por defecto seleccionada la columna Close
                  selected = names(coins)[7]
                ),
                #Botón para lanzar la busqueda:
                actionButton("executeCluster", "Buscar"),
                textInput("texto", "3. Visualiza un cluster", placeholder = "Cluster ID"),
                actionButton("visual", "Visualizar")
              )
            ))
  ))
)

server <- function(input, output) {
  clusters <- reactiveValues(data = NULL)
  coins_list <- reactiveValues(data = NULL)
  sliderLearner <- reactiveValues(data = NULL)
  sliderPredictor <- reactiveValues(data = NULL)
  columnPredict <- reactiveValues(data = NULL)
  output$plot1 <-
    renderPlot({
      #Filtramos el dataset por nombre de criptomoneda (atributo Name) seleccionado/s en el checkbox
      df <-
        coins[grepl(paste(paste(paste0(
          "^", input$coins
        ), "$", sep = ""), collapse = "|"), coins$Name),]
      #Eje x -> fecha, eje y -> seleccionado con el input select
      ggplot(data = df, aes(
        x = Date,
        y = df[[input$column]],
        group = Name,
        color = Name
      )) +
        geom_line() + labs(y = input$column)
    })
  
  observeEvent(input$executePredict, {
    coin_selected <-
      coins[grepl(paste(paste(
        paste0("^", input$coinsPredict), "$", sep = ""
      ), collapse = "|"), coins$Name),]
    
    #Guardamos los valores de los inputs para que no cambie automáticamente, sólo cuando se esté observando el evento
    sliderLearner$data <- input$sliderLearner
    sliderPredictor$data <- input$sliderPredictor
    columnPredict$data <- input$columnPredict
    
    coin_selected$Date <-
      as.numeric(as.Date(coin_selected$Date))
    
    rule <- str_c(input$columnPredict, " ~ Date")
    
    modeloPredictivo <-
      lm(rule,
         data = tail(coin_selected, input$sliderLearner))
    
    next_day <- tail(coin_selected$Date, 1) + 1
    
    nuevo <-
      data.frame(Date = c(next_day:(next_day + sliderPredictor$data - 1)))
    
    prediccion <-
      predict(object = modeloPredictivo,
              newdata = nuevo,
              interval = "prediction")
    
    #mydata <- cbind(coin_selected, prediccion)
    #mydata <- cbind(coin_selected, prediccion)
    #mydata$Date <- as.Date(mydata$Date)
    
    output$prediccion <- renderText({
      string <-
        "<style>
      table,
      th,
      td {
        padding: 10px;
        border: 1px solid black;
        border-collapse: collapse;
      }
    </style>
        <h3>La prediccion para el/los día/s</h3><table><tr><th>Días</th>
    <th>Prediccion</th>"
      for (i in 1:sliderPredictor$data) {
        date <- as.Date(nuevo[[1]][i])
        pred <- round(prediccion[[i]], 2)
        string <-
          str_c(string,
                "<tr><td>",
                date,
                "</td><td> ",
                pred,
                "</td></tr>",
                collapse = NULL)
      }
      string <- str_c(string, "</table>")
    })
    
    output$summary <- renderPrint({
      print("Resumen del modelo predictivo:")
      summary(modeloPredictivo)
    })
    
    output$plotPredict <-
      renderPlot({
        # 2. Regression line + confidence intervals
        nuevo$Date <- as.Date(nuevo$Date)
        coin_selected$Date <- as.Date(coin_selected$Date)
        coin_selected <- tail(coin_selected, sliderLearner$data)
        prediccion <- as.data.frame(prediccion)
        p <-
          ggplot(coin_selected, aes(x = Date, y = coin_selected[[columnPredict$data]])) +
          geom_point() +
          labs(y = columnPredict$data) +
          stat_smooth(method = lm) +
          geom_line(aes(y = min(prediccion$lwr)), color = "red", linetype = "dashed") +
          geom_line(aes(y = max(prediccion$upr)), color = "red", linetype = "dashed")
        
        
        for (i in 1:sliderPredictor$data) {
          p <-
            p + annotate(geom = "point", x = nuevo$Date[i], y = prediccion$fit[i], color = "blue")
        }
        
        p
      })
  })
  
  #Tercera
  observeEvent(input$executeCluster, {
    coin_cluster <- coins
    
    #coin_cluster$Date <-
    #as.numeric(as.Date(coin_cluster$Date))
    
    coin_cluster =  split(coin_cluster, coin_cluster$Name)
    
    coins_list$data <- data.frame()
    
    for (i in 1:length(coin_cluster)) {
      coin_cluster[[i]] <-
        tail(coin_cluster[[i]], input$sliderClusterDays)
      #name <- unique(coin_cluster[[i]]$Name)
      coin_cluster[[i]] <-
        subset(coin_cluster[[i]], select = c("Date", input$columnCluster))
      coin_cluster[[i]] <-
        transpose(make.names = "Date", coin_cluster[[i]])
      coins_list$data <- rbind(coins_list$data, coin_cluster[[i]])
      #rownames(coins_list[i]) <- name
    }
    
    clusters$data <-
      kmeans(coins_list$data, input$sliderCluster, nstart = 25)
    
    
  })
  observeEvent(input$visual, {
    #data.cluster.x = coins_list[clusters$data$cluster == input$texto,]
    #coins_list$data$name <- names_coins
    #coins_list$data <- coins_list$data[, c()]
    output$summaryCluster = renderPrint({
      summary(coins_list$data[clusters$data$cluster == input$texto,])
    })
    
    output$plotCluster <-
      
      renderPlot({
        c <- coins_list$data
        c$Name <- names_coins
        c$Group <- clusters$data$cluster
        c <- c[c$Group == input$texto,]
        c$Group <- NULL
        d <- melt(data = c, id.vars = "Name")
        #fviz_cluster(clusters$data, coins_list$data)
        ggplot(data = d, aes(
          x = variable,
          y = value,
          group = Name,
          color = Name
        )) +
          geom_line() + labs(y = input$columnCluster, x = "Date")
      })
    
  })
  
  
}

shinyApp(ui, server)