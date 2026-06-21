// cliente_ia.js
// Cliente de truco que en vez de un humano usa un LLM (API de Groq) para decidir
// cada jugada. Se conecta al mismo WebSocket que cliente.html y cliente.pl, así que el
// servidor (servidor.pl) no nota ninguna diferencia: para él es "otro jugador" más.
//
// Groq es gratuito (sin tarjeta) y usa el mismo formato de API que OpenAI, así que
// el SDK que se usa es "openai", apuntado a la URL base de Groq.
//
// Instalación:
//   npm install ws openai
//
// Conseguir API key gratis (sin tarjeta): https://console.groq.com/keys
//
// Uso:
//   GROQ_API_KEY=tu_api_key NOMBRE_IA=RoboTruco node cliente_ia.js

import WebSocket from "ws";
import OpenAI from "openai";

const SERVIDOR_WS = "ws://localhost:8316/ws";
const NOMBRE_IA = process.env.NOMBRE_IA || "RoboTruco";

// Llama 3.3 70B en Groq: gratis, y corre a velocidades muy altas (ideal para que
// la IA responda casi al instante y no se note el "pensar" entre turnos).
const MODELO = "llama-3.3-70b-versatile";

const groq = new OpenAI({
  apiKey: process.env.GROQ_API_KEY, // lee GROQ_API_KEY de las variables de entorno
  baseURL: "https://api.groq.com/openai/v1",
});

// IMPORTANTE: estas reglas son un punto de partida. Antes de usar esto de verdad,
// revisá truco_prolog.pl (accion/2, envido_querido, cargarCarta_ws, repetir_ws) para
// confirmar el formato EXACTO de cada respuesta válida — si el LLM manda algo que no
// es un término Prolog válido, format(prolog) puede romper la conexión del lado del servidor.
const REGLAS = `Sos un jugador experto de truco argentino para 2 jugadores.
Vas a recibir el mensaje que te manda el servidor de juego con la situación actual.
Respondé ÚNICAMENTE con la jugada elegida, en el formato exacto que se pide, sin
explicaciones, sin saludos, sin texto adicional. Reglas de formato:
- Las opciones de menú numeradas se responden con el número y un punto. Ej: 1.
- Sí/No (envido, truco) se responde con y. (quiero) o n. (no quiero).
- Las cartas se identifican como [Numero,Palo]. con Palo en espada, basto, oro o copa.
  Ej: [7,espada].
Tu respuesta debe ser SOLO esa jugada, terminada en punto.`;

// Guardamos los últimos mensajes para darle algo de contexto al modelo
// (de qué se viene hablando, qué cartas se jugaron, etc.)
const historial = [];
const MAX_HISTORIAL = 8; 
// si no tenemos un maximo del historial el prompt que le mandamos
// al LLM creceria cada vez mas y consumiria muchos mas tokens

function agregarAlHistorial(linea) {
  historial.push(linea);
  if (historial.length > MAX_HISTORIAL) historial.shift();
}

// Se queda solo con la "palabra" Prolog inicial terminada en punto,
// descartando cualquier explicación que el LLM agregue de más.
function limpiarRespuesta(texto) {
  const m = texto.trim().match(/^(\[[^\]]+\]|[a-z0-9]+)\s*\./i);
  return m ? m[0].replace(/\s+/g, "") : null;
}

// limpiar respuesta mejorado por chatgpt
function limpiarRespuesta(texto) {
  texto = texto.trim();

  // Buscar una carta
  let m = texto.match(/\[[^\]]+\]\s*\./);
  if (m) {
    return m[0].replace(/\s+/g, "");
  }

  // Buscar respuestas simples
  m = texto.match(/\b([1-4]|y|n)\s*\./i);
  if (m) {
    return m[1].toLowerCase() + ".";
  }

  return null;
}

async function decidirJugada(mensajeServidor) {
  agregarAlHistorial(mensajeServidor);

  const contexto = `Últimos mensajes del servidor (el más reciente es el último):
${historial.join("\n")}

¿Qué jugada hacés? Respondé solo con la acción, en el formato indicado.`;

  const respuesta = await groq.chat.completions.create({
    model: MODELO,
    max_tokens: 20,
    temperature: 0.3, // poca creatividad: queremos una jugada consistente, no prosa
    messages: [
      { role: "system", content: REGLAS },
      { role: "user", content: contexto },
    ],
  });

  const texto = respuesta.choices[0]?.message?.content || "";
  return limpiarRespuesta(texto);
}

// Heurística simple para saber si el mensaje del servidor espera una respuesta nuestra
// o si es solo informativo (ej. "Juan ganó la ronda").
function requiereRespuesta(mensaje) {
  return (
    /elige_accion|Que carta tira|Quiere|¿Quiere|Elija una opci/i.test(mensaje) ||
    mensaje.includes("aceptar: y") ||
    mensaje.includes("cartas disponibles:")
  );
}

const ws = new WebSocket(SERVIDOR_WS);

ws.on("open", () => {
  console.log(`Conectado. Registrando como "${NOMBRE_IA}"...`);
  ws.send(`join(${NOMBRE_IA}).`);
});

ws.on("message", async (data) => {
  const mensaje = data.toString();
  console.log("[servidor] ->", mensaje);

  if (!requierePeRespuesta(mensaje)) {
    agregarAlHistorial(mensaje); // igual lo guardamos como contexto
    return;
  }

  let jugada = null;
  for (let intento = 0; intento < 3 && !jugada; intento++) {
    try {
      jugada = await decidirJugada(mensaje);
    } catch (err) {
      console.error("Error llamando a Groq:", err.message);
    }
  }

  if (!jugada) {
    console.warn("El LLM no devolvió un formato válido tras 3 intentos. Usando jugada de respaldo.");
    jugada = "1."; // jugada de respaldo segura: ajustar según el contexto real
  }

  console.log("[IA] responde ->", jugada);
  ws.send(jugada);
});

ws.on("close", () => console.log("Conexión cerrada."));
ws.on("error", (err) => console.error("Error de WebSocket:", err.message));
