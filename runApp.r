#!/usr/bin/env Rscript

library("docopt")

doc <- "Usage: runApp.r [options] ( <appdir> | [-e <example>] )

-p PORT --port=PORT            Port to listen on
-h HOST --host=HOST            Host to listen on
-e EXAMPLE --example=EXAMPLE   Example name [default: 01_hello]
"

if (exists("argv")){
  cmdArgs <- argv
} else {
  cmdArgs <- commandArgs(trailingOnly = TRUE)
}

args <- docopt(doc, cmdArgs, help = TRUE)

port <- if (!is.null(args$port)) as.numeric(args$port) else getOption("shiny.port")

appdir <- if (!is.null(args$appdir)) args$appdir else {
  system.file("examples", args$example, package = "shiny")
}

message("App directory: ", normalizePath(appdir))

host <- if (!is.null(args$host)) args$host else {
  getOption("shiny.host", default = "127.0.0.1")
}

shiny::runApp(appdir, port = port, host = host)
