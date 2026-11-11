// pico.js — Experimento 1, prueba "Pico" (spike, ~3 min): salto brusco de
// carga y vuelta a la normalidad, para medir la recuperación. Se corre sin
// cambios en los 3 escenarios (base/r1/r2).
import { sleep } from "k6";
import { runMixedRequest, THRESHOLDS } from "./common.js";

export const options = {
  scenarios: {
    pico: {
      executor: "ramping-vus",
      startVUs: 10,
      stages: [
        { duration: "30s", target: 10 }, // línea base
        { duration: "10s", target: 300 }, // salto brusco
        { duration: "1m", target: 300 }, // sostenido en el pico
        { duration: "10s", target: 10 }, // vuelta brusca a la normalidad
        { duration: "1m10s", target: 10 }, // recuperación
      ],
    },
  },
  thresholds: THRESHOLDS,
};

export default function () {
  runMixedRequest();
  sleep(1);
}
