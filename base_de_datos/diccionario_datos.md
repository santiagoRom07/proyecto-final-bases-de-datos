# Diccionario de datos — Caso Universidad

Base: `universidad` (PostgreSQL). 8 tablas, 1 vista, 4 funciones, 1 procedimiento y 3 triggers.

## carrera
Programas académicos de la universidad.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_carrera | SERIAL | PK | Identificador de la carrera |
| nombre_carrera | VARCHAR(100) | NOT NULL, UNIQUE | Nombre del programa |

## estudiante
| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_estudiante | SERIAL | PK | Identificador del estudiante |
| nombre_estudiante | VARCHAR(100) | NOT NULL | Nombre completo |
| correo_estudiante | VARCHAR(150) | NOT NULL, UNIQUE | Correo institucional |

## profesor
| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_profesor | SERIAL | PK | Identificador del profesor |
| nombre_profesor | VARCHAR(100) | NOT NULL | Nombre completo |

## materia
| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_materia | SERIAL | PK | Identificador de la materia |
| nombre_materia | VARCHAR(100) | NOT NULL | Nombre de la materia |
| id_carrera | INT | NOT NULL, FK → carrera (ON DELETE RESTRICT) | Carrera a la que pertenece |
| creditos | INT | NOT NULL, CHECK > 0 | Créditos de la materia (dependen de la materia, no del grupo: 3NF) |

## materia_prerrequisito
Relación M:N de `materia` consigo misma: qué materias hay que aprobar antes de otra.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_materia | INT | PK compuesta, FK → materia (ON DELETE CASCADE) | Materia que exige el prerrequisito |
| id_prerrequisito | INT | PK compuesta, FK → materia (ON DELETE CASCADE) | Materia que debe estar aprobada |

CHECK: `id_materia <> id_prerrequisito` (una materia no es prerrequisito de sí misma).

## grupo
Una oferta concreta de una materia en un semestre.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_grupo | SERIAL | PK | Identificador del grupo |
| cupo | INT | NOT NULL, CHECK > 0 | Máximo de estudiantes |
| semestre | VARCHAR(20) | NOT NULL | Periodo, p. ej. `2026-1` |
| id_profesor | INT | NOT NULL, FK → profesor (ON DELETE RESTRICT) | Profesor que lo dicta |
| id_materia | INT | NOT NULL, FK → materia (ON DELETE RESTRICT) | Materia que se dicta |

## matricula
Inscripción de un estudiante en un grupo y su nota.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_matricula | SERIAL | PK | Identificador de la matrícula |
| calificacion | NUMERIC(3,1) | CHECK entre 0 y 5, admite NULL | Nota final; NULL = curso en desarrollo |
| id_estudiante | INT | NOT NULL, FK → estudiante (ON DELETE RESTRICT) | Estudiante inscrito |
| id_grupo | INT | NOT NULL, FK → grupo (ON DELETE RESTRICT) | Grupo donde se inscribió |

UNIQUE: `(id_estudiante, id_grupo)` (no se matricula dos veces en el mismo grupo).

Índice: `idx_matricula_grupo` sobre `id_grupo` (lo usan el trigger de cupo y la consulta de ocupación de grupos).

## auditoria_calificacion
Historial de cambios de nota. La llena el trigger `auditar_cambio_calificacion`; nadie escribe aquí a mano.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_auditoria | SERIAL | PK | Identificador del registro |
| id_matricula | INT | NOT NULL | Matrícula cuya nota cambió (sin FK, para conservar el historial aunque se borre la matrícula) |
| nota_anterior | NUMERIC(3,1) | — | Nota antes del cambio |
| nota_nueva | NUMERIC(3,1) | — | Nota después del cambio |
| usuario | TEXT | NOT NULL, DEFAULT CURRENT_USER | Usuario de la base que hizo el cambio |
| fecha | TIMESTAMP | NOT NULL, DEFAULT now() | Momento del cambio |

## Lógica en la base

| Objeto | Tipo | Qué hace |
|---|---|---|
| validar_cupo_matricula | Trigger BEFORE INSERT en matricula | Rechaza la matrícula si el grupo ya está lleno |
| validar_prerrequisitos_matricula | Trigger BEFORE INSERT en matricula | Rechaza la matrícula si el estudiante no aprobó (≥ 3.0) los prerrequisitos |
| auditar_cambio_calificacion | Trigger AFTER UPDATE OF calificacion | Guarda nota anterior y nueva en auditoria_calificacion |
| calcular_promedio_estudiante(id) | Función | Promedio, materias calificadas y créditos aprobados |
| contar_cupos_disponibles(id_grupo) | Función | Cupos libres de un grupo |
| clasificar_estado_academico(id) | Función | Clasifica al estudiante como Excelente, Normal o En riesgo |
| listar_materias_habilitadas(id) | Función | Materias que el estudiante ya puede cursar |
| matricular_estudiante(correo, materia, semestre) | Procedimiento | Matricula buscando por correo y nombre de materia |
| ranking_estudiantes | Vista | Puesto de cada estudiante por promedio, con créditos aprobados |
