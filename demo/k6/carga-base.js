// carga-base.js — Experimento 1, prueba "Carga base" (~5 min): usuarios
// virtuales constantes, comportamiento normal. Se corre sin cambios en los
// 3 escenarios (base/r1/r2); lo que varía es el --tag del comando y los
// hosts de lectura de la API (READ_DB_HOSTS), nunca este archivo.
import { sleep } from "k6";
import { runMixedRequest, THRESHOLDS } from "./common.js";

export const options = {
  scenarios: {
    carga_base: {
      executor: "constant-vus",
      vus: 20,
      duration: "5m",
    },
  },
  thresholds: THRESHOLDS,
};

export default function () {
  runMixedRequest();
  sleep(1);
}
