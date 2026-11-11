// read-after-write.js — Fase 4 (Experimento 3, punto 7 del pedido): por cada
// iteración, escribe un dato (alta de producto + edición de precio) y lo lee
// de inmediato varias veces, sin pausa, contando cuántas lecturas devuelven
// el dato ausente (404 tras el alta) o viejo (precio anterior tras el PUT).
// Se corre una vez por nivel de latencia (0/20/50/100ms) y una vez con
// READ_FALLBACK_TO_PRIMARY=true y otra con false (la API se recrea entre
// corridas; este script no cambia esa variable, solo mide el efecto).
//
// Tags pasados por línea de comando (ver demo/scripts o el documento de
// resultados): --tag escenario=r2 --tag prueba=read-after-write
//               --tag latencia_ms=<0|20|50|100> --tag fallback=<true|false>
import http from "k6/http";
import { Counter } from "k6/metrics";
import { check } from "k6";

const BASE_URL = __ENV.API_BASE_URL || "http://10.10.1.10:8000";
const READS_PER_WRITE = 5;

export const options = {
  scenarios: {
    read_after_write: {
      executor: "shared-iterations",
      vus: 1,
      iterations: 20,
      maxDuration: "60s",
    },
  },
};

// Lecturas ausentes/viejas/frescas, contadas aparte del throughput: lo que
// importa acá es la PROPORCIÓN de lecturas desactualizadas a cada latencia,
// no cuántas peticiones por segundo soporta el sistema.
const absentAfterInsert = new Counter("read_after_write_absent_total");
const staleAfterUpdate = new Counter("read_after_write_stale_total");
const freshAfterUpdate = new Counter("read_after_write_fresh_total");

function jsonHeaders() {
  return { headers: { "Content-Type": "application/json" } };
}

export default function () {
  // --- 1. Alta: ¿la lectura inmediata ve el producto recién creado? -------
  const createPayload = JSON.stringify({
    category_id: Math.floor(Math.random() * 10) + 1,
    name: `read-after-write ${__VU}-${__ITER}-${Date.now()}`,
    price: 10.0,
    stock: 1,
  });
  const createRes = http.post(`${BASE_URL}/products`, createPayload, {
    ...jsonHeaders(),
    tags: { name: "POST /products (raw)" },
  });
  check(createRes, { "alta devuelve 201": (r) => r.status === 201 });
  if (createRes.status !== 201) return;
  const productId = createRes.json("id");

  // http.batch: las READS_PER_WRITE lecturas salen en paralelo, apenas
  // llega la respuesta del alta. Con lecturas secuenciales, el overhead de
  // cada request (HTTP + gunicorn + psycopg, decenas de ms) ya hacía que
  // para la 2da/3ra lectura hubiera pasado más tiempo desde el commit que
  // la latencia inyectada, sin encontrar nunca un dato viejo/ausente.
  const readUrl = `${BASE_URL}/products/${productId}`;
  const batchReqs = Array(READS_PER_WRITE).fill([
    "GET",
    readUrl,
    null,
    { tags: { name: "GET /products/{id} (raw)" } },
  ]);
  const batchRes = http.batch(batchReqs);
  for (const res of batchRes) {
    if (res.status === 404) {
      absentAfterInsert.add(1);
    }
  }

  // --- 2. Edición: ¿la lectura inmediata ve el precio nuevo o el viejo? ---
  const oldPrice = 10.0;
  const newPrice = 99.99;
  const updatePayload = JSON.stringify({ price: newPrice, stock: 1 });
  const updateRes = http.put(`${BASE_URL}/products/${productId}`, updatePayload, {
    ...jsonHeaders(),
    tags: { name: "PUT /products/{id} (raw)" },
  });
  check(updateRes, { "edición devuelve 200": (r) => r.status === 200 });
  if (updateRes.status !== 200) return;

  const batchRes2 = http.batch(batchReqs);
  for (const res of batchRes2) {
    if (res.status === 200) {
      const price = res.json("price");
      if (Math.abs(price - oldPrice) < 0.001) {
        staleAfterUpdate.add(1);
      } else if (Math.abs(price - newPrice) < 0.001) {
        freshAfterUpdate.add(1);
      }
    }
  }
}
