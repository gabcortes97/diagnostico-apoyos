
### PROYECTOS: armonización de concursos, roles y estados
# Entradas: input/data-general.rdata, R/mapeo-concursos.csv
# Salida:   output/datos/proyectos.rds (una fila por investigador x proyecto)
# Tipo de fondo (externos incluyen U. de Chile; Facultad = FPCI/FIP), rol (liderazgo =
# IR/Director; coinvestigación incluye investigador principal; patrocinio) y estado
# (adjudicado / no adjudicado / pendiente). Trayectoria completa, incluye proyectos previos a FACSO.

source(here::here("R", "00-setup.R"))


## 1. Carga ---------------------------------------------------------------------------

# Investigador x proyecto, 1987-2027 (objeto data): 1.938 filas, 190 RUT, 96 concursos.
# No hay filas repetidas de RUT x código de proyecto.
load(file.path(ruta_input, "data-general.rdata"))

# Mapeo concurso -> fuente (quién financia), tipo de fondo, instrumento y asociativo.
# Se clasifica por concurso y no por la variable institucion, porque esta tiene NA en
# algunos concursos y separa ANID de Conicyt/Mideplan (aquí todo es ANID).
# Si aparece un concurso nuevo en la base, hay que agregarlo al CSV (ver revisión, sección 4).
mapeo <- read_csv(here("R", "mapeo-concursos.csv"), show_col_types = FALSE)


## 2. Roles y estados ---------------------------------------------------------------------

# Las variables etiquetadas (haven) se pasan a texto con sus etiquetas
proyectos <- data |>
  mutate(rol_original = as.character(haven::as_factor(tipo_investigador)),
         estado_original = as.character(haven::as_factor(estado_proyecto))) |>
  # La marca de asociativo de la base es incompleta (p. ej., Institutos Milenio y parte de
  # Anillos figuran como "No"): se reemplaza por la del mapeo - REVISAR EN CINDAI
  select(-asociativo) |>
  left_join(mapeo, by = "concurso") |>
  mutate(
    # Rol agrupado. En Fondecyt Postdoctorado:
    # - el académico como "Investigador responsable" fue él mismo el postdoc (en muchos
    #   casos antes de ingresar a la U.), así que queda como liderazgo;
    # - el académico como "Coinvestigador" es en la práctica el patrocinante del postdoc.
    # En FIP el rol viene registrado directamente como "Patrocinante".
    rol = case_when(
      instrumento == "Fondecyt Postdoctorado" & rol_original == "Coinvestigador" ~ "Patrocinio",
      rol_original == "Patrocinante"                                            ~ "Patrocinio",
      rol_original %in% c("Investigador responsable", "Director")               ~ "Liderazgo",
      asociativo                                                                ~ "Coinvestigación asociativa",
      TRUE                                                                      ~ "Coinvestigación individual"
    ),
    rol = factor(rol, levels = c("Liderazgo", "Coinvestigación asociativa",
                                 "Coinvestigación individual", "Patrocinio")),

    # Estado: finalizados y en ejecución están adjudicados; "Postulado" = resultado pendiente
    estado = case_when(
      estado_original %in% c("Finalizado", "En ejecución") ~ "Adjudicado",
      estado_original == "No adjudicado"                    ~ "No adjudicado",
      estado_original == "Postulado"                        ~ "Pendiente"
    ),
    estado = factor(estado, levels = c("Adjudicado", "No adjudicado", "Pendiente")),
    adjudicado = estado == "Adjudicado",

    # Proyecto vigente (adjudicado y aún en ejecución). Reemplaza la variable etiquetada
    # en_ejecucion de la base, que es NA en los pendientes.
    en_ejecucion = estado_original == "En ejecución",

    # Resultado conocido: los pendientes cuentan como actividad, pero no en las tasas de éxito
    resuelto = estado != "Pendiente",

    # Ventana de volumen (anio_ini-anio_fin). Recencia y trayectorias usan toda la historia.
    en_ventana = between(anio_concurso, anio_ini, anio_fin),

    # Monto adjudicado en pesos: con moneda "Miles de pesos (M$)" viene en miles;
    # sin moneda (sobre todo fondos U. de Chile y Facultad) viene en pesos.
    monto_pesos = if_else(str_detect(str_to_lower(moneda), "miles") & !is.na(moneda),
                          monto_adjudicado * 1000, monto_adjudicado)
  )

# Revisar desde aquí

## 3. Selección de variables ---------------------------------------------------------------

# Las características del investigador (sexo, edad, jerarquía, grado) no se traen de esta
# base: se toman de academicos.rds (01), que está depurada y actualizada.
proyectos <- proyectos |>
  select(rut = rut_investigador, codigo_proyecto, titulo, concurso, anio_concurso,
         fuente, tipo_fondo, instrumento, asociativo,
         rol, rol_original, estado, estado_original, adjudicado, en_ejecucion, resuelto,
         en_ventana,
         duracion, monto_pesos, proyecto_facso) |>
  mutate(proyecto_facso = haven::as_factor(proyecto_facso) == "Sí") |>
  arrange(rut, anio_concurso)


## 4. Revisión -----------------------------------------------------------------------------

# Concursos sin mapeo (debe dar 0 filas)
proyectos |> filter(is.na(tipo_fondo)) |> distinct(concurso)

# Roles y estados sin clasificar (debe dar 0 filas)
proyectos |> filter(is.na(rol) | is.na(estado)) |> count(rol_original, estado_original)

# Cruces de control
count(proyectos, rol_original, rol)
count(proyectos, estado_original, estado)
count(proyectos, tipo_fondo, fuente)
proyectos |> filter(instrumento != "Otro") |> count(instrumento, rol, estado)

# Cobertura de los no adjudicados por fuente: la auditoría de tasas de éxito se hace en 05
proyectos |> filter(resuelto) |> count(fuente, estado) |>
  pivot_wider(names_from = estado, values_from = n, values_fill = 0)

# Cruce con el universo de académicos (01)
academicos <- read_rds(file.path(ruta_datos, "academicos.rds"))
proyectos |> distinct(rut) |> mutate(en_planta = rut %in% academicos$rut) |> count(en_planta)
academicos |> filter(universo) |> mutate(con_proyectos = rut %in% proyectos$rut) |>
  count(con_proyectos)


## 5. Guardar -------------------------------------------------------------------------------

write_rds(proyectos, file.path(ruta_datos, "proyectos.rds"))
