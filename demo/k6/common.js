// common.js — base compartida de las 3 pruebas del Experimento 1 (Fase 3).
// URL base, mezcla de tráfico EXACTA de la propuesta (90% lecturas / 10%
// escrituras) y umbrales comunes. Los 3 scripts de prueba (carga-base.js,
// estres.js, pico.js) importan esto sin modificarlo: lo único que cambia
// entre escenarios (base/r1/r2) son las etiquetas --tag del comando de
// ejecución, nunca el código.
import http from "k6/http";
import { check } from "k6";

// La API vive en net-app (10.10.1.10:8000); k6 llega ahí a través del
// router (regla de firewall net-clientes -> api:8000, §2.4). En el
// contenedor k6 esto se pasa por env (API_BASE_URL en docker-compose.yml);
// fuera del contenedor no hace falta, siempre corre dentro.
export const BASE_URL = __ENV.API_BASE_URL || "http://10.10.1.10:8000";

// Rango sembrado por demo/postgres/seed.sql (10 categorías, 500.000
// productos, IDs 1..N sin huecos en una base recién inicializada).
const CATEGORY_COUNT = 10;
const PRODUCT_COUNT = 500000;

export function randomCategoryId() {
  return Math.floor(Math.random() * CATEGORY_COUNT) + 1;
}

export function randomProductId() {
  return Math.floor(Math.random() * PRODUCT_COUNT) + 1;
}

function uniqueSuffix() {
  return `${__VU}-${__ITER}-${Date.now()}`;
}

const JSON_HEADERS = { headers: { "Content-Type": "application/json" } };

function getProducts() {
  const categoryId = randomCategoryId();
  return http.get(`${BASE_URL}/products?category_id=${categoryId}&limit=50`, {
    tags: { name: "GET /products" },
  });
}

function getProductById() {
  const id = randomProductId();
  return http.get(`${BASE_URL}/products/${id}`, {
    tags: { name: "GET /products/{id}" },
  });
}

function getCategoryById() {
  const id = randomCategoryId();
  return http.get(`${BASE_URL}/categories/${id}`, {
    tags: { name: "GET /categories/{id}" },
  });
}

function getCategories() {
  return http.get(`${BASE_URL}/categories`, {
    tags: { name: "GET /categories" },
  });
}

function postProduct() {
  const payload = JSON.stringify({
    category_id: randomCategoryId(),
    name: `k6 producto ${uniqueSuffix()}`,
    price: Math.round((Math.random() * 500 + 5) * 100) / 100,
    stock: Math.floor(Math.random() * 100),
  });
  return http.post(`${BASE_URL}/products`, payload, {
    ...JSON_HEADERS,
    tags: { name: "POST /products" },
  });
}

function putProduct() {
  const id = randomProductId();
  const payload = JSON.stringify({
    price: Math.round((Math.random() * 500 + 5) * 100) / 100,
    stock: Math.floor(Math.random() * 100),
  });
  return http.put(`${BASE_URL}/products/${id}`, payload, {
    ...JSON_HEADERS,
    tags: { name: "PUT /products/{id}" },
  });
}

function putCategory() {
  const id = randomCategoryId();
  const payload = JSON.stringify({
    name: `Categoría k6 ${uniqueSuffix()}`,
    description: "actualizada por k6 (carga de fase 3)",
  });
  return http.put(`${BASE_URL}/categories/${id}`, payload, {
    ...JSON_HEADERS,
    tags: { name: "PUT /categories/{id}" },
  });
}

function postCategory() {
  const payload = JSON.stringify({
    name: `Categoría k6 ${uniqueSuffix()}`,
    description: "creada por k6 (carga de fase 3)",
  });
  return http.post(`${BASE_URL}/categories`, payload, {
    ...JSON_HEADERS,
    tags: { name: "POST /categories" },
  });
}

// Mezcla de tráfico EXACTA de la propuesta (§3): 90% lecturas (40+30+10+10),
// 10% escrituras (5+4+0.5+0.5). Pesos acumulativos para la selección.
export const ENDPOINT_MIX = [
  { weight: 40, name: "GET /products", fn: getProducts },
  { weight: 30, name: "GET /products/{id}", fn: getProductById },
  { weight: 10, name: "GET /categories/{id}", fn: getCategoryById },
  { weight: 10, name: "GET /categories", fn: getCategories },
  { weight: 5, name: "POST /products", fn: postProduct },
  { weight: 4, name: "PUT /products/{id}", fn: putProduct },
  { weight: 0.5, name: "PUT /categories/{id}", fn: putCategory },
  { weight: 0.5, name: "POST /categories", fn: postCategory },
];

function pickEndpoint() {
  const r = Math.random() * 100;
  let acc = 0;
  for (const ep of ENDPOINT_MIX) {
    acc += ep.weight;
    if (r < acc) return ep;
  }
  return ENDPOINT_MIX[ENDPOINT_MIX.length - 1];
}

// Ejecuta una iteración de la mezcla 90/10: elige un endpoint según su peso,
// lo llama y valida que la respuesta sea 2xx. Lo llaman los 3 scripts de
// prueba en su función default.
export function runMixedRequest() {
  const endpoint = pickEndpoint();
  const res = endpoint.fn();
  check(res, {
    "status es 2xx": (r) => r.status >= 200 && r.status < 300,
  });
  return res;
}

// Umbrales de partida (conservadores): si la API o k6 se vuelven el cuello
// de botella antes que Postgres, se suben workers/CPU por igual en los 3
// escenarios (D11) y se documenta, en vez de aflojar estos umbrales.
export const THRESHOLDS = {
  http_req_failed: ["rate<0.05"],
  http_req_duration: ["p(95)<2000"],
};
