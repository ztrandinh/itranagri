// k6 load-test tối thiểu — trước đây 0 kết quả toàn repo cho k6/artillery/autocannon, không có cách
// nào biết hệ thống chịu tải tới đâu trước khi hỏng (mục tiêu mở rộng đa trại/đa vùng cần biết trước).
// Chạy: k6 run -e BASE_URL=http://localhost:3111 -e SESSION_COOKIE="itran_sess=..." scripts/load/smoke.js
// (lấy SESSION_COOKIE bằng cách đăng nhập trên trình duyệt rồi copy cookie, hoặc POST /api/auth/login trước).
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    smoke: { executor: "ramping-vus", startVUs: 0, stages: [
      { duration: "30s", target: 5 },
      { duration: "1m", target: 5 },
      { duration: "30s", target: 0 },
    ] },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<800"],
  },
};

const BASE_URL = __ENV.BASE_URL || "http://localhost:3111";
const COOKIE = __ENV.SESSION_COOKIE || "";

export default function smokeTest() {
  const headers = COOKIE ? { Cookie: COOKIE } : {};

  const health = http.get(`${BASE_URL}/api/health`);
  check(health, { "health 200": (r) => r.status === 200 });

  if (COOKIE) {
    const kpi = http.get(`${BASE_URL}/api/data/tasks_today?farm=F01`, { headers });
    check(kpi, { "tasks_today ok": (r) => r.status === 200 || r.status === 401 });
  }

  sleep(1);
}
