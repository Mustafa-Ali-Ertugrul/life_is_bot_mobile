#!/usr/bin/env python3
"""Life Is Bot backend taklidi — cihaz smoke testi için.

Gerçek ApiClient'ın beklediği yanıt şekillerini birebir döndürür:
  - liste endpoint'leri PaginatedResponse: {"items": [...], "total": N}
  - /preferences ham liste
  - /reports/monthly bot_stats
  - /reports/monthly/days scheduled_days + completed_days (ISO tarih)

Ayrıca HER isteği sayar ve stderr'e yazar; böylece uygulamanın soğuk açılışta
gerçekte kaç istek attığı ölçülebilir (review'daki Y4 iddiasının ölçümü).
"""
import datetime
import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

PORT = 8080

MEDS = [
    {"id": 11, "name": "Aspirin", "dose": "100mg", "target_hour": 8,
     "target_minute": 0, "days_of_week": "1,2,3,4,5,6,7", "is_active": True},
    {"id": 12, "name": "D Vitamini", "dose": "1000IU", "target_hour": 21,
     "target_minute": 30, "days_of_week": "1,2,3,4,5,6,7", "is_active": True},
]
HABITS = [
    {"id": 21, "name": "Meditasyon", "target_hour": 7, "target_minute": 0,
     "days_of_week": "1,3,5", "is_active": True},
    {"id": 22, "name": "Kitap Oku", "target_hour": 22, "target_minute": 0,
     "days_of_week": "1,2,3,4,5,6,7", "is_active": True},
]
SPORT = [
    {"id": 31, "sport_type": "Koşu", "target_hour": 18, "target_minute": 0,
     "days_of_week": "1,3,5", "is_active": True},
]
SUPP = [
    {"id": 41, "name": "Kreatin", "dose": "5g", "target_hour": 9,
     "target_minute": 0, "days_of_week": "1,2,3,4,5,6,7", "is_active": True},
]
PREFS = [
    {"bot_key": "medication_bot", "enabled": True},
    {"bot_key": "habit_bot", "enabled": True},
    {"bot_key": "sport_bot", "enabled": True},
    {"bot_key": "supplement_bot", "enabled": True},
    {"bot_key": "step_bot", "enabled": True},
    {"bot_key": "assessment_bot", "enabled": False},
]

_lock = threading.Lock()
_calls = []  # (method, path) — sırayla


def _month_days(days):
    """Bu aya ait ISO tarih listesi (uygulama yıl/ay filtreliyor)."""
    t = datetime.date.today()
    last = (t.replace(day=28) + datetime.timedelta(days=4)).replace(day=1) - datetime.timedelta(days=1)
    out = []
    for d in days:
        if 1 <= d <= last.day:
            out.append(t.replace(day=d).isoformat())
    return out


def _daily():
    return {"total": 5, "completed": 3, "missed": 1, "unanswered": 1}


def _weekly():
    return {
        "total": 24, "completed": 17, "missed": 4, "unanswered": 3,
        "completion_rate": 70.8,
        "daily": [
            {"date": (datetime.date.today() - datetime.timedelta(days=i)).isoformat(),
             "total": 5, "completed": 3 + (i % 3)}
            for i in range(6, -1, -1)
        ],
    }


def _monthly():
    return {
        "total": 96, "completed": 61, "missed": 20, "unanswered": 15,
        "completion_rate": 63.5,
        "bot_stats": [
            {"bot_key": "medication_bot", "completion_rate": 66.0, "total": 30, "completed": 20},
            {"bot_key": "habit_bot", "completion_rate": 58.0, "total": 40, "completed": 23},
            {"bot_key": "sport_bot", "completion_rate": 80.0, "total": 15, "completed": 12},
            {"bot_key": "supplement_bot", "completion_rate": 45.0, "total": 11, "completed": 5},
        ],
    }


def _month_days_payload(bot_key):
    if bot_key == "medication_bot":
        sched, done = list(range(1, 16)), [1, 2, 3, 5, 8, 9, 11, 12]
    elif bot_key == "habit_bot":
        sched, done = [1, 3, 5, 8, 10, 12, 15], [1, 3, 5, 8]
    elif bot_key == "sport_bot":
        sched, done = [1, 3, 5, 8, 10, 12], [1, 3, 10]
    else:  # supplement_bot
        sched, done = list(range(1, 13)), [2, 4, 6]
    return {"bot_key": bot_key,
            "scheduled_days": _month_days(sched),
            "completed_days": _month_days(done)}


def _streak():
    return {"current": 12, "longest": 27, "last_completed": datetime.date.today().isoformat()}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # gürültüyü kapat, kendi logumuz var
        pass

    def _record(self):
        path = urlparse(self.path).path
        with _lock:
            _calls.append((self.command, path))
        sys.stderr.write("REQ %s %s (toplam %d)\n" % (self.command, path, len(_calls)))
        sys.stderr.flush()

    def _send(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _route(self):
        self._record()
        path = urlparse(self.path).path
        p = path[4:] if path.startswith("/api") else path
        m = self.command

        if p == "/health":
            return self._send(200, {"status": "ok"})
        if p == "/auth/token" and m == "POST":
            return self._send(200, {"access_token": "smoke-jwt-token", "token_type": "bearer"})
        if p == "/medications" and m == "GET":
            return self._send(200, {"items": MEDS, "total": len(MEDS)})
        if p == "/habits" and m == "GET":
            return self._send(200, {"items": HABITS, "total": len(HABITS)})
        if p == "/sport" and m == "GET":
            return self._send(200, {"items": SPORT, "total": len(SPORT)})
        if p == "/supplement" and m == "GET":
            return self._send(200, {"items": SUPP, "total": len(SUPP)})
        if p == "/preferences" and m == "GET":
            return self._send(200, PREFS)
        if p == "/reports/daily":
            return self._send(200, _daily())
        if p == "/reports/weekly":
            return self._send(200, _weekly())
        if p == "/reports/monthly/days":
            q = urlparse(self.path).query
            bot = "medication_bot"
            for part in q.split("&"):
                if part.startswith("bot_key="):
                    bot = part.split("=", 1)[1]
            return self._send(200, _month_days_payload(bot))
        if p == "/reports/monthly":
            return self._send(200, _monthly())
        if p == "/reports/streak":
            return self._send(200, _streak())
        if p == "/step/settings":
            if m == "GET":
                return self._send(200, {"daily_target": 8000})
            return self._send(200, {"daily_target": 8000})
        if p == "/step/logs":
            return self._send(200, {"ok": True})
        if p == "/responses":
            return self._send(200, {"ok": True})
        if p == "/onboarding":
            return self._send(200, {"completed": True, "skipped": False, "question": None})
        return self._send(404, {"detail": "route yok: %s %s" % (m, p)})

    def do_GET(self):
        self._route()

    def do_POST(self):
        ln = int(self.headers.get("Content-Length") or 0)
        if ln:
            self.rfile.read(ln)
        self._route()

    def do_PATCH(self):
        self.do_POST()

    def do_PUT(self):
        self.do_POST()

    def do_DELETE(self):
        self._route()


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    sys.stderr.write("mock backend 0.0.0.0:%d üzerinde hazır\n" % PORT)
    sys.stderr.flush()
    srv.serve_forever()
