#' Test UI
#' @export
#'
#' @import shiny
#'
#' @importFrom dplyr select mutate rename bind_rows case_when
#' @importFrom tidyr gather
#' @importFrom ggplot2 ggplot theme_light labs theme geom_point geom_line facet_wrap
#'
#' @param dt data of Tree series
#'
#'


# library(shiny)

Trend_age <-function(dt,... ){
  ui <- fluidPage(
              "Trend Age",
              sidebarPanel(width =3,
                           "三种方法拟合年龄趋势",
                           ## 读入 RW 和 MaxLA 序列拟合年龄趋势文件
                           # fileInput("fileRW", "Updata csv file of TreeRing series",
                           #           accept=c("text/csv", "text/comma-separated-values,text/plain")),
                           # checkboxInput("headerRW", "Header", TRUE),
                           # tags$hr(),
                           ## 指定行列名
                           textInput("xaxis", "colum of X-axis", "age"),
                           textInput("MRW", "colum of Ring Width", "MRW"),
                           textInput("MaxLA", "colum of Max Lumen area", "MaxLA"),
                           textInput("CD", "colum of Vessel density", "CD"),
                           textInput("RCTA", "colum of RCTA", "RCTA"),

                           tags$hr(),
                           ## 输入参数
                           helpText( "Formula: y  = α exp( β * x ) + c"),
                           helpText( "Parameters of MRW"),
                           ### input param 1 & 2 :alpha_age, beta_age
                           numericInput("rwA", "Alpha", NULL, min = -Inf , max = Inf ),
                           numericInput("rwB", "Beta", NULL, min = -Inf , max = Inf ),
                           numericInput("rwC", "C", NULL, min = -Inf , max = Inf ),

                           ### input Knots of gam , use slider
                           sliderInput("rwK",
                                       "K of GAM:",
                                       min = 1,
                                       max = 12,
                                       step = 1,
                                       value = 5 ), ## end of sliderinput
                           tags$hr(),

                           helpText( "Parameters of MaxLA"),
                           ### input param 1 & 2 :alpha_age, beta_age
                           numericInput("laA", "Alpha", NULL, min = -Inf , max = Inf ),
                           numericInput("laB", "Beta",NULL, min = -Inf , max = Inf ),
                           numericInput("laC", "C", NULL, min = -Inf , max = Inf ),
                           ### input Knots of gam , use slider
                           sliderInput("laK",
                                       "K of GAM:",
                                       min = 1,
                                       max = 12,
                                       step = 1,
                                       value = 5 ), ## end of sliderinput

                           tags$hr(),
                           selectInput("Trw", "Choose RW trend line:",
                                       choices = c("EXP", "GAM", "Manual")),
                           selectInput("Tla", "Choose a dataset:",
                                       choices = c("EXP", "GAM", "Manual")),
                           tags$hr(),
                           # Button
                           actionButton("Sim", "Calculate"),
                           # Button
                           downloadButton("downloadData", "Download Trend_age")

              ), ##end of sidebarPanel


              # 输出部分：显示图表
              mainPanel(
                tableOutput("dataRW"),
                plotOutput("RegFig"),
                tableOutput("Params"),
                tableOutput("ModAs"),
                plotOutput('Trendline'),
                tableOutput('Trend')
              ) ## mainPanel end --

  )

  server <- function(input, output) {
    ## blank database Tab1  ####
    Tab1Val <- reactiveValues(   )
    dtTrend <- reactiveValues(   )

    #### Tab 1 Analysis ####
    ### show dataTable
    output$dataRW <-renderTable({  head( dt,3 )  })

    observeEvent(input$Sim, {
      ResReg <- RegData( dt = dt ,
                         Nage = input$xaxis , Nrw = input$MRW, Nla = input$MaxLA,Ncd = input$CD,Nrcta = input$RCTA,
                         rwA = input$rwA, rwB = input$rwB, rwC = input$rwC, rwK = input$rwK,
                         laA = input$laA, laB = input$laB, laC = input$laC, laK = input$laK )

      Tab1Val$dtOri <- ResReg$dtOri
      Tab1Val$dtNor <- ResReg$dtNor
      Tab1Val$param <- ResReg$param
      Tab1Val$ModAs <- ResReg$ModAs

      ccrw <- dplyr::case_when(
        input$Trw == "EXP" ~ "pExpRw",
        input$Trw == "GAM" ~ "pGamRw",
        input$Trw == "Manual" ~ "mExpRw")
      ccla <- dplyr::case_when(
        input$Tla == "EXP" ~ "pExpLa",
        input$Tla == "GAM" ~ "pGamLa",
        input$Tla == "Manual" ~ "mExpLa")
      Tab1Val$Trend <- dplyr::left_join(Tab1Val$dtNor |> dplyr::select(all_of(  c('Year','age',ccrw,ccla ))) |>
                                          dplyr::rename( setNames( c('Year','age',ccrw,ccla ), c('Year','age','Tage','Lage'  ))),
                                        Tab1Val$dtOri |> dplyr::select(all_of(  c('Year','age',"MRW",'MaxLA','CD','RCTA',ccrw,ccla ))) |>
                                          dplyr::rename( setNames( c('Year','age',"MRW",'MaxLA','CD','RCTA',ccrw,ccla ),
                                                                   c('Year','age',"MRW",'MaxLA','CD','RCTA','TageOri','LageOri'  )))
      )  |> dplyr::mutate( Frw =  MRW - TageOri ,sFrw = scale(Frw) )

      output$RegFig <- renderPlot({
        dtRegSum <- ResReg$dtOri |> dplyr::select(age,MRW,pGamRw,pExpRw,mExpRw) |> dplyr::mutate(Name = "RW", type = "Regression", .after = age ) |>
          dplyr::rename(setNames( c('age','MRW','pGamRw','pExpRw','mExpRw' ),c('age','Obs','GAM','EXP','Manu' )) )
        dtRegSum <- ResReg$dtOri |> dplyr::select(age,MaxLA,pGamLa,pExpLa, mExpLa)|> dplyr::mutate(Name = "MaxLA", type = "Regression", .after = age) |>
          dplyr::rename(setNames( c('age','MaxLA','pGamLa','pExpLa','mExpLa' ),c('age','Obs','GAM','EXP','Manu' )))  |>
          dplyr::bind_rows(dtRegSum)
        dtRegSum <- ResReg$dtNor |> dplyr::select(age,pGamRw,pExpRw,mExpRw) |> dplyr::mutate(Name = "RW", type = "Trend line", .after = age ) |>
          dplyr::rename(setNames( c('age','pGamRw','pExpRw','mExpRw' ),c('age','GAM','EXP','Manu' )) ) |>
          dplyr::bind_rows(dtRegSum)
        dtRegSum <- ResReg$dtNor |> dplyr::select(age,pGamLa,pExpLa, mExpLa)|> dplyr::mutate(Name = "MaxLA", type = "Trend line", .after = age) |>
          dplyr::rename(setNames( c('age','pGamLa','pExpLa','mExpLa' ),c('age','GAM','EXP','Manu' )))  |>
          dplyr::bind_rows(dtRegSum) |> tidyr::gather(key, val , c(-1:-3)) |> na.omit()

        ggplot2::ggplot(dtRegSum ) + ## x = "age1", y = 'MRW'
          ggplot2::theme_light()+
          ggplot2::labs(title = "sim",
               # subtitle = paste( 'k = ', input$knots, '| α = ', alphat, " β = " ,  betat, " c = ",ct, ExpRes ),
               x = 'age', y = 'Value'
          )+
          ggplot2::theme(legend.position = "bottom")+
          # scale_y_continuous( limits = c(0 , 1.1*max(dt$y))    )+
          ggplot2::geom_point(ggplot2::aes(x= age, y = val ,color = "Obs" ), data = dtRegSum[ dtRegSum$key == "Obs",])+
          ggplot2::geom_line(ggplot2::aes(x= age, y = val , color = key))+
          ggplot2::facet_wrap(factor(Name,levels = c('RW', 'MaxLA') )  ~ type, scales = "free")

      }) # RegFig end

      output$Trendline <- renderPlot({


        ggplot2::ggplot(Tab1Val$Trend )+
          ggplot2::geom_line(  ggplot2::aes(x  = Year, y = Tage ,color = 'Tage'  ))+
          ggplot2::geom_line(  ggplot2::aes(x  = Year, y = Lage ,color = 'Lage'  ))

      })

      output$Params <- renderTable( Tab1Val$param, digits = 5 )
      output$ModAs <- renderTable( Tab1Val$ModAs , rownames = T  )
      output$Trend <- renderTable( head( Tab1Val$Trend ) )

    }) ## Sim act end

    # Downloadable csv of selected dataset ----
    output$downloadData <- downloadHandler(
      filename = "TrendAge.csv",
      content = function(file) {
        write.csv(Tab1Val$Trend , file, row.names = FALSE)
      }
    )
    #### Tab 1 Analysis end ----

  }

  shinyApp(ui, server)


}


## Trend_age(dt)
