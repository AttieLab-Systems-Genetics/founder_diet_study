# README for Deployment

This folder has instructions for deploying the Founder Diet Study Shiny App to RStudio Connect.
The app is deployed at <https://connect.doit.wisc.edu/FounderDietStudy/>.
The code is in
[byandell-sysgen/FounderDietStudy/deployNew](https://github.com/byandell-sysgen/FounderDietStudy/tree/main/deployNew).
Key files are:

- [`app.R`](app.R): R Shiny App code
- [`appSetup.R`](appSetup.R): Code to set up `datasets.rds`
- `datasets.rds`: RDS file containing names of datasets
- `help.Rmd`: R Markdown file containing help information for the app
- [`help.md`](help.md): processed markdown from `help.Rmd`

As configured, this assumes user as acquired the necessary data and placed the following files in this directory:

- `traitData.rds`: raw data
- `traitSignal.rds`: signals
- `traitStats.rds`: statistics
- `traitModule.rds`: module information

The most recent versions of these data are in the parent directory:
`$RD/adattie/General/founder_diet_study/`.
