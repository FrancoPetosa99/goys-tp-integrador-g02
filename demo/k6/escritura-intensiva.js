// escritura-intensiva.js — Fase 4 (Experimento 3, lag vs. latencia). NO es
// parte de la mezcla 90/10 estándar: se verificó que con el volumen de
// escritura de carga-base.js (~1-2 escrituras/s) el lag de WAL
// (pg_stat_replication_pg_wal_lsn_diff) se mantiene en 0 en los cuatro
// niveles de latencia probados (0/20/50/100ms) — ver
// decisiones-tecnicas.md. Este script existe solo para esta medición
// puntual: muchos UPDATE concurrentes y sin pausa, para generar backlog de
// WAL real y observable mientras se varía la latencia con netem.sh.
import http from "k6/http";

const BASE_URL = __ENV.API_BASE_URL || "http://10.10.1.10:8000";
const PRODUCT_COUNT = 500000;

export const options = {
  scenarios: {
    escritura_intensiva: {
      executor: "constant-vus",
      vus: 50,
      duration: "45s",
    },
  },
};

export default function () {
  const id = Math.floor(Math.random() * PRODUCT_COUNT) + 1;
  const payload = JSON.stringify({
    price: Math.round(Math.random() * 500 * 100) / 100,
    stock: Math.floor(Math.random() * 100),
  });
  http.put(`${BASE_URL}/products/${id}`, payload, {
    headers: { "Content-Type": "application/json" },
    tags: { name: "PUT /products/{id} (escritura-intensiva)" },
  });
}
