// Cliente de truco que en vez de un humano usa un LLM (API de Groq) para decidir
// cada jugada. Se conecta al mismo WebSocket que cliente.html y cliente.pl, así que el
// servidor (servidor.pl) no nota ninguna diferencia: para él es "otro jugador" más.
//
// Instalación:
//   npm install ws openai
//
// Conseguir API key: https://console.groq.com/keys (ya esta puesta la key en el .env)
//
// Uso: node cliente_ia.js

import 'dotenv/config';
import WebSocket from "ws";
import OpenAI from "openai";

const SERVIDOR_WS = "ws://localhost:8316/ws";
const NOMBRE_IA = process.env.NOMBRE_IA;

const MODELO = "llama-3.3-70b-versatile";

const groq = new OpenAI({
  apiKey: process.env.GROQ_API_KEY,
  baseURL: "https://api.groq.com/openai/v1",
});
 
const REGLAS = `Sos un jugador experto de truco argentino para 2 jugadores.
Vas a recibir el mensaje que te manda el servidor de juego con la situación actual.
Respondé ÚNICAMENTE con la jugada elegida, en el formato exacto que se pide, sin
explicaciones, sin saludos, sin texto adicional. Reglas de formato:
- Las opciones de menú numeradas se responden con el número y un punto. Ej: 1.
- Sí/No (envido, truco) se responde con y. (quiero) o n. (no quiero).
- Las cartas se identifican como [Numero,Palo]. con Palo en espada, basto, oro o copa.
  Ej: [7,espada].
  Tu carta SIEMPRE tiene que ser una de las que aparecen listadas en "cartas disponibles".
Tu respuesta debe ser SOLO esa jugada, terminada en punto. 
Evalua si cantar o aceptar el envido si tenes mas de una carta del mismo palo, también recordá que
podes mentir (cantar o aceptar el envido sin tener buenos puntos).
Evalua si cantar o aceptar el truco si tenes alguna de las cartas de mayor valor, también recordá que
podes mentir (cantar o aceptar el truco aunque no tengas buenas cartas).`;
 
const historial = [];
const MAX_HISTORIAL = 8; // para que no se sobre cargue mucho el prompt
 
function agregarAlHistorial(linea) {
  historial.push(linea);
  if (historial.length > MAX_HISTORIAL) historial.shift();
}

// Clasificación de mensajes, ajustada a los triggers de truco_prolog.pl
// "Es su turno..." y "Que carta tira?..." son solo texto informativo: el servidor
// todavía no llamó a ws_receive en ese punto. Si respondemos ahí, mandamos una
// respuesta de más que se queda encolada y se lee en el momento equivocado más
// adelante, lo cual desincroniza todo el protocolo y traba la partida.
let tipoEsperado = null; // 'accion' | 'carta' | 'si_no' | null
let ultimasCartasValidas = [];  // ej: ["[6,copa].", "[1,espada].", "[3,oro]."]
let ultimoIntentoInvalido = null; // lo último que mandamos y el servidor rechazó

function limpiarRespuesta(texto) {
  if (!texto) return null;
  const limpio = texto.trim().replace(/^[`*"'\s]+|[`*"'\s]+$/g, "");
 
  if (tipoEsperado === "carta") {
    // Buscamos el patrón [Numero,Palo] en cualquier parte del texto, ignorando
    // basura que el LLM agregue antes o después.
    const m = limpio.match(/\[\s*(\w+)\s*,\s*(\w+)\s*\]/);
    return m ? `[${m[1]},${m[2]}].` : null;
  }
 
  // Para menú (1-4) y sí/no (y/n): buscamos un token corto seguido de punto.
  const m = limpio.match(/\b([a-z0-9]+)\s*\./i);
  return m ? `${m[1].toLowerCase()}.` : null;
}
 
// Extrae las cartas reales del texto "cartas disponibles: [[6,copa],[1,espada],...]"
// que manda cargarCarta_ws, para poder validar y tener un respaldo siempre correcto.
function parsearCartas(mensaje) {
  const regex = /\[\s*(\w+)\s*,\s*(\w+)\s*\]/g;
  const cartas = [];
  let m;
  while ((m = regex.exec(mensaje)) !== null) {
    cartas.push(`[${m[1]},${m[2]}].`);
  }
  return cartas;
}
 
// Devuelve la versión exacta de la carta que matchea, o null si no matchea ninguna.
// Comparamos sin importar mayúsculas (el LLM no siempre es consistente con eso),
// pero lo que mandamos es siempre la canónica, nunca lo que escribió el LLM tal
// cual — porque "[7,Espada]." parsearía Espada como una VARIABLE Prolog, no como
// el átomo espada, y nunca matchearía en el servidor.
function buscarCartaCanonica(jugada) {
  if (!jugada) return null;
  return ultimasCartasValidas.find((c) => c.toLowerCase() === jugada.toLowerCase()) || null;
}
 
function clasificarMensaje(mensaje) {
  if (mensaje === "elige_accion" || mensaje === "elige_accion_sin_envido") {
    tipoEsperado = "accion";
    return true;
  }
  if (mensaje.startsWith("cartas disponibles:")) {
    tipoEsperado = "carta";
    ultimasCartasValidas = parsearCartas(mensaje);
    return true;
  }
  if (mensaje.includes("aceptar: y rechazar: n")) {
    tipoEsperado = "si_no";
    return true;
  }
  if (mensaje === "opcion invalida, ingrese nuevamente") {
    // El servidor no repite la lista de cartas en el reintento: ultimasCartasValidas
    // ya quedó guardada de la vez anterior, así que no se pierde el contexto.
    return tipoEsperado !== null;
  }
  return false;
}
 
// Frase explícita de qué se espera ahora. Esto es lo que evita que el LLM se
// confunda con mensajes viejos del historial (como el menú de "Elija una opcion").
function construirInstruccionActual() {
  switch (tipoEsperado) {
    case "carta":
      return `Tenés que elegir UNA carta para jugar ahora. Las ÚNICAS opciones válidas son: ${ultimasCartasValidas.join(" ")} — no existe ninguna otra carta posible.`;
    case "accion":
      return `Tenés que elegir una opción del menú de turno. Respondé solo con el número de la opción y un punto (ej: 1.).`;
    case "si_no":
      return `Te están preguntando si querés el envido/truco. Respondé y. (querer) o n. (no querer).`;
    default:
      return "";
  }
}
 
async function decidirJugada() {
  const avisoRechazo = ultimoIntentoInvalido
    ? `\nIMPORTANTE: tu respuesta anterior "${ultimoIntentoInvalido}" fue rechazada (no es válida ahora mismo). NO la repitas, elegí otra distinta de las opciones válidas.`
    : "";
 
  const contexto = `Contexto reciente de la partida (el más reciente es el último):
${historial.join("\n")}
 
---
DECISIÓN ACTUAL (responder solo a esto, ignorando decisiones anteriores ya resueltas): ${construirInstruccionActual()}${avisoRechazo}
 
Respondé solo con la jugada, en el formato indicado.`;
 
  const respuesta = await groq.chat.completions.create({
    model: MODELO,
    max_tokens: 20,
    temperature: 0.3,
    messages: [
      { role: "system", content: REGLAS },
      { role: "user", content: contexto },
    ],
  });
 
  const texto = respuesta.choices[0]?.message?.content || "";
  return limpiarRespuesta(texto);
}
 
const ws = new WebSocket(SERVIDOR_WS);
 
ws.on("open", () => {
  console.log(`Conectado. Registrando como "${NOMBRE_IA}"...`);
  // Comillas simples para forzar que sea un átomo Prolog válido sin importar
  // mayúsculas/minúsculas (join(Nombre) con mayúscula inicial sería una VARIABLE).
  ws.send(`join('${NOMBRE_IA}').`);
});
 
ws.on("message", async (data) => {
  const mensaje = data.toString();
  console.log("[servidor] ->", mensaje);
 
  if (!clasificarMensaje(mensaje)) { // cuando el mensaje no requiere respuesta (ej: "es su turno..")
    agregarAlHistorial(mensaje);
    return;
  }
 
  agregarAlHistorial(mensaje);
 
  let jugada = null;
  for (let intento = 0; intento < 3 && !jugada; intento++) {
    try {
      const candidata = await decidirJugada();
      if (tipoEsperado === "carta") {
        const canonica = buscarCartaCanonica(candidata);
        if (!canonica) {
          console.warn(`Carta inválida del LLM: "${candidata}". Cartas reales: ${ultimasCartasValidas.join(", ")}`);
          ultimoIntentoInvalido = candidata;
          continue; // no la mandamos al servidor, reintentamos
        }
        jugada = canonica; // la versión exacta que vino del servidor, no la del LLM
      } else {
        jugada = candidata;
      }
    } catch (err) {
      console.error("Error llamando a Groq:", err.message);
    }
  }
 
  if (!jugada) {
    if (tipoEsperado === "si_no") jugada = "n.";
    else if (tipoEsperado === "carta") jugada = ultimasCartasValidas[0] || null;
    else jugada = "1.";
 
    if (jugada) {
      console.warn("El LLM no devolvió un formato válido tras 3 intentos. Usando jugada de respaldo:", jugada);
    }
  }
 
  ultimoIntentoInvalido = null; // se resetea una vez que ya vamos a mandar algo
 
  if (!jugada) {
    console.error("No hay ninguna jugada de respaldo disponible (no se pudo parsear la lista de cartas).");
    return;
  }
 
  console.log("[IA] responde ->", jugada);
  ws.send(jugada);
});
 
ws.on("close", () => console.log("Conexión cerrada."));
ws.on("error", (err) => console.error("Error de WebSocket:", err.message));
 