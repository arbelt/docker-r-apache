# R-apache Docker image

Docker image based on `rocker/tidyverse` for deploying Shiny apps to Heroku.
Runs an Apache2 reverse proxy in front of an R Shiny app so we can add some
middleware, such as authentication/authorization.

## Usage

This image is meant to provide a base for packaging Shiny apps; by default it
runs the `01_hello` packaged with Shiny. Includes a helper script `/runApp.r` to
make it easy to call `shiny::runApp()` from the shell.

A minimal Dockerfile would look something like:

``` dockerfile
FROM albertw/r-apache:latest
COPY /app.R /app/app.R
CMD ["/runApp.r", "/app"]
```

Apache site configuration is in `/etc/apache2/sites-available/shiny.conf`.
Overwrite to customize, e.g., add authentication. The default listens on all
domains and proxies to 127.0.0.1:3939, where the Shiny app runs.

To add additional packages, either use the `install.r` script (from `littler`)
or run `packrat::restore()` as part of the build process, e.g.,

``` dockerfile
FROM albertw/r-apache:latest
RUN install.r wrapr rquery semantic.dashboard
RUN cd /app && r 'packrat::restore()'
COPY /app.R /app/app.R
CMD ["/runApp.r", "/app"]
```


## What's included

### Apache configuration 

Heroku runs Docker containers in a slightly non-standard way:

- Container must bind to a port specified at run-time in the environment
  variable `PORT`
- Container must run as a normal non-root user that's not known ahead of time

Run-time port specification is simple: hard-coded listening port in
`/etc/apache2/ports.conf` was replaced with the environment variable.

Non-root user is a little trickier because Apache needs the user to be specified
in the config file. For now:

- Set user and group in `/etc/apache2/envvars`. This is just a shell script so
  get values from `id -un` and `id -gn`.
- Set a bunch of directories in `/var` to be globally readable and writable.

Finally, to get logging through Docker to work, the default log files are
symlinked to stdout/stderr.

### Rprofile

`shiny.port` and `shiny.host` options are set in the site-wide R profile.
(`/usr/local/lib/R/etc/Rprofile.site`)

``` R
options(shiny.host = "127.0.0.1", shiny.port = 3838)
```

### Scripts

- `/entrypoint.sh`: specified as the `ENTRYPOINT` of the image. Runs Apache and
  the R process (specified in the Dockerfile `CMD`) in the background and
  monitors them; exits if either process exits. In addition, it reparents itself
  under `tini` if it detects it's running as PID 1 (useful for local testing,
  Heroku does not seem to run Docker containers as PID 1 though).
- `/runApp.r`: simple wrapper around `shiny::runApp()` that takes an app
  directory as its argument. Can optionally specify listening port and host with
  `-p` and `-h` flags.
