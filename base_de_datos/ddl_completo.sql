-- ============================================================
-- Proyecto Final — Caso Universidad: DDL completo
-- Integrantes: Santiago Romero Viloria, Juan Pablo Quintero Carrillo,
--              Yamid Rafael Amaya Diaz
-- ============================================================
-- Qué hace: crea las 8 tablas con sus restricciones, las funciones,
--           el procedimiento, los triggers y la vista del caso.
-- Requisito: base "universidad" recién creada y vacía.
-- Cómo correrlo:
--   psql -d universidad -f ddl_completo.sql
--   y después: psql -d universidad -f datos.sql
-- ============================================================

-- ---------- TABLAS ----------
CREATE TABLE carrera (
  id_carrera     SERIAL       PRIMARY KEY,
  nombre_carrera VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE estudiante (
  id_estudiante     SERIAL       PRIMARY KEY,
  nombre_estudiante VARCHAR(100) NOT NULL,
  correo_estudiante VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE profesor (
  id_profesor     SERIAL       PRIMARY KEY,
  nombre_profesor VARCHAR(100) NOT NULL
);

-- ON DELETE RESTRICT: no se puede borrar una carrera que todavía tiene materias.
CREATE TABLE materia (
  id_materia     SERIAL       PRIMARY KEY,
  nombre_materia VARCHAR(100) NOT NULL,
  id_carrera     INT          NOT NULL REFERENCES carrera(id_carrera) ON DELETE RESTRICT
);

-- ON DELETE CASCADE: si se elimina una materia, sus relaciones de
-- prerrequisito dejan de tener sentido y se eliminan con ella.
CREATE TABLE materia_prerrequisito (
  id_materia       INT NOT NULL REFERENCES materia(id_materia) ON DELETE CASCADE,
  id_prerrequisito INT NOT NULL REFERENCES materia(id_materia) ON DELETE CASCADE,
  PRIMARY KEY (id_materia, id_prerrequisito),
  CONSTRAINT materia_no_es_su_propio_prerrequisito CHECK (id_materia <> id_prerrequisito)
);

-- ON DELETE RESTRICT: no se puede borrar un profesor o una materia
-- que tiene grupos abiertos (se perdería la historia académica).
CREATE TABLE grupo (
  id_grupo    SERIAL      PRIMARY KEY,
  cupo        INT         NOT NULL CONSTRAINT cupo_positivo CHECK (cupo > 0),
  creditos    INT         NOT NULL CONSTRAINT creditos_positivos CHECK (creditos > 0),
  semestre    VARCHAR(20) NOT NULL,
  id_profesor INT         NOT NULL REFERENCES profesor(id_profesor) ON DELETE RESTRICT,
  id_materia  INT         NOT NULL REFERENCES materia(id_materia) ON DELETE RESTRICT
);

-- ON DELETE RESTRICT: las notas son historia académica; no se borran
-- en cascada al eliminar un estudiante o un grupo.
CREATE TABLE matricula (
  id_matricula  SERIAL       PRIMARY KEY,
  calificacion  DECIMAL(3,1) CONSTRAINT calificacion_entre_0_y_5 CHECK (calificacion >= 0 AND calificacion <= 5),
  id_estudiante INT          NOT NULL REFERENCES estudiante(id_estudiante) ON DELETE RESTRICT,
  id_grupo      INT          NOT NULL REFERENCES grupo(id_grupo) ON DELETE RESTRICT,
  UNIQUE (id_estudiante, id_grupo)
);

-- Nota: no se crea idx_matricula_estudiante porque el índice de
-- UNIQUE (id_estudiante, id_grupo) ya cubre las búsquedas por id_estudiante.

-- ---------- FUNCIONES, PROCEDIMIENTO, TRIGGERS Y VISTA ----------
-- F1. Promedio, materias calificadas y créditos aprobados de un estudiante (parámetros IN/OUT)
CREATE OR REPLACE FUNCTION calcular_promedio_estudiante(
  IN  p_id_estudiante      INT,
  OUT promedio             DECIMAL(3,2),
  OUT materias_calificadas INT,
  OUT creditos_aprobados   INT
) AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM estudiante WHERE id_estudiante = p_id_estudiante) THEN
    RAISE EXCEPTION 'El estudiante no existe (recibido: %)', p_id_estudiante;
  END IF;

  SELECT ROUND(AVG(calificacion), 2), COUNT(calificacion)
    INTO promedio, materias_calificadas
    FROM matricula
   WHERE id_estudiante = p_id_estudiante;

  SELECT COALESCE(SUM(g.creditos), 0)
    INTO creditos_aprobados
    FROM matricula mt
    JOIN grupo g ON g.id_grupo = mt.id_grupo
   WHERE mt.id_estudiante = p_id_estudiante
     AND mt.calificacion >= 3.0;
END;
$$ LANGUAGE plpgsql;

-- F2. Cupos disponibles en un grupo
CREATE OR REPLACE FUNCTION contar_cupos_disponibles(p_id_grupo INT)
RETURNS INT AS $$
DECLARE
  v_cupo      INT;
  v_inscritos INT;
BEGIN
  SELECT cupo INTO v_cupo FROM grupo WHERE id_grupo = p_id_grupo;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El grupo no existe (recibido: %)', p_id_grupo;
  END IF;

  SELECT COUNT(*) INTO v_inscritos FROM matricula WHERE id_grupo = p_id_grupo;
  RETURN v_cupo - v_inscritos;
END;
$$ LANGUAGE plpgsql;

-- F3. Estado académico de un estudiante (ciclo FOR + IF/ELSIF)
CREATE OR REPLACE FUNCTION clasificar_estado_academico(p_id_estudiante INT)
RETURNS TEXT AS $$
DECLARE
  r           RECORD;
  v_aprobadas INT := 0;
  v_perdidas  INT := 0;
  v_en_curso  INT := 0;
  v_suma      DECIMAL := 0;
  v_promedio  DECIMAL(3,2);
  v_estado    TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM estudiante WHERE id_estudiante = p_id_estudiante) THEN
    RAISE EXCEPTION 'El estudiante no existe (recibido: %)', p_id_estudiante;
  END IF;

  FOR r IN SELECT calificacion FROM matricula WHERE id_estudiante = p_id_estudiante LOOP
    IF r.calificacion IS NULL THEN
      v_en_curso := v_en_curso + 1;
    ELSIF r.calificacion >= 3.0 THEN
      v_aprobadas := v_aprobadas + 1;
      v_suma := v_suma + r.calificacion;
    ELSE
      v_perdidas := v_perdidas + 1;
      v_suma := v_suma + r.calificacion;
    END IF;
  END LOOP;

  IF v_aprobadas + v_perdidas = 0 THEN
    RETURN 'Sin notas registradas (en curso: ' || v_en_curso || ')';
  END IF;

  v_promedio := ROUND(v_suma / (v_aprobadas + v_perdidas), 2);

  IF v_perdidas = 0 AND v_promedio >= 4.0 THEN
    v_estado := 'Excelente';
  ELSIF v_perdidas >= 2 OR v_promedio < 3.0 THEN
    v_estado := 'En riesgo';
  ELSE
    v_estado := 'Normal';
  END IF;

  RETURN format('%s | promedio %s | aprobadas %s | perdidas %s | en curso %s',
                v_estado, v_promedio, v_aprobadas, v_perdidas, v_en_curso);
END;
$$ LANGUAGE plpgsql;

-- F4. Materias que un estudiante puede matricular (tiene todos los prerrequisitos aprobados)
CREATE OR REPLACE FUNCTION listar_materias_habilitadas(p_id_estudiante INT)
RETURNS TABLE (materia_habilitada VARCHAR, carrera VARCHAR) AS $$
DECLARE
  r RECORD;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM estudiante WHERE id_estudiante = p_id_estudiante) THEN
    RAISE EXCEPTION 'El estudiante no existe (recibido: %)', p_id_estudiante;
  END IF;

  FOR r IN
    SELECT m.id_materia, m.nombre_materia, c.nombre_carrera
      FROM materia m
      JOIN carrera c ON c.id_carrera = m.id_carrera
     ORDER BY m.nombre_materia
  LOOP
    -- se salta si ya la aprobó o la está cursando
    CONTINUE WHEN EXISTS (
      SELECT 1 FROM matricula mt JOIN grupo g ON g.id_grupo = mt.id_grupo
       WHERE mt.id_estudiante = p_id_estudiante
         AND g.id_materia = r.id_materia
         AND (mt.calificacion IS NULL OR mt.calificacion >= 3.0));

    -- se incluye solo si no le falta ningún prerrequisito aprobado
    IF NOT EXISTS (
      SELECT 1 FROM materia_prerrequisito mp
       WHERE mp.id_materia = r.id_materia
         AND NOT EXISTS (
           SELECT 1 FROM matricula mt JOIN grupo g ON g.id_grupo = mt.id_grupo
            WHERE mt.id_estudiante = p_id_estudiante
              AND g.id_materia = mp.id_prerrequisito
              AND mt.calificacion >= 3.0))
    THEN
      materia_habilitada := r.nombre_materia;
      carrera := r.nombre_carrera;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- F5. Procedimiento para matricular a un estudiante por correo, materia y semestre
CREATE OR REPLACE PROCEDURE matricular_estudiante(
  p_correo   VARCHAR,
  p_materia  VARCHAR,
  p_semestre VARCHAR
) AS $$
DECLARE
  v_id_estudiante INT;
  v_id_grupo      INT;
BEGIN
  SELECT id_estudiante INTO v_id_estudiante
    FROM estudiante WHERE correo_estudiante = p_correo;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No existe un estudiante con ese correo (recibido: %)', p_correo;
  END IF;

  SELECT g.id_grupo INTO v_id_grupo
    FROM grupo g JOIN materia m ON m.id_materia = g.id_materia
   WHERE m.nombre_materia = p_materia AND g.semestre = p_semestre;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No hay grupo de % en el semestre %', p_materia, p_semestre;
  END IF;

  INSERT INTO matricula (calificacion, id_estudiante, id_grupo)
  VALUES (NULL, v_id_estudiante, v_id_grupo);

  RAISE NOTICE 'Matricula creada: % en % (%), grupo %',
               p_correo, p_materia, p_semestre, v_id_grupo;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El estudiante % ya esta matriculado en % (%)',
                    p_correo, p_materia, p_semestre;
END;
$$ LANGUAGE plpgsql;

-- T1. Qué hace: antes de insertar una matrícula, verifica que el grupo tenga cupo.
--     Por qué importa: sin esto, un grupo podría quedar con más estudiantes que su cupo.
CREATE OR REPLACE FUNCTION verificar_cupo_disponible()
RETURNS TRIGGER AS $$
BEGIN
  IF contar_cupos_disponibles(NEW.id_grupo) <= 0 THEN
    RAISE EXCEPTION 'El grupo ya no tiene cupos disponibles (grupo: %)', NEW.id_grupo;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validar_cupo_matricula
BEFORE INSERT ON matricula
FOR EACH ROW
EXECUTE FUNCTION verificar_cupo_disponible();

-- T2. Qué hace: antes de insertar una matrícula, verifica que el estudiante haya aprobado
--     (nota >= 3.0, en un semestre anterior) todos los prerrequisitos de la materia.
--     Por qué importa: sin esto, un estudiante podría ver una materia sin las bases necesarias.
CREATE OR REPLACE FUNCTION verificar_prerrequisitos_aprobados()
RETURNS TRIGGER AS $$
DECLARE
  v_id_materia INT;
  v_semestre   VARCHAR;
  r            RECORD;
  v_faltantes  TEXT := '';
  v_nombre     VARCHAR;
BEGIN
  SELECT id_materia, semestre INTO v_id_materia, v_semestre
    FROM grupo WHERE id_grupo = NEW.id_grupo;

  FOR r IN
    SELECT p.id_materia, p.nombre_materia
      FROM materia_prerrequisito mp
      JOIN materia p ON p.id_materia = mp.id_prerrequisito
     WHERE mp.id_materia = v_id_materia
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM matricula mt JOIN grupo g ON g.id_grupo = mt.id_grupo
       WHERE mt.id_estudiante = NEW.id_estudiante
         AND g.id_materia = r.id_materia
         AND g.semestre < v_semestre
         AND mt.calificacion >= 3.0)
    THEN
      v_faltantes := v_faltantes || CASE WHEN v_faltantes = '' THEN '' ELSE ', ' END || r.nombre_materia;
    END IF;
  END LOOP;

  IF v_faltantes <> '' THEN
    SELECT nombre_estudiante INTO v_nombre
      FROM estudiante WHERE id_estudiante = NEW.id_estudiante;
    RAISE EXCEPTION '% no ha aprobado los prerrequisitos: %', v_nombre, v_faltantes;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validar_prerrequisitos_matricula
BEFORE INSERT ON matricula
FOR EACH ROW
EXECUTE FUNCTION verificar_prerrequisitos_aprobados();

-- T3. Qué hace: después de cambiar una calificación, guarda la nota anterior, la nueva,
--     el usuario y la fecha en auditoria_calificacion.
--     Por qué importa: sin esto, no habría forma de saber quién cambió una nota ni cuándo.
CREATE TABLE auditoria_calificacion (
  id_auditoria  SERIAL       PRIMARY KEY,
  id_matricula  INT          NOT NULL,
  nota_anterior DECIMAL(3,1),
  nota_nueva    DECIMAL(3,1),
  usuario       TEXT         NOT NULL DEFAULT current_user,
  fecha         TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION registrar_cambio_calificacion()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO auditoria_calificacion (id_matricula, nota_anterior, nota_nueva)
  VALUES (NEW.id_matricula, OLD.calificacion, NEW.calificacion);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auditar_cambio_calificacion
AFTER UPDATE OF calificacion ON matricula
FOR EACH ROW
WHEN (OLD.calificacion IS DISTINCT FROM NEW.calificacion)
EXECUTE FUNCTION registrar_cambio_calificacion();

-- BONO 2. Vista: ranking de estudiantes por promedio (solo materias calificadas)
CREATE OR REPLACE VIEW ranking_estudiantes AS
SELECT RANK() OVER (ORDER BY ROUND(AVG(mt.calificacion), 2) DESC) AS puesto,
       e.nombre_estudiante,
       COUNT(mt.calificacion)                                   AS materias_calificadas,
       ROUND(AVG(mt.calificacion), 2)                           AS promedio,
       COALESCE(SUM(g.creditos) FILTER (WHERE mt.calificacion >= 3.0), 0) AS creditos_aprobados
FROM estudiante e
JOIN matricula mt ON mt.id_estudiante = e.id_estudiante
JOIN grupo g      ON g.id_grupo       = mt.id_grupo
WHERE mt.calificacion IS NOT NULL
GROUP BY e.id_estudiante, e.nombre_estudiante;
