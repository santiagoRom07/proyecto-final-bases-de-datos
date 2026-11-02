--
-- PostgreSQL database dump
--

\restrict Hx1nWLtdFbfgJMhq7bWaaN4WArHBdEpFS7odEBtXnzASTFkcUmtldsaJa3so2g5

-- Dumped from database version 16.15 (Homebrew)
-- Dumped by pg_dump version 16.15 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: calcular_promedio_estudiante(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calcular_promedio_estudiante(p_id_estudiante integer, OUT promedio numeric, OUT materias_calificadas integer, OUT creditos_aprobados integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: clasificar_estado_academico(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clasificar_estado_academico(p_id_estudiante integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: contar_cupos_disponibles(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contar_cupos_disponibles(p_id_grupo integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: listar_materias_habilitadas(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.listar_materias_habilitadas(p_id_estudiante integer) RETURNS TABLE(materia_habilitada character varying, carrera character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: matricular_estudiante(character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.matricular_estudiante(IN p_correo character varying, IN p_materia character varying, IN p_semestre character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: registrar_cambio_calificacion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_cambio_calificacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO auditoria_calificacion (id_matricula, nota_anterior, nota_nueva)
  VALUES (NEW.id_matricula, OLD.calificacion, NEW.calificacion);
  RETURN NULL;
END;
$$;


--
-- Name: verificar_cupo_disponible(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verificar_cupo_disponible() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF contar_cupos_disponibles(NEW.id_grupo) <= 0 THEN
    RAISE EXCEPTION 'El grupo ya no tiene cupos disponibles (grupo: %)', NEW.id_grupo;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: verificar_prerrequisitos_aprobados(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verificar_prerrequisitos_aprobados() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auditoria_calificacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auditoria_calificacion (
    id_auditoria integer NOT NULL,
    id_matricula integer NOT NULL,
    nota_anterior numeric(3,1),
    nota_nueva numeric(3,1),
    usuario text DEFAULT CURRENT_USER NOT NULL,
    fecha timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: auditoria_calificacion_id_auditoria_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auditoria_calificacion_id_auditoria_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auditoria_calificacion_id_auditoria_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auditoria_calificacion_id_auditoria_seq OWNED BY public.auditoria_calificacion.id_auditoria;


--
-- Name: carrera; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carrera (
    id_carrera integer NOT NULL,
    nombre_carrera character varying(100) NOT NULL
);


--
-- Name: carrera_id_carrera_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.carrera_id_carrera_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: carrera_id_carrera_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.carrera_id_carrera_seq OWNED BY public.carrera.id_carrera;


--
-- Name: estudiante; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estudiante (
    id_estudiante integer NOT NULL,
    nombre_estudiante character varying(100) NOT NULL,
    correo_estudiante character varying(150) NOT NULL
);


--
-- Name: estudiante_id_estudiante_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.estudiante_id_estudiante_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: estudiante_id_estudiante_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.estudiante_id_estudiante_seq OWNED BY public.estudiante.id_estudiante;


--
-- Name: grupo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grupo (
    id_grupo integer NOT NULL,
    cupo integer NOT NULL,
    creditos integer NOT NULL,
    semestre character varying(20) NOT NULL,
    id_profesor integer NOT NULL,
    id_materia integer NOT NULL,
    CONSTRAINT creditos_positivos CHECK ((creditos > 0)),
    CONSTRAINT cupo_positivo CHECK ((cupo > 0))
);


--
-- Name: grupo_id_grupo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grupo_id_grupo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grupo_id_grupo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grupo_id_grupo_seq OWNED BY public.grupo.id_grupo;


--
-- Name: materia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.materia (
    id_materia integer NOT NULL,
    nombre_materia character varying(100) NOT NULL,
    id_carrera integer NOT NULL
);


--
-- Name: materia_id_materia_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.materia_id_materia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: materia_id_materia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.materia_id_materia_seq OWNED BY public.materia.id_materia;


--
-- Name: materia_prerrequisito; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.materia_prerrequisito (
    id_materia integer NOT NULL,
    id_prerrequisito integer NOT NULL,
    CONSTRAINT materia_no_es_su_propio_prerrequisito CHECK ((id_materia <> id_prerrequisito))
);


--
-- Name: matricula; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matricula (
    id_matricula integer NOT NULL,
    calificacion numeric(3,1),
    id_estudiante integer NOT NULL,
    id_grupo integer NOT NULL,
    CONSTRAINT calificacion_entre_0_y_5 CHECK (((calificacion >= (0)::numeric) AND (calificacion <= (5)::numeric)))
);


--
-- Name: matricula_id_matricula_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.matricula_id_matricula_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matricula_id_matricula_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.matricula_id_matricula_seq OWNED BY public.matricula.id_matricula;


--
-- Name: profesor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profesor (
    id_profesor integer NOT NULL,
    nombre_profesor character varying(100) NOT NULL
);


--
-- Name: profesor_id_profesor_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.profesor_id_profesor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: profesor_id_profesor_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.profesor_id_profesor_seq OWNED BY public.profesor.id_profesor;


--
-- Name: ranking_estudiantes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.ranking_estudiantes AS
 SELECT rank() OVER (ORDER BY (round(avg(mt.calificacion), 2)) DESC) AS puesto,
    e.nombre_estudiante,
    count(mt.calificacion) AS materias_calificadas,
    round(avg(mt.calificacion), 2) AS promedio,
    COALESCE(sum(g.creditos) FILTER (WHERE (mt.calificacion >= 3.0)), (0)::bigint) AS creditos_aprobados
   FROM ((public.estudiante e
     JOIN public.matricula mt ON ((mt.id_estudiante = e.id_estudiante)))
     JOIN public.grupo g ON ((g.id_grupo = mt.id_grupo)))
  WHERE (mt.calificacion IS NOT NULL)
  GROUP BY e.id_estudiante, e.nombre_estudiante;


--
-- Name: auditoria_calificacion id_auditoria; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_calificacion ALTER COLUMN id_auditoria SET DEFAULT nextval('public.auditoria_calificacion_id_auditoria_seq'::regclass);


--
-- Name: carrera id_carrera; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrera ALTER COLUMN id_carrera SET DEFAULT nextval('public.carrera_id_carrera_seq'::regclass);


--
-- Name: estudiante id_estudiante; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estudiante ALTER COLUMN id_estudiante SET DEFAULT nextval('public.estudiante_id_estudiante_seq'::regclass);


--
-- Name: grupo id_grupo; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grupo ALTER COLUMN id_grupo SET DEFAULT nextval('public.grupo_id_grupo_seq'::regclass);


--
-- Name: materia id_materia; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materia ALTER COLUMN id_materia SET DEFAULT nextval('public.materia_id_materia_seq'::regclass);


--
-- Name: matricula id_matricula; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula ALTER COLUMN id_matricula SET DEFAULT nextval('public.matricula_id_matricula_seq'::regclass);


--
-- Name: profesor id_profesor; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profesor ALTER COLUMN id_profesor SET DEFAULT nextval('public.profesor_id_profesor_seq'::regclass);


--
-- Name: auditoria_calificacion auditoria_calificacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_calificacion
    ADD CONSTRAINT auditoria_calificacion_pkey PRIMARY KEY (id_auditoria);


--
-- Name: carrera carrera_nombre_carrera_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrera
    ADD CONSTRAINT carrera_nombre_carrera_key UNIQUE (nombre_carrera);


--
-- Name: carrera carrera_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrera
    ADD CONSTRAINT carrera_pkey PRIMARY KEY (id_carrera);


--
-- Name: estudiante estudiante_correo_estudiante_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estudiante
    ADD CONSTRAINT estudiante_correo_estudiante_key UNIQUE (correo_estudiante);


--
-- Name: estudiante estudiante_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estudiante
    ADD CONSTRAINT estudiante_pkey PRIMARY KEY (id_estudiante);


--
-- Name: grupo grupo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT grupo_pkey PRIMARY KEY (id_grupo);


--
-- Name: materia materia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materia
    ADD CONSTRAINT materia_pkey PRIMARY KEY (id_materia);


--
-- Name: materia_prerrequisito materia_prerrequisito_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materia_prerrequisito
    ADD CONSTRAINT materia_prerrequisito_pkey PRIMARY KEY (id_materia, id_prerrequisito);


--
-- Name: matricula matricula_id_estudiante_id_grupo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_id_estudiante_id_grupo_key UNIQUE (id_estudiante, id_grupo);


--
-- Name: matricula matricula_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_pkey PRIMARY KEY (id_matricula);


--
-- Name: profesor profesor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profesor
    ADD CONSTRAINT profesor_pkey PRIMARY KEY (id_profesor);


--
-- Name: matricula auditar_cambio_calificacion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER auditar_cambio_calificacion AFTER UPDATE OF calificacion ON public.matricula FOR EACH ROW WHEN ((old.calificacion IS DISTINCT FROM new.calificacion)) EXECUTE FUNCTION public.registrar_cambio_calificacion();


--
-- Name: matricula validar_cupo_matricula; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validar_cupo_matricula BEFORE INSERT ON public.matricula FOR EACH ROW EXECUTE FUNCTION public.verificar_cupo_disponible();


--
-- Name: matricula validar_prerrequisitos_matricula; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validar_prerrequisitos_matricula BEFORE INSERT ON public.matricula FOR EACH ROW EXECUTE FUNCTION public.verificar_prerrequisitos_aprobados();


--
-- Name: grupo grupo_id_materia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT grupo_id_materia_fkey FOREIGN KEY (id_materia) REFERENCES public.materia(id_materia) ON DELETE RESTRICT;


--
-- Name: grupo grupo_id_profesor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT grupo_id_profesor_fkey FOREIGN KEY (id_profesor) REFERENCES public.profesor(id_profesor) ON DELETE RESTRICT;


--
-- Name: materia materia_id_carrera_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materia
    ADD CONSTRAINT materia_id_carrera_fkey FOREIGN KEY (id_carrera) REFERENCES public.carrera(id_carrera) ON DELETE RESTRICT;


--
-- Name: materia_prerrequisito materia_prerrequisito_id_materia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materia_prerrequisito
    ADD CONSTRAINT materia_prerrequisito_id_materia_fkey FOREIGN KEY (id_materia) REFERENCES public.materia(id_materia) ON DELETE CASCADE;


--
-- Name: materia_prerrequisito materia_prerrequisito_id_prerrequisito_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materia_prerrequisito
    ADD CONSTRAINT materia_prerrequisito_id_prerrequisito_fkey FOREIGN KEY (id_prerrequisito) REFERENCES public.materia(id_materia) ON DELETE CASCADE;


--
-- Name: matricula matricula_id_estudiante_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_id_estudiante_fkey FOREIGN KEY (id_estudiante) REFERENCES public.estudiante(id_estudiante) ON DELETE RESTRICT;


--
-- Name: matricula matricula_id_grupo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_id_grupo_fkey FOREIGN KEY (id_grupo) REFERENCES public.grupo(id_grupo) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict Hx1nWLtdFbfgJMhq7bWaaN4WArHBdEpFS7odEBtXnzASTFkcUmtldsaJa3so2g5

