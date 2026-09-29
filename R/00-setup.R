
### CONFIGURACIÓN COMÚN
# Paquetes, rutas, parámetros del análisis (anio_ini, anio_fin, horas_min, anio_ref),
# funciones auxiliares, paleta y tema ggplot del informe.
# Se carga con source() al inicio de cada script.


## 1. Paquetes -----------------------------------------------------------------------

library(pacman)

p_load(tidyverse, readxl, here, writexl, survival)

# Estos paquetes NO se cargan, porque tapan funciones del tidyverse: poLCA carga MASS
# (tapa dplyr::select()), mclust tapa purrr::map() y scales tapa purrr::discard().
# Se llaman con paquete::función, p. ej. poLCA::poLCA(), nnet::multinom(),
# mclust::adjustedRandIndex(), scales::percent(). Aquí solo se instalan si faltan.
faltan <- setdiff(c("poLCA", "nnet", "mclust", "scales"), rownames(installed.packages()))
if (length(faltan) > 0) install.packages(faltan)


## 2. Rutas --------------------------------------------------------------------------

# here() apunta siempre a la raíz del proyecto (marcada con el archivo .here), también
# cuando el informe se compila desde informe/.
ruta_input   <- here("input")
ruta_datos   <- here("output", "datos")
ruta_figuras <- here("output", "figuras")
ruta_tablas  <- here("output", "tablas")

# Las carpetas de salida no se versionan: se crean si no existen
walk(c(ruta_datos, ruta_figuras, ruta_tablas), dir.create, recursive = TRUE, showWarnings = FALSE)


## 3. Parámetros del análisis ----------------------------------------------------------

# Ventana de volumen (postulaciones y publicaciones). Recencia y trayectorias usan toda la historia.
anio_ini <- 2016
anio_fin <- 2025

# Año de referencia para edad, años en la jerarquía, desde el grado y desde el ingreso
anio_ref <- 2026

# Universo: horas sumadas por RUT con tope; análisis principal y sensibilidad
horas_tope <- 44
horas_min  <- 12
horas_sens <- 22

# Ventana (años) para la secuencia FPCI/FIP -> postulación o adjudicación externa (08)
ventana_seq <- 3

# Semilla para LCA y cualquier procedimiento aleatorio
set.seed(2026)


## 4. Funciones auxiliares -------------------------------------------------------------
# Solo las que se repiten en varios scripts.

# Máximo que devuelve NA (y no -Inf con advertencia) cuando todos los valores son NA.
# Útil en summarise() por académico (p. ej., último año de postulación).
max_na <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
min_na <- function(x) if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE)

# Guarda una figura en output/figuras/ con tamaño uniforme para el informe
guardar_figura <- function(grafico, nombre, ancho = 8, alto = 5) {
  ggsave(file.path(ruta_figuras, paste0(nombre, ".png")), grafico,
         width = ancho, height = alto, dpi = 300, bg = "white")
}


## 5. Paleta y tema ----------------------------------------------------------------------

# Paleta categórica del proyecto anterior (7 colores, para perfiles y fuentes)
paleta <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7")
color_principal <- paleta[1]
color_neutro    <- "grey55"

# Tema común para todas las figuras
theme_set(
  theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold"),
          plot.title.position = "plot",
          legend.position = "bottom")
)
