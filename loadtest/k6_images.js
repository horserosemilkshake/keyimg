import http from "k6/http";
import { check } from "k6";

export const options = {
  vus: Number(__ENV.VUS || 100),
  duration: __ENV.DURATION || "20s",
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<200"],
  },
};

const baseUrl = __ENV.BASE_URL || "http://127.0.0.1:4000";
const payloadBytes = Number(__ENV.PAYLOAD_BYTES || 256);
const payload = "x".repeat(payloadBytes);

let imageId = "";

export function setup() {
  const headers = { "Content-Type": "image/png" };
  const res = http.post(`${baseUrl}/images`, payload, { headers });
  check(res, {
    "setup POST /images status 200": (r) => r.status === 200,
  });

  const body = JSON.parse(res.body);
  imageId = body.id;
  return { imageId };
}

export default function (data) {
  const res = http.get(`${baseUrl}/images/${data.imageId}`);
  check(res, {
    "GET /images/:id status 200": (r) => r.status === 200,
    "GET /images/:id body length": (r) => r.body.length === payloadBytes,
  });
}
