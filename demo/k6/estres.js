// estres.js — Experimento 1, prueba "Estrés escalonado" (~8 min): la carga
// sube por etapas hasta que la latencia o los errores se disparan, para
// encontrar el punto de quiebre. Se corre sin cambios en los 3 escenarios
// (base/r1/r2); el umbral de error/latencia puede incumplirse a propósito
// en algún escalón (eso es justamente lo que se mide), sin abortar el test.
import { sleep } from "k6";
import { runMixedRequest, THRESHOLDS } from "./common.js";

export const options = {
  scenarios: {
    estres: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "1m", target: 20 },
        { duration: "1m", target: 50 },
        { duration: "1m", target: 100 },
        { duration: "1m", target: 150 },
        { duration: "1m", target: 200 },
        { duration: "1m", target: 250 },
        { duration: "1m", target: 300 },
        { duration: "1m", target: 0 },
      ],
    },
  },
  thresholds: THRESHOLDS,
};

export default function () {
  runMixedRequest();
  sleep(1);
}
