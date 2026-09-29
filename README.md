# Diagnóstico de perfiles de investigadores FACSO

Caracterización de la planta académica de la Facultad de Ciencias Sociales para identificar perfiles de investigadores. El objetivo es **mejorar y focalizar las políticas de apoyo a la postulación de fondos**.

El análisis parte de cero respecto del proyecto previo (`../diagnostico-apoyos`), cuyo agrupamiento estadístico (LPA) dio solo 2 perfiles, insuficientes para focalizar. Aquí se usa un **enfoque híbrido**: una tipología por reglas, que la política puede aplicar directamente, validada con un análisis de clases latentes (LCA).

> ⚠️ `input/` y `output/perfiles-academicos.csv` contienen **datos nominales** (RUT, nombres). Son de uso interno y no deben compartirse. El informe es agregado y sin nombres.

## Datos (`input/`)

| Archivo | Contenido |
|---|---|
| `acad.xlsx` | Planta actual: un nombramiento por fila (225 filas, 206 RUT) |
| `data-general.rdata` (`data`) | Investigador × proyecto, 1987–2026. Incluye postulaciones no adjudicadas y pendientes |
| `base-final.rdata` (`base_final`) | Publicaciones × autor, 2016–2025 |
| `primera_jeraq.rdata` | Año de la primera jerarquización, que es el indicador de ingreso a la universidad |

## Decisiones de diseño (confirmadas)

- **Fondos externos:** todo concurso que no sea de la Facultad, incluidos los de la **U. de Chile** (U-Inicia, U-Apoya, U-Redes, etc.).
- **Fondos de la Facultad (FPCI, FIP):** quedan fuera de la segmentación y se analizan **a posteriori**. FPCI es el instrumento de apoyo a carreras académicas.
- **Liderazgo** (foco): solo *Investigador responsable* y *Director*.
- **Coinvestigación** (secundaria): coinvestigador, director alterno, investigador asociado e **investigador principal**.
- **Patrocinio de postdoctorados:** categoría aparte, usada como indicador de consolidación.
- **Trayectoria completa:** se incluyen los proyectos anteriores al ingreso a FACSO.
- **Ingreso a la universidad:** se mide con `primera_jeraq`. `FECH_ING_U` no se usa, porque incluye ingresos a honorarios y otras modalidades.
- **Características del investigador:** género, edad, jerarquía, años en la jerarquía y años desde el grado. Forman parte explícita de la caracterización y del modelamiento de los perfiles.
- **Universo:** planta vigente, una fila por RUT (horas sumadas con tope de 44, jerarquía más alta). Se excluyen los nombramientos de postdoctorales y los ad honorem. Análisis principal con 12 horas o más; sensibilidad con 22 horas o más.
  - Las filas idénticas de un mismo RUT son nombramientos reales e iguales: se suman.
  - Las horas en dejación transitoria se cuentan (son académicos de jornada completa con cargos directivos).
  - Los profesores adjuntos entran si cumplen el criterio de horas.

### Supuestos por confirmar

- **Etapa de carrera:** según años desde el doctorado (inicial ≤ 7, intermedia 8–15, consolidada > 15, sin doctorado aparte). Parámetros en `00-setup.R`.

- **Ventana de volumen:** 2016–2025, igual que las publicaciones. La recencia y las trayectorias usan toda la historia.
- **Postulaciones pendientes:** cuentan como actividad, pero no entran en las tasas de éxito.
- **Tasas de éxito:** los no adjudicados vienen sobre todo de ANID/Conicyt, así que se reportan por fuente y con la cobertura auditada.

## Preguntas del diagnóstico

1. **Cobertura.** ¿Qué proporción de la planta publica, postula como IR, adjudica y lo hace de forma recurrente? Se presenta como un embudo.
2. **Éxito y persistencia.** ¿Cuál es la tasa de adjudicación por concurso? ¿Quienes no se adjudican vuelven a postular?
3. **Trayectorias y pipelines.** ¿Cuánto tiempo pasa desde el ingreso o el grado hasta la primera postulación y la primera adjudicación? ¿Funcionan los tránsitos **U-Inicia → Fondecyt Iniciación** y **U-Apoya → Fondecyt Regular**?
4. **Brechas.** ¿Cómo varían postulación y éxito según género, edad, jerarquía, años en la jerarquía, años desde el grado, departamento y productividad?
5. **Perfiles.** ¿Qué grupos de académicos, distintos entre sí y accionables, existen, y quiénes los componen?
6. **Instrumentos de la Facultad.** ¿A qué perfiles llegan FPCI y FIP? ¿Se asocian a postulaciones o adjudicaciones externas posteriores?

## Fases y scripts

| Script | Fase | Salida principal |
|---|---|---|
| `R/00-setup.R` | Paquetes, rutas, parámetros, funciones, paleta | — |
| `R/01-academicos.R` | Universo y características del investigador, etapa de carrera | `output/datos/academicos.rds` |
| `R/02-proyectos.R` | Mapeo concurso → tipo de fondo (`R/mapeo-concursos.csv`), roles y estados | `output/datos/proyectos.rds` |
| `R/03-publicaciones.R` | Deduplicación e indicadores de calidad | `output/datos/publicaciones.rds` |
| `R/04-indicadores.R` | Indicadores por académico en las dimensiones A–G (abajo) | `output/datos/base-investigadores.rds` |
| `R/05-descriptivos.R` | Auditoría de cobertura, embudo, Kaplan-Meier, pipelines, modelos logísticos | figuras y tablas |
| `R/06-tipologia.R` | **Tipología por reglas**, sensibilidad, caracterización y modelo multinomial | `output/datos/tipologia.rds` |
| `R/07-lca.R` | LCA con indicadores categorizados y covariables; comparación con la tipología (ARI) | `output/datos/lca.rds` |
| `R/08-instrumentos.R` | FPCI/FIP por perfil, secuencia FPCI → fondos externos, transición coinvestigador → IR | figuras y tablas |
| `informe/diagnostico.qmd` | Informe final (HTML y Word) | `informe/diagnostico.html` y `.docx` |

**Dimensiones de indicadores (2016–2025 salvo que se indique):**
- **A. Postulación como IR:** n.º de postulaciones, años con postulación, recencia.
- **B. Éxito:** adjudicaciones, tasa suavizada (Beta-binomial), persistencia tras un rechazo.
- **C. Escala y pipelines:** U-Inicia → Iniciación, U-Apoya → Regular, Iniciación → Regular, asociativos, internacionales, montos.
- **D. Colaboración:** coinvestigaciones, % de participaciones como IR, patrocinio de postdoctorados.
- **E. Productividad:** n.º de publicaciones, % WoS/Scopus, % Q1–Q2, continuidad, recencia.
- **F. Características:** género, edad, jerarquía, años en la jerarquía, años desde el grado, años desde el ingreso, etapa de carrera y departamento.
- **G. Fondos de la Facultad (a posteriori):** FPCI/FIP.

**Tipología (resultado principal):** cruza dos ejes y usa la etapa de carrera para matizar:
- **Relación con fondos externos como IR:** no postula / postula sin adjudicar / adjudica una vez / adjudica recurrentemente o lidera asociativos.
- **Productividad reciente:** activa o baja.

Resultan de 5 a 7 perfiles con nombres orientados a la acción. Los umbrales se fijan antes de mirar los instrumentos y quedan documentados.

## Ejecución

```r
# Desde la raíz del proyecto
source("run-all.R")   # scripts 01-08 + compilación del informe
```

Requiere R ≥ 4.5 y Quarto.

## Estado

- [x] Plan de análisis y estructura del proyecto
- [ ] 01–03 Limpieza y armonización
- [ ] 04 Indicadores
- [ ] 05 Diagnóstico general
- [ ] 06 Tipología
- [ ] 07 LCA
- [ ] 08 Fondos de la Facultad
- [ ] Informe
