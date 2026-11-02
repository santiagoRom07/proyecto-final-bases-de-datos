# API del Caso Universidad: el único programa que habla con la base.
# Correr: .venv/bin/uvicorn main:app --reload   (y abrir http://127.0.0.1:8000/docs)
import os

import psycopg2
from psycopg2 import errors
from psycopg2.extras import RealDictCursor
from typing import Optional

from pydantic import BaseModel
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.routing import APIRoute
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()  # lee el .env (la contraseña nunca va escrita aquí)

conexion = psycopg2.connect(
    host=os.getenv("DB_HOST"),
    port=os.getenv("DB_PORT"),
    dbname=os.getenv("DB_NAME"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    cursor_factory=RealDictCursor,  # cada fila sale como diccionario -> JSON directo
)

app = FastAPI(title="API Caso Universidad")

# Permiso para que la página web (otro puerto) pueda leer las respuestas.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5500", "http://127.0.0.1:5500"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def escribir(sql, params):
    """Corre un INSERT/UPDATE/DELETE. Si la base lo rechaza, deshace (rollback)
    y lo traduce a un error que la app entiende."""
    try:
        with conexion.cursor() as cur:
            cur.execute(sql, params)
            fila = cur.fetchone()
        conexion.commit()
        return fila
    except errors.UniqueViolation:
        conexion.rollback()
        raise HTTPException(status_code=409, detail="Ese dato ya existe (está repetido)")
    except errors.ForeignKeyViolation as e:
        conexion.rollback()
        if "still referenced" in str(e):  # se intentó borrar algo que otros datos usan
            raise HTTPException(status_code=409, detail="No se puede borrar: otros datos dependen de este")
        raise HTTPException(status_code=409, detail="Un dato relacionado no existe (revisa el id)")
    except errors.CheckViolation:
        conexion.rollback()
        raise HTTPException(status_code=422, detail="Un valor está fuera del rango permitido")
    except errors.RaiseException as e:  # mensajes de los triggers (RAISE EXCEPTION)
        conexion.rollback()
        raise HTTPException(status_code=409, detail=e.diag.message_primary)
    except errors.DataError:  # texto muy largo o número que no cabe en la columna
        conexion.rollback()
        raise HTTPException(status_code=422, detail="Un valor es demasiado largo o grande")
    except psycopg2.Error:  # cualquier otro error: deshacer igual, o la API quedaría colgada
        conexion.rollback()
        raise


# ---------- CARRERA ----------
class Carrera(BaseModel):
    nombre_carrera: str

@app.get("/carreras")
def listar_carreras():
    with conexion.cursor() as cur:
        cur.execute("SELECT id_carrera, nombre_carrera FROM carrera ORDER BY id_carrera")
        return cur.fetchall()


@app.get("/carreras/{id_carrera}")
def obtener_carrera(id_carrera: int):
    with conexion.cursor() as cur:
        cur.execute("SELECT id_carrera, nombre_carrera FROM carrera WHERE id_carrera = %s", (id_carrera,))
        carrera = cur.fetchone()
    if carrera is None:
        raise HTTPException(status_code=404, detail="Esa carrera no existe")
    return carrera


@app.post("/carreras", status_code=201)
def crear_carrera(datos: Carrera):
    return escribir(
        "INSERT INTO carrera (nombre_carrera) VALUES (%s) RETURNING id_carrera, nombre_carrera",
        (datos.nombre_carrera,),
    )


@app.put("/carreras/{id_carrera}")
def editar_carrera(id_carrera: int, datos: Carrera):
    carrera = escribir(
        "UPDATE carrera SET nombre_carrera = %s WHERE id_carrera = %s RETURNING id_carrera, nombre_carrera",
        (datos.nombre_carrera, id_carrera),
    )
    if carrera is None:
        raise HTTPException(status_code=404, detail="Esa carrera no existe")
    return carrera


@app.delete("/carreras/{id_carrera}")
def borrar_carrera(id_carrera: int):
    carrera = escribir("DELETE FROM carrera WHERE id_carrera = %s RETURNING id_carrera, nombre_carrera", (id_carrera,))
    if carrera is None:
        raise HTTPException(status_code=404, detail="Esa carrera no existe")
    return {"mensaje": "Carrera borrada", "carrera": carrera}


# ---------- MATERIA (tiene llave foránea a carrera) ----------
class Materia(BaseModel):
    nombre_materia: str
    id_carrera: int
    creditos: int


@app.get("/materias")
def listar_materias():
    with conexion.cursor() as cur:
        cur.execute(
            """SELECT m.id_materia, m.nombre_materia, m.id_carrera, m.creditos, c.nombre_carrera
               FROM materia m JOIN carrera c ON c.id_carrera = m.id_carrera
               ORDER BY m.id_materia"""
        )
        return cur.fetchall()


@app.get("/materias/{id_materia}")
def obtener_materia(id_materia: int):
    with conexion.cursor() as cur:
        cur.execute("SELECT id_materia, nombre_materia, id_carrera, creditos FROM materia WHERE id_materia = %s", (id_materia,))
        materia = cur.fetchone()
    if materia is None:
        raise HTTPException(status_code=404, detail="Esa materia no existe")
    return materia


@app.post("/materias", status_code=201)
def crear_materia(datos: Materia):
    return escribir(
        "INSERT INTO materia (nombre_materia, id_carrera, creditos) VALUES (%s, %s, %s) RETURNING id_materia, nombre_materia, id_carrera, creditos",
        (datos.nombre_materia, datos.id_carrera, datos.creditos),
    )


@app.put("/materias/{id_materia}")
def editar_materia(id_materia: int, datos: Materia):
    materia = escribir(
        "UPDATE materia SET nombre_materia = %s, id_carrera = %s, creditos = %s WHERE id_materia = %s RETURNING id_materia, nombre_materia, id_carrera, creditos",
        (datos.nombre_materia, datos.id_carrera, datos.creditos, id_materia),
    )
    if materia is None:
        raise HTTPException(status_code=404, detail="Esa materia no existe")
    return materia


@app.delete("/materias/{id_materia}")
def borrar_materia(id_materia: int):
    materia = escribir("DELETE FROM materia WHERE id_materia = %s RETURNING id_materia, nombre_materia, id_carrera, creditos", (id_materia,))
    if materia is None:
        raise HTTPException(status_code=404, detail="Esa materia no existe")
    return {"mensaje": "Materia borrada", "materia": materia}


# ---------- ESTUDIANTE ----------
class Estudiante(BaseModel):
    nombre_estudiante: str
    correo_estudiante: str


@app.get("/estudiantes")
def listar_estudiantes():
    with conexion.cursor() as cur:
        cur.execute("SELECT id_estudiante, nombre_estudiante, correo_estudiante FROM estudiante ORDER BY id_estudiante")
        return cur.fetchall()


@app.get("/estudiantes/{id_estudiante}")
def obtener_estudiante(id_estudiante: int):
    with conexion.cursor() as cur:
        cur.execute("SELECT id_estudiante, nombre_estudiante, correo_estudiante FROM estudiante WHERE id_estudiante = %s", (id_estudiante,))
        estudiante = cur.fetchone()
    if estudiante is None:
        raise HTTPException(status_code=404, detail="Ese estudiante no existe")
    return estudiante


@app.post("/estudiantes", status_code=201)
def crear_estudiante(datos: Estudiante):
    return escribir(
        "INSERT INTO estudiante (nombre_estudiante, correo_estudiante) VALUES (%s, %s) RETURNING id_estudiante, nombre_estudiante, correo_estudiante",
        (datos.nombre_estudiante, datos.correo_estudiante),
    )


@app.put("/estudiantes/{id_estudiante}")
def editar_estudiante(id_estudiante: int, datos: Estudiante):
    estudiante = escribir(
        "UPDATE estudiante SET nombre_estudiante = %s, correo_estudiante = %s WHERE id_estudiante = %s RETURNING id_estudiante, nombre_estudiante, correo_estudiante",
        (datos.nombre_estudiante, datos.correo_estudiante, id_estudiante),
    )
    if estudiante is None:
        raise HTTPException(status_code=404, detail="Ese estudiante no existe")
    return estudiante


@app.delete("/estudiantes/{id_estudiante}")
def borrar_estudiante(id_estudiante: int):
    estudiante = escribir("DELETE FROM estudiante WHERE id_estudiante = %s RETURNING id_estudiante, nombre_estudiante, correo_estudiante", (id_estudiante,))
    if estudiante is None:
        raise HTTPException(status_code=404, detail="Ese estudiante no existe")
    return {"mensaje": "Estudiante borrado", "estudiante": estudiante}


# ---------- CONSULTAS DE NEGOCIO (JOIN + GROUP BY) ----------
@app.get("/consultas/rendimiento-materias")
def rendimiento_materias():
    """Promedio, nota máxima/mínima y reprobados por materia en semestres ya calificados."""
    with conexion.cursor() as cur:
        cur.execute(
            """SELECT m.nombre_materia, g.semestre,
                      COUNT(*)                                      AS estudiantes,
                      ROUND(AVG(mt.calificacion), 2)                AS promedio,
                      MAX(mt.calificacion)                          AS nota_maxima,
                      MIN(mt.calificacion)                          AS nota_minima,
                      COUNT(*) FILTER (WHERE mt.calificacion < 3.0) AS reprobados
               FROM matricula mt
               JOIN grupo   g ON g.id_grupo   = mt.id_grupo
               JOIN materia m ON m.id_materia = g.id_materia
               WHERE mt.calificacion IS NOT NULL AND g.semestre < '2026-1'
               GROUP BY m.nombre_materia, g.semestre
               ORDER BY promedio DESC"""
        )
        return cur.fetchall()


@app.get("/consultas/ocupacion-grupos")
def ocupacion_grupos():
    """Inscritos y cupos libres de cada grupo del semestre actual."""
    with conexion.cursor() as cur:
        cur.execute(
            """SELECT g.id_grupo, m.nombre_materia, p.nombre_profesor, g.cupo,
                      COUNT(mt.id_matricula)                            AS inscritos,
                      g.cupo - COUNT(mt.id_matricula)                   AS cupos_libres,
                      ROUND(100.0 * COUNT(mt.id_matricula) / g.cupo, 1) AS porcentaje_ocupacion
               FROM grupo g
               JOIN materia  m ON m.id_materia  = g.id_materia
               JOIN profesor p ON p.id_profesor = g.id_profesor
               LEFT JOIN matricula mt ON mt.id_grupo = g.id_grupo
               WHERE g.semestre = '2026-1'
               GROUP BY g.id_grupo, m.nombre_materia, p.nombre_profesor, g.cupo
               ORDER BY porcentaje_ocupacion DESC"""
        )
        return cur.fetchall()


# ---------- MATRÍCULA (aquí actúan los triggers de la base) ----------
class Matricula(BaseModel):
    id_estudiante: int
    id_grupo: int


class Calificacion(BaseModel):
    calificacion: Optional[float]  # vacía = todavía sin nota


@app.get("/matriculas")
def listar_matriculas():
    with conexion.cursor() as cur:
        cur.execute(
            """SELECT mt.id_matricula, e.nombre_estudiante, m.nombre_materia, g.semestre,
                      mt.calificacion, mt.id_estudiante, mt.id_grupo
               FROM matricula mt
               JOIN estudiante e ON e.id_estudiante = mt.id_estudiante
               JOIN grupo      g ON g.id_grupo      = mt.id_grupo
               JOIN materia    m ON m.id_materia    = g.id_materia
               ORDER BY mt.id_matricula"""
        )
        return cur.fetchall()


@app.post("/matriculas", status_code=201)
def matricular(datos: Matricula):
    # Los triggers T1 (cupo) y T2 (prerrequisitos) revisan antes de guardar;
    # si dicen que no, escribir() devuelve su mensaje como 409.
    return escribir(
        "INSERT INTO matricula (id_estudiante, id_grupo) VALUES (%s, %s) RETURNING id_matricula, calificacion, id_estudiante, id_grupo",
        (datos.id_estudiante, datos.id_grupo),
    )


@app.put("/matriculas/{id_matricula}/calificacion")
def calificar(id_matricula: int, datos: Calificacion):
    # El trigger T3 guarda la nota vieja y la nueva en auditoria_calificacion.
    matricula = escribir(
        "UPDATE matricula SET calificacion = %s WHERE id_matricula = %s RETURNING id_matricula, calificacion, id_estudiante, id_grupo",
        (datos.calificacion, id_matricula),
    )
    if matricula is None:
        raise HTTPException(status_code=404, detail="Esa matrícula no existe")
    return matricula


@app.delete("/matriculas/{id_matricula}")
def borrar_matricula(id_matricula: int):
    matricula = escribir("DELETE FROM matricula WHERE id_matricula = %s RETURNING id_matricula, calificacion, id_estudiante, id_grupo", (id_matricula,))
    if matricula is None:
        raise HTTPException(status_code=404, detail="Esa matrícula no existe")
    return {"mensaje": "Matrícula borrada", "matricula": matricula}


@app.get("/auditoria")
def ver_auditoria():
    """Historial de cambios de notas que llena el trigger T3."""
    with conexion.cursor() as cur:
        cur.execute("SELECT id_auditoria, id_matricula, nota_anterior, nota_nueva, usuario, fecha FROM auditoria_calificacion ORDER BY id_auditoria DESC")
        return cur.fetchall()


# ---------- Orden de /docs: agrupa los endpoints por tipo de acción ----------
GRUPOS = {"GET": "GET: leer", "POST": "POST: crear", "PUT": "PUT: editar", "DELETE": "DELETE: borrar"}
app.openapi_tags = [{"name": g} for g in GRUPOS.values()]
for ruta in app.routes:
    if isinstance(ruta, APIRoute):
        ruta.tags = [GRUPOS[next(iter(ruta.methods))]]
