# Proyecto final — Caso Universidad

**Bases de Datos, Universidad Pontificia Bolivariana**
Integrantes: Santiago Romero Viloria, Juan Pablo Quintero Carrillo, Yamid Rafael Amaya Diaz

Sistema de gestión académica en tres capas:

```
App web (HTML + JS)  --HTTP/JSON-->  API (FastAPI + psycopg2)  --SQL-->  PostgreSQL "universidad"
     puerto 5500                          puerto 8000
```

La app **nunca** toca la base: solo llama a la API. La API es el único programa con la contraseña de la base.

## Estructura

```
Entrega Final/
├── README.md
├── base_de_datos/
│   ├── ddl_completo.sql       tablas, restricciones, funciones, procedimiento, triggers y vista
│   ├── datos.sql              datos de prueba (INSERT)
│   ├── diagrama_er.png        diagrama E-R final (8 tablas)
│   └── diccionario_datos.md   cada tabla y columna explicada
├── api/
│   ├── main.py                todos los endpoints
│   ├── requirements.txt
│   └── .env.example           plantilla de la conexión (el .env real no se sube)
└── app/
    ├── index.html
    └── app.js
```

## Cómo correrlo

1. **Base de datos** (una sola vez):
   ```bash
   createdb universidad
   psql -d universidad -f base_de_datos/ddl_completo.sql
   psql -d universidad -f base_de_datos/datos.sql
   ```
2. **API**:
   ```bash
   cd api
   python3 -m venv .venv
   .venv/bin/pip install -r requirements.txt
   cp .env.example .env        # y poner usuario y contraseña reales
   .venv/bin/uvicorn main:app --reload
   ```
   Documentación interactiva: http://127.0.0.1:8000/docs
3. **App** (otra terminal):
   ```bash
   cd app
   python3 -m http.server 5500
   ```
   Abrir http://localhost:5500

## Endpoints

| Recurso | Endpoints |
|---|---|
| Carreras | `GET /carreras`, `GET /carreras/{id}`, `POST /carreras`, `PUT /carreras/{id}`, `DELETE /carreras/{id}` |
| Materias (FK a carrera) | `GET /materias`, `GET /materias/{id}`, `POST /materias`, `PUT /materias/{id}`, `DELETE /materias/{id}` |
| Estudiantes | `GET /estudiantes`, `GET /estudiantes/{id}`, `POST /estudiantes`, `PUT /estudiantes/{id}`, `DELETE /estudiantes/{id}` |
| Matrículas (triggers) | `GET /matriculas`, `POST /matriculas`, `PUT /matriculas/{id}/calificacion`, `DELETE /matriculas/{id}` |
| Auditoría (trigger) | `GET /auditoria` |
| Consultas de negocio | `GET /consultas/rendimiento-materias`, `GET /consultas/ocupacion-grupos` |

### Consultas de negocio (JOIN + GROUP BY)
- **Rendimiento por materia:** promedio, nota máxima y mínima, y reprobados por materia y semestre (JOIN matricula–grupo–materia).
- **Ocupación de grupos 2026-1:** inscritos, cupos libres y % de ocupación (JOIN grupo–materia–profesor, LEFT JOIN matricula).

### Lógica en la base que se ve en la app
- `POST /matriculas` activa los triggers **validar_cupo_matricula** y **validar_prerrequisitos_matricula**. Si el grupo está lleno o faltan prerrequisitos, el mensaje del trigger llega a la app (ej.: *"El grupo ya no tiene cupos disponibles"*).
- `PUT /matriculas/{id}/calificacion` activa **auditar_cambio_calificacion**, que guarda la nota vieja y la nueva; se ve en la pantalla *Auditoría*.

### Manejo de errores
Todo `INSERT/UPDATE/DELETE` pasa por `escribir()` en `main.py`, que hace `conexion.rollback()` ante cualquier rechazo de la base y responde:

| Código | Cuándo |
|---|---|
| 404 | El registro no existe |
| 409 | Dato repetido (UNIQUE), cualquier `ForeignKeyViolation` (borrar algo que otros datos usan o apuntar a un id que no existe), o un trigger lo rechaza |
| 422 | Faltan datos o tienen formato incorrecto, un valor fuera de rango (CHECK) o demasiado largo/grande para la columna |

Todas las consultas usan parámetros `%s` (nunca se pega texto del usuario en el SQL). La conexión se lee del `.env`, que está en `.gitignore`.

## Normalización

Todas las tablas están en **BCNF**: en cada dependencia funcional, el lado izquierdo es una llave (superllave). Las dependencias de cada tabla están en [`base_de_datos/diccionario_datos.md`](base_de_datos/diccionario_datos.md#dependencias-funcionales).

## Convención de nombres

Columnas en `snake_case`, llaves primarias `id_<entidad>` con `SERIAL` y palabras clave SQL en MAYÚSCULAS. Las tablas se dejaron en **singular** (`carrera`, `materia`, `matricula`…) porque así quedaron en el modelo de la Entrega 2 y la implementación de la Entrega 3; renombrarlas obligaría a reescribir triggers, funciones, vista y API sin cambiar el modelo.

## Cambios respecto a la Entrega 3

Qué observó el docente en la Entrega 3 y qué se hizo:

| Observación | Qué se hizo |
|---|---|
| Faltaba documentar qué se cambió respecto a la Entrega 2. | Quedó documentado abajo (puntos 1 a 4). |
| El índice `matricula(id_estudiante)` era redundante con el `UNIQUE (id_estudiante, id_grupo)`. | Se quitó (punto 6). |
| No había `INSERT` en `grupo` ni en `profesor`, y el script no era reproducible. | `base_de_datos/datos.sql` tiene los `INSERT` de las 8 tablas, en orden y con columnas: 5 profesores, 10 grupos, 36 matrículas… Se probó reconstruyendo la base desde cero con `ddl_completo.sql` + `datos.sql`. |
| Varios `UPDATE` y `DELETE` devolvían 0 filas sin avisar. | La API usa `RETURNING`: si el `WHERE` no encuentra la fila, responde **404** ("Esa carrera no existe") en vez de quedarse en silencio. |

Correcciones del modelo respecto a la Entrega 2 (hechas desde la Entrega 3):

1. **Prerrequisitos recursivos.** Antes eran un atributo suelto de `materia` (solo cabía uno). Ahora hay una tabla puente `materia_prerrequisito` (M:N de materia consigo misma) con PK compuesta, dos FK a `materia` y `CHECK (id_materia <> id_prerrequisito)`.
2. **Matrícula con FK a grupo.** Antes `matricula` solo se unía a `estudiante`; no se sabía en qué grupo estaba. Ahora tiene FK a `estudiante` y a `grupo`, más `UNIQUE (id_estudiante, id_grupo)`.
3. **Materia con FK a carrera.** Antes `carrera` estaba desconectada. Ahora `materia.id_carrera` es NOT NULL con FK a `carrera` (1:N).
4. **Cardinalidad Grupo–Materia.** Antes estaba como M:N. Ahora es 1:N: una FK `id_materia` en `grupo`, sin tabla intermedia.

Cambios posteriores (Entrega 4 y final):

5. **Reglas `ON DELETE` explícitas.** `RESTRICT` en materia, grupo y matrícula (no se borra lo que tiene historia académica); `CASCADE` en `materia_prerrequisito` (si se borra una materia, sus prerrequisitos ya no tienen sentido).
6. **Se quitó el índice redundante `idx_matricula_estudiante`.** El `UNIQUE (id_estudiante, id_grupo)` ya crea un índice que empieza por `id_estudiante`, así que el otro sobraba.
7. **Nuevo índice `idx_matricula_grupo` en `matricula(id_grupo)`.** Postgres no indexa las llaves foráneas. Esta columna se busca en cada matrícula (el trigger de cupo cuenta los inscritos del grupo) y en la consulta de ocupación de grupos; sin índice, las dos recorren toda la tabla `matricula`, que es la que más crece.
8. **Créditos pasan de `grupo` a `materia` (3NF).** Los créditos dependen de la materia, no del grupo (`id_materia → creditos`); guardarlos en `grupo` era una dependencia transitiva `id_grupo → id_materia → creditos`. Se movieron conservando los valores (todos los grupos de una misma materia ya tenían los mismos créditos); Ingeniería de Software y Aprendizaje Profundo, que no tenían grupos, quedaron con 3 créditos. La función `calcular_promedio_estudiante` y la vista `ranking_estudiantes` ahora los toman de `materia` y dan los mismos resultados.
9. **Nueva tabla `auditoria_calificacion`**, llenada por un trigger, para registrar cada cambio de nota.
10. **Lógica en la base:** 4 funciones, 1 procedimiento, 3 triggers y la vista `ranking_estudiantes` (detalle en `base_de_datos/diccionario_datos.md`).
11. **Datos ampliados:** 10 estudiantes, 10 materias, 3 semestres y 36 matrículas coherentes con los prerrequisitos.
