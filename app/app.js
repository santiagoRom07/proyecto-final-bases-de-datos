// La app solo habla con la API por HTTP (fetch). Nunca toca la base directamente.
const API = "http://127.0.0.1:8000";

// ---------- Hablar con la API ----------
async function pedir(metodo, ruta, datos) {
  let respuesta;
  try {
    respuesta = await fetch(API + ruta, {
      method: metodo,
      headers: { "Content-Type": "application/json" },
      body: datos ? JSON.stringify(datos) : undefined,
    });
  } catch {
    throw new Error("No hay conexión con la API. ¿Está prendida?");
  }
  const cuerpo = await respuesta.json().catch(() => null);
  if (!respuesta.ok) {
    // FastAPI manda un texto (nuestros errores) o una lista (datos mal llenados).
    const detalle = cuerpo && cuerpo.detail;
    throw new Error(typeof detalle === "string" ? detalle : "Revisa el formulario: falta un dato o tiene un formato incorrecto");
  }
  return cuerpo;
}

function avisar(texto, tipo) {
  const aviso = document.getElementById("aviso");
  aviso.textContent = texto;
  aviso.className = tipo;
}

// Crea un elemento HTML. Usa textContent, así los datos nunca se ejecutan como código.
function el(etiqueta, props = {}, ...hijos) {
  const nodo = Object.assign(document.createElement(etiqueta), props);
  for (const h of hijos) nodo.append(h);
  return nodo;
}

function tabla(filas, columnas, acciones) {
  if (filas.length === 0) return el("p", { textContent: "No hay datos." });
  const t = el("table");
  t.append(el("tr", {}, ...columnas.map(([, titulo]) => el("th", { textContent: titulo })), ...(acciones ? [el("th")] : [])));
  for (const fila of filas) {
    const tr = el("tr", {}, ...columnas.map(([campo]) => el("td", { textContent: fila[campo] ?? "—" })));
    if (acciones) tr.append(el("td", {}, ...acciones(fila)));
    t.append(tr);
  }
  return el("div", { className: "tabla" }, t);
}

async function opciones(ruta, valor, texto) {
  const filas = await pedir("GET", ruta);
  return filas.map((f) => el("option", { value: f[valor], textContent: texto(f) }));
}

// ---------- Pantallas CRUD (carrera, materia, estudiante) ----------
const tablas = {
  carreras: {
    titulo: "Carreras", id: "id_carrera",
    campos: [{ nombre: "nombre_carrera", etiqueta: "Nombre" }],
    columnas: [["id_carrera", "ID"], ["nombre_carrera", "Nombre"]],
  },
  materias: {
    titulo: "Materias", id: "id_materia",
    campos: [
      { nombre: "nombre_materia", etiqueta: "Nombre" },
      { nombre: "id_carrera", etiqueta: "Carrera", numero: true,
        opciones: () => opciones("/carreras", "id_carrera", (c) => c.nombre_carrera) },
      { nombre: "creditos", etiqueta: "Créditos", tipo: "number", numero: true },
    ],
    columnas: [["id_materia", "ID"], ["nombre_materia", "Nombre"], ["nombre_carrera", "Carrera"], ["creditos", "Créditos"]],
  },
  estudiantes: {
    titulo: "Estudiantes", id: "id_estudiante",
    campos: [
      { nombre: "nombre_estudiante", etiqueta: "Nombre" },
      { nombre: "correo_estudiante", etiqueta: "Correo", tipo: "email" },
    ],
    columnas: [["id_estudiante", "ID"], ["nombre_estudiante", "Nombre"], ["correo_estudiante", "Correo"]],
  },
};

async function pantallaCrud(ruta) {
  const cfg = tablas[ruta];
  let editando = null; // id de la fila que se está editando, o null si se está creando

  const entradas = {};
  const form = el("form");
  for (const c of cfg.campos) {
    const entrada = c.opciones
      ? el("select", { name: c.nombre, required: true }, ...(await c.opciones()))
      : el("input", { name: c.nombre, type: c.tipo || "text", required: true });
    entradas[c.nombre] = entrada;
    form.append(el("label", {}, c.etiqueta, entrada));
  }
  const botonGuardar = el("button", { type: "submit", textContent: "Crear" });
  const botonCancelar = el("button", { type: "button", className: "secundario", textContent: "Cancelar", hidden: true });
  form.append(botonGuardar, botonCancelar);

  function modoCrear() {
    editando = null;
    form.reset();
    botonGuardar.textContent = "Crear";
    botonCancelar.hidden = true;
  }
  botonCancelar.onclick = modoCrear;

  form.onsubmit = async (evento) => {
    evento.preventDefault();
    const datos = {};
    for (const c of cfg.campos) datos[c.nombre] = c.numero ? Number(entradas[c.nombre].value) : entradas[c.nombre].value.trim();
    try {
      if (editando === null) await pedir("POST", "/" + ruta, datos);
      else await pedir("PUT", `/${ruta}/${editando}`, datos);
      avisar(editando === null ? "Creado correctamente" : "Cambios guardados", "ok");
      modoCrear();
      await pintarLista();
    } catch (e) { avisar(e.message, "error"); }
  };

  const lista = el("div");
  async function pintarLista() {
    const filas = await pedir("GET", "/" + ruta);
    lista.replaceChildren(tabla(filas, cfg.columnas, (fila) => [
      el("button", { textContent: "Editar", onclick: () => {
        editando = fila[cfg.id];
        for (const c of cfg.campos) entradas[c.nombre].value = fila[c.nombre];
        botonGuardar.textContent = "Guardar cambios";
        botonCancelar.hidden = false;
        window.scrollTo(0, 0);
      } }),
      " ",
      el("button", { className: "peligro", textContent: "Borrar", onclick: async () => {
        if (!confirm("¿Seguro que quieres borrar este registro?")) return;
        try {
          await pedir("DELETE", `/${ruta}/${fila[cfg.id]}`);
          avisar("Borrado correctamente", "ok");
          await pintarLista();
        } catch (e) { avisar(e.message, "error"); }
      } }),
    ]));
  }
  await pintarLista();
  return [el("h2", { textContent: cfg.titulo }), form, lista];
}

// ---------- Matrículas (aquí responden los triggers) ----------
async function pantallaMatriculas() {
  const estudiante = el("select", { required: true }, ...(await opciones("/estudiantes", "id_estudiante", (e) => e.nombre_estudiante)));
  const grupo = el("select", { required: true }, ...(await opciones("/consultas/ocupacion-grupos", "id_grupo",
    (g) => `${g.nombre_materia} (grupo ${g.id_grupo}, ${g.cupos_libres} cupos libres)`)));
  const form = el("form", {},
    el("label", {}, "Estudiante", estudiante),
    el("label", {}, "Grupo 2026-1", grupo),
    el("button", { type: "submit", textContent: "Matricular" }));
  form.onsubmit = async (evento) => {
    evento.preventDefault();
    try {
      await pedir("POST", "/matriculas", { id_estudiante: Number(estudiante.value), id_grupo: Number(grupo.value) });
      avisar("Matrícula creada", "ok");
      mostrar("matriculas");
    } catch (e) { avisar(e.message, "error"); }
  };

  const filas = await pedir("GET", "/matriculas");
  const lista = tabla(filas,
    [["id_matricula", "ID"], ["nombre_estudiante", "Estudiante"], ["nombre_materia", "Materia"], ["semestre", "Semestre"], ["calificacion", "Nota"]],
    (fila) => {
      const nota = el("input", { type: "number", step: "0.1", value: fila.calificacion ?? "" });
      return [
        nota, " ",
        el("button", { textContent: "Guardar nota", onclick: async () => {
          try {
            await pedir("PUT", `/matriculas/${fila.id_matricula}/calificacion`, { calificacion: nota.value === "" ? null : Number(nota.value) });
            avisar("Nota guardada (quedó registrada en la auditoría)", "ok");
            mostrar("matriculas");
          } catch (e) { avisar(e.message, "error"); }
        } }),
        " ",
        el("button", { className: "peligro", textContent: "Borrar", onclick: async () => {
          if (!confirm("¿Seguro que quieres borrar esta matrícula?")) return;
          try {
            await pedir("DELETE", `/matriculas/${fila.id_matricula}`);
            avisar("Matrícula borrada", "ok");
            mostrar("matriculas");
          } catch (e) { avisar(e.message, "error"); }
        } }),
      ];
    });
  return [el("h2", { textContent: "Matrículas" }), form, lista];
}

// ---------- Consultas y auditoría (solo lectura) ----------
async function pantallaConsultas() {
  const rendimiento = await pedir("GET", "/consultas/rendimiento-materias");
  const ocupacion = await pedir("GET", "/consultas/ocupacion-grupos");
  return [
    el("h2", { textContent: "Rendimiento por materia (semestres calificados)" }),
    tabla(rendimiento, [["nombre_materia", "Materia"], ["semestre", "Semestre"], ["estudiantes", "Estudiantes"], ["promedio", "Promedio"],
      ["nota_maxima", "Nota máx."], ["nota_minima", "Nota mín."], ["reprobados", "Reprobados"]]),
    el("h2", { textContent: "Ocupación de grupos 2026-1" }),
    tabla(ocupacion, [["id_grupo", "Grupo"], ["nombre_materia", "Materia"], ["nombre_profesor", "Profesor"], ["cupo", "Cupo"],
      ["inscritos", "Inscritos"], ["cupos_libres", "Libres"], ["porcentaje_ocupacion", "% ocupación"]]),
  ];
}

async function pantallaAuditoria() {
  const filas = await pedir("GET", "/auditoria");
  return [
    el("h2", { textContent: "Auditoría de notas" }),
    el("p", { textContent: "Cada cambio de nota lo registra automáticamente un trigger de la base." }),
    tabla(filas, [["id_auditoria", "ID"], ["id_matricula", "Matrícula"], ["nota_anterior", "Nota anterior"], ["nota_nueva", "Nota nueva"],
      ["usuario", "Usuario"], ["fecha", "Fecha"]]),
  ];
}

// ---------- Menú ----------
const pantallas = {
  carreras: ["Carreras", () => pantallaCrud("carreras")],
  materias: ["Materias", () => pantallaCrud("materias")],
  estudiantes: ["Estudiantes", () => pantallaCrud("estudiantes")],
  matriculas: ["Matrículas", pantallaMatriculas],
  consultas: ["Consultas", pantallaConsultas],
  auditoria: ["Auditoría", pantallaAuditoria],
};

async function mostrar(nombre) {
  for (const b of document.querySelectorAll("nav button")) b.classList.toggle("activo", b.dataset.p === nombre);
  try {
    document.getElementById("contenido").replaceChildren(...(await pantallas[nombre][1]()));
  } catch (e) { avisar(e.message, "error"); }
}

for (const [clave, [titulo]] of Object.entries(pantallas)) {
  const boton = el("button", { textContent: titulo, onclick: () => { avisar("", ""); mostrar(clave); } });
  boton.dataset.p = clave;
  document.getElementById("menu").append(boton);
}
mostrar("carreras");
