# https://connect.doit.wisc.edu/FounderDietStudy/

# Ensure pak and renv are installed
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
#renv::install("byandell/foundr")
#renv::install("byandell/foundrShiny")
#renv::snapshot()
#renv::record("byandell/foundr")
#renv::record("byandell/foundrShiny")

# Install CRAN and GitHub packages with pak
pak::pak(c("plotly", "markdown", "cowplot", "ggdendro"))
pak::pak(c("byandell/foundr", "byandell/foundrShiny"))
options(shiny.sanitize.errors = FALSE)

dirpath <- file.path(".")
traitData <- readRDS(file.path(dirpath, "traitData.rds"))
traitSignal <- readRDS(file.path(dirpath, "traitSignal.rds"))
traitStats <- readRDS(file.path(dirpath, "traitStats.rds"))
traitModule <- readRDS(file.path(dirpath, "traitModule.rds"))

#source("../appSetup.R")
datasets <- readRDS("datasets.rds")

customSettings <- list(
  help = "help.md",
  condition = "diet",
  entrykey = "Founder",
  dataset = datasets)

################################################################

title <- "New Founder Diet Study"

ui <- shiny::fluidPage(
  shiny::titlePanel(title),
  shiny::sidebarLayout(
    shiny::sidebarPanel(
      # foundrInput("foundr")
      foundrShiny::panelInput("panel"),
      foundrShiny::entryInput("entry")
    ),
    shiny::mainPanel(
      # foundrOutput("foundr")
      foundrShiny::panelOutput("panel")
    )
  )
)
server <- function(input, output, session) {
  # foundrShiny::foundrServer("foundr",
  #                           traitData, traitSignal, traitStats,
  #                           customSettings, traitModule)
  entry <- foundrShiny::entryServer("entry", customSettings)
  panel_list <- foundrShiny::panelServer("panel",
                            traitData, traitSignal, traitStats,
                            customSettings, traitModule, entry)

  # Allow reconnect with Shiny Server.
  session$allowReconnect(TRUE)
}
shiny::shinyApp(ui, server)
