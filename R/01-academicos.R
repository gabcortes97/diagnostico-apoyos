
### ACADÉMICOS: universo y características del investigador
# Entradas: input/acad.xlsx, input/primera_jeraq.rdata
# Salida:   output/datos/academicos.rds (una fila por RUT)
# Universo, horas sumadas (tope 44), jerarquía más alta, género, edad, años en la
# jerarquía, años desde el grado, años desde el ingreso (primera jerarquización;
# no se usa FECH_ING_U) y etapa de carrera.

source(here::here("R", "00-setup.R"))


## 1. Carga ---------------------------------------------------------------------------

# Planta vigente: un nombramiento por fila (225 filas, 206 RUT)
acad_raw <- read_excel(file.path(ruta_input, "acad.xlsx"))

# Año de la primera jerarquización por RUT (objeto primera_jeraq)
load(file.path(ruta_input, "primera_jeraq.rdata"))


## 2. Nombramientos válidos -------------------------------------------------------------

nombramientos <- acad_raw |>
  # Ojo: hay 2 RUT con dos filas idénticas (6 + 6 y 21 + 21 horas). No son duplicados,
  # sino nombramientos reales e iguales, así que se mantienen y sus horas se suman.
  # Fuera del universo: postdoctorales y nombramientos ad honorem. Se excluye el
  # nombramiento, no la persona: si tiene además un contrato pagado, se mantiene.
  filter(!str_detect(CARGO, "Postdoctoral"),
         TIPO_CONT != "K Ad Honorem Contrata") |>
  mutate(
    # Jerarquía sin la categoría académica
    jerarquia = case_when(
      str_detect(JERARQUIA, "Titular")    ~ "Titular",
      str_detect(JERARQUIA, "Asociado")   ~ "Asociado",
      str_detect(JERARQUIA, "Asistente")  ~ "Asistente",
      str_detect(JERARQUIA, "Instructor") ~ "Instructor",
      str_detect(JERARQUIA, "Adjunto")    ~ "Adjunto"
    ),
    # Rango para elegir la jerarquía más alta. Adjunto queda al final porque es una
    # categoría aparte (no forma parte de la carrera ordinaria ni docente).
    rango = case_when(jerarquia == "Titular"    ~ 5,
                      jerarquia == "Asociado"   ~ 4,
                      jerarquia == "Asistente"  ~ 3,
                      jerarquia == "Instructor" ~ 2,
                      jerarquia == "Adjunto"    ~ 1),
    # Categoría académica (solo para profesores asistente, asociado y titular)
    categoria = case_when(
      str_detect(JERARQUIA, "Ord\\.") ~ "Ordinaria",
      str_detect(JERARQUIA, "Doc\\.") ~ "Docente"
    ),
    departamento = case_when(
      str_detect(REPARTICION, "Antropolog") ~ "Antropología",
      str_detect(REPARTICION, "Educaci")    ~ "Educación",
      str_detect(REPARTICION, "Psicolog")   ~ "Psicología",
      str_detect(REPARTICION, "Sociolog")   ~ "Sociología",
      str_detect(REPARTICION, "Trabajo")    ~ "Trabajo Social",
      str_detect(REPARTICION, "Postgrado")  ~ "Escuela de Postgrado"
    )
  )


## 3. Una fila por RUT --------------------------------------------------------------------

# 3.1 Horas: suma de todos los nombramientos, con tope de 44.
# Se cuentan también los nombramientos en dejación transitoria (DEJ_TRANSITORIA_VIG = "SI"):
# corresponden a académicos con jornada completa que ejercen cargos directivos.
# Los profesores adjuntos entran al universo si cumplen el criterio de horas.
horas <- nombramientos |>
  group_by(rut = RUT) |>
  summarise(
    horas           = min(sum(HORAS_REALES), horas_tope),
    n_nombramientos = n(),
    n_deptos        = n_distinct(departamento),
    dejacion        = any(DEJ_TRANSITORIA_VIG == "SI")
  )

# 3.2 Departamento: el del nombramiento con más horas (empate: el primero de la planilla)
deptos <- nombramientos |>
  arrange(RUT, desc(HORAS_REALES)) |>
  distinct(RUT, .keep_all = TRUE) |>
  select(rut = RUT, departamento)

# 3.3 Jerarquía más alta y su fecha de ratificación (si hay dos filas con la misma
# jerarquía, la más reciente). Los datos personales son iguales en todas las filas del RUT.
jerarquias <- nombramientos |>
  arrange(RUT, desc(rango), desc(FECH_RATIF_JERARQUIA)) |>
  distinct(RUT, .keep_all = TRUE) |>
  select(rut = RUT, nombre = FUNCIONARIO, SEXO, FECH_NAC, GRADO, FECHA_GRADO, PAIS_GRADO,
         jerarquia, categoria, FECH_RATIF_JERARQUIA)

academicos <- horas |>
  left_join(deptos, by = "rut") |>
  left_join(jerarquias, by = "rut") |>
  left_join(primera_jeraq |> select(rut = rut_investigador, anio_ingreso = jerarquizacion),
            by = "rut")


## 4. Características del investigador ------------------------------------------------------

# Todos los "años desde" se calculan respecto de anio_ref (00-setup.R)
academicos <- academicos |>
  mutate(
    genero = if_else(SEXO == "Femenino", "Mujer", "Hombre"),
    edad   = anio_ref - year(FECH_NAC),

    jerarquia = factor(jerarquia, levels = c("Instructor", "Asistente", "Asociado",
                                             "Titular", "Adjunto")),
    anios_jerarquia = anio_ref - year(FECH_RATIF_JERARQUIA),

    # Grado más alto registrado (Especialista y Licenciado quedan en "Otro")
    grado = case_when(
      str_detect(GRADO, "Doctor") ~ "Doctorado",
      str_detect(GRADO, "Mag")    ~ "Magíster",
      !is.na(GRADO)               ~ "Otro"
    ),
    grado_extranjero = PAIS_GRADO != "CHILE",
    anio_grado  = year(FECHA_GRADO),
    anios_grado = anio_ref - anio_grado,

    # Ingreso a la universidad = primera jerarquización (NA en 3 instructores sin registro)
    anios_ingreso = anio_ref - anio_ingreso,

    # Etapa de carrera según años desde el doctorado
    etapa = case_when(
      grado != "Doctorado" | is.na(grado) ~ "Sin doctorado",
      anios_grado <= etapa_inicial        ~ "Inicial",
      anios_grado <= etapa_consol         ~ "Intermedia",
      TRUE                                ~ "Consolidada"
    ),
    etapa = factor(etapa, levels = c("Sin doctorado", "Inicial", "Intermedia", "Consolidada")),

    # Universo principal (12 horas o más) y de sensibilidad (22 horas o más)
    universo      = horas >= horas_min,
    universo_sens = horas >= horas_sens
  ) |>
  select(rut, nombre, departamento, horas, universo, universo_sens, n_nombramientos,
         n_deptos, dejacion, genero, edad, jerarquia, categoria, anios_jerarquia,
         grado, grado_extranjero, anio_grado, anios_grado, anio_ingreso, anios_ingreso,
         etapa)


## 5. Revisión -----------------------------------------------------------------------------

count(academicos, universo, universo_sens)
academicos |> filter(universo) |> count(jerarquia, etapa)
academicos |> filter(universo) |> count(departamento, genero)

# Casos a revisar: dejación transitoria y sin año de ingreso
academicos |> filter(dejacion) |> select(rut, jerarquia, horas, n_nombramientos)
academicos |> filter(is.na(anio_ingreso)) |> select(rut, jerarquia, horas)


## 6. Guardar -------------------------------------------------------------------------------

write_rds(academicos, file.path(ruta_datos, "academicos.rds"))
