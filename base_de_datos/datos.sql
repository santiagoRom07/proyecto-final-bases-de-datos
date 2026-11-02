--
-- PostgreSQL database dump
--

\restrict GJhGBKzER5b8cBWd2DfpKE13iIXngezLMJaJbd0cVP998Q9TjdeYaa8b0GIMy3q

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

-- Las matrículas guardadas ya son válidas: se apagan los triggers solo durante la carga.
ALTER TABLE public.matricula DISABLE TRIGGER USER;

--
-- Data for Name: auditoria_calificacion; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.auditoria_calificacion VALUES (1, 15, NULL, 3.8, 'postgres', '2026-09-30 20:14:38.781987');


--
-- Data for Name: carrera; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.carrera VALUES (1, 'Ingenieria de Sistemas');
INSERT INTO public.carrera VALUES (2, 'Ingenieria en Inteligencia Artificial');


--
-- Data for Name: estudiante; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.estudiante VALUES (1, 'Santiago Romero Viloria', 'santiago.romero@upb.edu.co');
INSERT INTO public.estudiante VALUES (2, 'Juan Pablo Quintero Carrillo', 'juanpablo.quintero@upb.edu.co');
INSERT INTO public.estudiante VALUES (3, 'Yamid Rafael Amaya Diaz', 'yamid.amaya@upb.edu.co');
INSERT INTO public.estudiante VALUES (4, 'Valeria Restrepo Gomez', 'valeria.restrepo@upb.edu.co');
INSERT INTO public.estudiante VALUES (5, 'Mateo Cardona Lopez', 'mateo.cardona@upb.edu.co');
INSERT INTO public.estudiante VALUES (6, 'Sara Echeverri Munoz', 'sara.echeverri@upb.edu.co');
INSERT INTO public.estudiante VALUES (7, 'Daniel Alzate Rios', 'daniel.alzate@upb.edu.co');
INSERT INTO public.estudiante VALUES (8, 'Isabela Montoya Arango', 'isabela.montoya@upb.edu.co');
INSERT INTO public.estudiante VALUES (9, 'Tomas Henao Zapata', 'tomas.henao@upb.edu.co');
INSERT INTO public.estudiante VALUES (10, 'Mariana Velez Castano', 'mariana.velez@upb.edu.co');


--
-- Data for Name: materia; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.materia VALUES (1, 'Algebra Lineal', 1);
INSERT INTO public.materia VALUES (2, 'Calculo Diferencial', 1);
INSERT INTO public.materia VALUES (3, 'Ingenieria de Software', 1);
INSERT INTO public.materia VALUES (4, 'Bases de Datos', 1);
INSERT INTO public.materia VALUES (5, 'Estructuras de Datos y Algoritmos', 1);
INSERT INTO public.materia VALUES (6, 'Programacion Orientada a Objetos', 1);
INSERT INTO public.materia VALUES (7, 'Fundamentos de Programacion', 1);
INSERT INTO public.materia VALUES (8, 'Aprendizaje Profundo', 2);
INSERT INTO public.materia VALUES (9, 'Aprendizaje Automatico', 2);
INSERT INTO public.materia VALUES (10, 'Estadistica y Probabilidad', 2);


--
-- Data for Name: profesor; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.profesor VALUES (1, 'Carlos Andres Vega');
INSERT INTO public.profesor VALUES (2, 'Maria Fernanda Torres');
INSERT INTO public.profesor VALUES (3, 'Ricardo Pineda Soto');
INSERT INTO public.profesor VALUES (4, 'Laura Milena Ospina');
INSERT INTO public.profesor VALUES (5, 'Andres Felipe Mejia');


--
-- Data for Name: grupo; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.grupo VALUES (1, 25, 3, '2025-2', 3, 1);
INSERT INTO public.grupo VALUES (2, 30, 4, '2025-1', 4, 2);
INSERT INTO public.grupo VALUES (3, 3, 4, '2026-1', 3, 2);
INSERT INTO public.grupo VALUES (4, 35, 3, '2026-1', 1, 4);
INSERT INTO public.grupo VALUES (5, 25, 4, '2026-1', 2, 5);
INSERT INTO public.grupo VALUES (6, 25, 4, '2025-2', 2, 6);
INSERT INTO public.grupo VALUES (7, 30, 3, '2025-1', 1, 7);
INSERT INTO public.grupo VALUES (8, 30, 3, '2026-1', 1, 7);
INSERT INTO public.grupo VALUES (9, 20, 4, '2026-1', 5, 9);
INSERT INTO public.grupo VALUES (10, 30, 3, '2025-2', 4, 10);


--
-- Data for Name: materia_prerrequisito; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.materia_prerrequisito VALUES (9, 1);
INSERT INTO public.materia_prerrequisito VALUES (10, 2);
INSERT INTO public.materia_prerrequisito VALUES (1, 2);
INSERT INTO public.materia_prerrequisito VALUES (3, 4);
INSERT INTO public.materia_prerrequisito VALUES (4, 5);
INSERT INTO public.materia_prerrequisito VALUES (5, 6);
INSERT INTO public.materia_prerrequisito VALUES (6, 7);
INSERT INTO public.materia_prerrequisito VALUES (8, 9);
INSERT INTO public.materia_prerrequisito VALUES (9, 10);


--
-- Data for Name: matricula; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.matricula VALUES (1, 4.0, 1, 1);
INSERT INTO public.matricula VALUES (2, 4.4, 4, 1);
INSERT INTO public.matricula VALUES (3, 3.2, 8, 1);
INSERT INTO public.matricula VALUES (4, 3.8, 10, 1);
INSERT INTO public.matricula VALUES (5, 3.9, 1, 2);
INSERT INTO public.matricula VALUES (6, 4.2, 4, 2);
INSERT INTO public.matricula VALUES (7, 2.8, 7, 2);
INSERT INTO public.matricula VALUES (8, 4.6, 8, 2);
INSERT INTO public.matricula VALUES (9, 3.5, 10, 2);
INSERT INTO public.matricula VALUES (10, 1.9, 9, 2);
INSERT INTO public.matricula VALUES (11, NULL, 7, 3);
INSERT INTO public.matricula VALUES (12, NULL, 9, 3);
INSERT INTO public.matricula VALUES (13, NULL, 2, 3);
INSERT INTO public.matricula VALUES (14, 4.0, 1, 5);
INSERT INTO public.matricula VALUES (16, 3.4, 6, 5);
INSERT INTO public.matricula VALUES (17, NULL, 9, 5);
INSERT INTO public.matricula VALUES (18, 4.3, 1, 6);
INSERT INTO public.matricula VALUES (19, 3.7, 2, 6);
INSERT INTO public.matricula VALUES (20, 4.1, 6, 6);
INSERT INTO public.matricula VALUES (21, 2.9, 3, 6);
INSERT INTO public.matricula VALUES (22, 3.4, 9, 6);
INSERT INTO public.matricula VALUES (23, 4.5, 1, 7);
INSERT INTO public.matricula VALUES (24, 4.0, 2, 7);
INSERT INTO public.matricula VALUES (25, 3.6, 3, 7);
INSERT INTO public.matricula VALUES (26, 2.4, 5, 7);
INSERT INTO public.matricula VALUES (27, 4.8, 6, 7);
INSERT INTO public.matricula VALUES (28, 3.1, 9, 7);
INSERT INTO public.matricula VALUES (29, NULL, 5, 8);
INSERT INTO public.matricula VALUES (30, 4.5, 4, 9);
INSERT INTO public.matricula VALUES (31, NULL, 8, 9);
INSERT INTO public.matricula VALUES (32, 3.5, 1, 10);
INSERT INTO public.matricula VALUES (33, 4.1, 4, 10);
INSERT INTO public.matricula VALUES (34, 3.7, 8, 10);
INSERT INTO public.matricula VALUES (35, 2.7, 10, 10);
INSERT INTO public.matricula VALUES (36, NULL, 1, 9);
INSERT INTO public.matricula VALUES (15, 3.8, 2, 5);


--
-- Name: auditoria_calificacion_id_auditoria_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auditoria_calificacion_id_auditoria_seq', 2, true);


--
-- Name: carrera_id_carrera_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.carrera_id_carrera_seq', 6, true);


--
-- Name: estudiante_id_estudiante_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.estudiante_id_estudiante_seq', 12, true);


--
-- Name: grupo_id_grupo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.grupo_id_grupo_seq', 10, true);


--
-- Name: materia_id_materia_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.materia_id_materia_seq', 12, true);


--
-- Name: matricula_id_matricula_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.matricula_id_matricula_seq', 49, true);


--
-- Name: profesor_id_profesor_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.profesor_id_profesor_seq', 5, true);


--
-- PostgreSQL database dump complete
--

\unrestrict GJhGBKzER5b8cBWd2DfpKE13iIXngezLMJaJbd0cVP998Q9TjdeYaa8b0GIMy3q


ALTER TABLE public.matricula ENABLE TRIGGER USER;
