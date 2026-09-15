#!/usr/bin/env python3
"""
Shulk Handheld Launcher - Web Server & Analytics Backend
Zero external dependencies (uses standard library: http.server, sqlite3, hashlib, secrets, json).
Serves static website files, tracks anonymous pageviews & download metrics, and hosts /admin.
"""

import os
import sys
import json
import time
import sqlite3
import hashlib
import secrets
import mimetypes
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timezone

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8088
WEB_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(WEB_DIR, 'analytics.db')
CONFIG_PATH = os.path.join(WEB_DIR, 'admin_config.json')

# Initialize Admin Config with secure default if missing
DEFAULT_ADMIN_USER = "admin"
DEFAULT_ADMIN_PASS = "shulk2026"

def get_admin_credentials():
    if not os.path.exists(CONFIG_PATH):
        salt = secrets.token_hex(16)
        pwd_hash = hashlib.pbkdf2_hmac('sha256', DEFAULT_ADMIN_PASS.encode(), salt.encode(), 100000).hex()
        cfg = {
            "username": DEFAULT_ADMIN_USER,
            "salt": salt,
            "password_hash": pwd_hash,
            "session_timeout_seconds": 86400 * 7
        }
        with open(CONFIG_PATH, 'w') as f:
            json.dump(cfg, f, indent=2)
        return cfg
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS pageviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            visitor_hash TEXT NOT NULL,
            path TEXT NOT NULL,
            referrer TEXT,
            os TEXT,
            user_agent TEXT,
            country TEXT
        )
    ''')
    cur.execute('''
        CREATE TABLE IF NOT EXISTS downloads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            visitor_hash TEXT NOT NULL,
            platform TEXT NOT NULL,
            asset_name TEXT NOT NULL,
            version TEXT NOT NULL
        )
    ''')
    cur.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
            token TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL
        )
    ''')
    cur.execute('CREATE INDEX IF NOT EXISTS idx_pv_ts ON pageviews(timestamp)')
    cur.execute('CREATE INDEX IF NOT EXISTS idx_dl_ts ON downloads(timestamp)')
    cur.execute('CREATE INDEX IF NOT EXISTS idx_dl_plat ON downloads(platform)')
    cur.execute('''
        CREATE TABLE IF NOT EXISTS announcement (
            id INTEGER PRIMARY KEY,
            enabled INTEGER NOT NULL DEFAULT 0,
            text TEXT NOT NULL DEFAULT '',
            link_url TEXT NOT NULL DEFAULT '',
            link_text TEXT NOT NULL DEFAULT '',
            banner_style TEXT NOT NULL DEFAULT 'emerald',
            updated_at INTEGER NOT NULL DEFAULT 0
        )
    ''')
    cur.execute('INSERT OR IGNORE INTO announcement (id, enabled, text, link_url, link_text, banner_style, updated_at) VALUES (1, 0, "", "", "", "emerald", 0)')
    conn.commit()
    conn.close()

init_db()

def validate_session(token):
    if not token:
        return False
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now = int(time.time())
    cur.execute('SELECT username, expires_at FROM sessions WHERE token = ?', (token,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return False
    if row[1] < now:
        return False
    return True

def create_session(username):
    token = secrets.token_hex(32)
    now = int(time.time())
    cfg = get_admin_credentials()
    expires = now + cfg.get("session_timeout_seconds", 86400 * 7)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('INSERT INTO sessions (token, username, created_at, expires_at) VALUES (?, ?, ?, ?)',
                (token, username, now, expires))
    conn.commit()
    conn.close()
    return token

def delete_session(token):
    if not token:
        return
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('DELETE FROM sessions WHERE token = ?', (token,))
    conn.commit()
    conn.close()

def hash_visitor(ip, user_agent):
    day_salt = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    raw = f"{ip}:{user_agent}:{day_salt}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]

class ShulkHandler(BaseHTTPRequestHandler):
    server_version = "ShulkServer/1.1"

    def get_client_ip(self):
        cf_ip = self.headers.get('CF-Connecting-IP')
        if cf_ip:
            return cf_ip.strip()
        forwarded = self.headers.get('X-Forwarded-For')
        if forwarded:
            return forwarded.split(',')[0].strip()
        return self.client_address[0]

    def get_cookie(self, name):
        cookie_header = self.headers.get('Cookie')
        if not cookie_header:
            return None
        for item in cookie_header.split(';'):
            item = item.strip()
            if item.startswith(f"{name}="):
                return item[len(name)+1:]
        return None

    def send_json(self, status, payload):
        data = json.dumps(payload).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        parsed = urlparse(self.path)
        content_len = int(self.headers.get('Content-Length', 0))
        post_body = b''
        if content_len > 0:
            post_body = self.rfile.read(min(content_len, 65536))

        try:
            data = json.loads(post_body.decode('utf-8')) if post_body else {}
        except Exception:
            data = {}

        if parsed.path == '/api/track/download':
            platform = str(data.get('platform', 'unknown'))[:32]
            asset_name = str(data.get('asset_name', ''))[:128]
            version = str(data.get('version', 'v1.1.2'))[:32]
            ip = self.get_client_ip()
            ua = self.headers.get('User-Agent', '')
            visitor_hash = hash_visitor(ip, ua)
            now = int(time.time())

            try:
                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute('INSERT INTO downloads (timestamp, visitor_hash, platform, asset_name, version) VALUES (?, ?, ?, ?, ?)',
                            (now, visitor_hash, platform, asset_name, version))
                conn.commit()
                conn.close()
            except Exception:
                pass
            return self.send_json(200, {"status": "ok"})

        elif parsed.path == '/api/track/view':
            path_str = str(data.get('path', '/'))[:128]
            referrer = str(data.get('referrer', ''))[:256]
            detected_os = str(data.get('os', ''))[:64]
            ip = self.get_client_ip()
            ua = self.headers.get('User-Agent', '')
            country = self.headers.get('CF-IPCountry', '')
            visitor_hash = hash_visitor(ip, ua)
            now = int(time.time())

            try:
                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute('INSERT INTO pageviews (timestamp, visitor_hash, path, referrer, os, user_agent, country) VALUES (?, ?, ?, ?, ?, ?, ?)',
                            (now, visitor_hash, path_str, referrer, detected_os, ua[:256], country[:8]))
                conn.commit()
                conn.close()
            except Exception:
                pass
            return self.send_json(200, {"status": "ok"})

        elif parsed.path == '/api/admin/login':
            user = data.get('username', '').strip()
            pwd = data.get('password', '')
            cfg = get_admin_credentials()

            salt = cfg.get('salt', '')
            expected_hash = cfg.get('password_hash', '')
            computed_hash = hashlib.pbkdf2_hmac('sha256', pwd.encode(), salt.encode(), 100000).hex()

            if user == cfg.get('username') and secrets.compare_digest(computed_hash, expected_hash):
                token = create_session(user)
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                cookie_str = f"shulk_admin_session={token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=604800"
                self.send_header('Set-Cookie', cookie_str)
                self.end_headers()
                self.wfile.write(json.dumps({"status": "success", "username": user}).encode())
                return
            else:
                time.sleep(0.5)
                return self.send_json(401, {"status": "error", "message": "Invalid username or password"})

        elif parsed.path == '/api/admin/announcement':
            token = self.get_cookie('shulk_admin_session')
            if not validate_session(token):
                return self.send_json(401, {"status": "unauthorized"})
            enabled = 1 if data.get('enabled') else 0
            text = str(data.get('text', '')).strip()[:256]
            link_url = str(data.get('link_url', '')).strip()[:256]
            link_text = str(data.get('link_text', '')).strip()[:64]
            banner_style = str(data.get('banner_style', 'emerald'))[:32]
            now = int(time.time())

            try:
                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute('''
                    UPDATE announcement 
                    SET enabled = ?, text = ?, link_url = ?, link_text = ?, banner_style = ?, updated_at = ?
                    WHERE id = 1
                ''', (enabled, text, link_url, link_text, banner_style, now))
                conn.commit()
                conn.close()
                return self.send_json(200, {"status": "ok", "announcement": {
                    "enabled": bool(enabled), "text": text, "link_url": link_url,
                    "link_text": link_text, "banner_style": banner_style, "updated_at": now
                }})
            except Exception as e:
                return self.send_json(500, {"status": "error", "message": str(e)})

        elif parsed.path == '/api/admin/logout':
            token = self.get_cookie('shulk_admin_session')
            if token:
                delete_session(token)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Set-Cookie', 'shulk_admin_session=; Path=/; HttpOnly; Max-Age=0')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "logged_out"}).encode())
            return

        self.send_error(404, "Not Found")


    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        parsed = urlparse(self.path)
        clean_path = parsed.path

        if clean_path == '/api/announcement':
            conn = sqlite3.connect(DB_PATH)
            cur = conn.cursor()
            cur.execute('SELECT enabled, text, link_url, link_text, banner_style, updated_at FROM announcement WHERE id = 1')
            row = cur.fetchone()
            conn.close()
            if row:
                return self.send_json(200, {
                    "enabled": bool(row[0]),
                    "text": row[1],
                    "link_url": row[2],
                    "link_text": row[3],
                    "banner_style": row[4],
                    "updated_at": row[5]
                })
            return self.send_json(200, {"enabled": False})

        if clean_path in ('/admin', '/admin/'):
            self.serve_admin_page()
            return

        if clean_path == '/api/admin/stats':
            token = self.get_cookie('shulk_admin_session')
            if not validate_session(token):
                return self.send_json(401, {"status": "unauthorized", "message": "Admin login required"})
            stats = self.gather_stats()
            return self.send_json(200, stats)

        if clean_path == '/api/admin/me':
            token = self.get_cookie('shulk_admin_session')
            if validate_session(token):
                return self.send_json(200, {"authenticated": True, "username": get_admin_credentials().get("username")})
            return self.send_json(200, {"authenticated": False})

        self.serve_static_file(clean_path)

    def serve_admin_page(self):
        admin_file = os.path.join(WEB_DIR, 'admin.html')
        if not os.path.exists(admin_file):
            return self.send_error(404, "admin.html not found")
        with open(admin_file, 'rb') as f:
            content = f.read()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(content)))
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        self.end_headers()
        self.wfile.write(content)

    def serve_static_file(self, req_path):
        if req_path == '/' or req_path == '':
            req_path = '/index.html'

        req_path = os.path.normpath(req_path.lstrip('/'))
        full_path = os.path.join(WEB_DIR, req_path)

        if not os.path.exists(full_path) or os.path.isdir(full_path):
            self.send_error(404, "File Not Found")
            return

        ctype, _ = mimetypes.guess_type(full_path)
        if not ctype:
            if full_path.endswith('.otf'):
                ctype = 'font/otf'
            elif full_path.endswith('.ttf'):
                ctype = 'font/ttf'
            elif full_path.endswith('.ogg'):
                ctype = 'audio/ogg'
            else:
                ctype = 'application/octet-stream'

        try:
            with open(full_path, 'rb') as f:
                content = f.read()

            self.send_response(200)
            self.send_header('Content-Type', ctype)
            self.send_header('Content-Length', str(len(content)))
            if req_path.endswith(('.png', '.svg', '.otf', '.ttf', '.ogg')):
                self.send_header('Cache-Control', 'public, max-age=604800')
            else:
                self.send_header('Cache-Control', 'public, max-age=60')
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error(500, f"Internal Error: {str(e)}")

    def gather_stats(self):
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        now = int(time.time())
        one_day_ago = now - 86400
        seven_days_ago = now - (86400 * 7)

        cur.execute('SELECT COUNT(*) FROM pageviews')
        total_views = cur.fetchone()[0]

        cur.execute('SELECT COUNT(*) FROM pageviews WHERE timestamp >= ?', (one_day_ago,))
        views_24h = cur.fetchone()[0]

        cur.execute('SELECT COUNT(DISTINCT visitor_hash) FROM pageviews')
        total_uniques = cur.fetchone()[0]

        cur.execute('SELECT COUNT(DISTINCT visitor_hash) FROM pageviews WHERE timestamp >= ?', (one_day_ago,))
        uniques_24h = cur.fetchone()[0]

        cur.execute('SELECT COUNT(DISTINCT visitor_hash) FROM pageviews WHERE timestamp >= ?', (seven_days_ago,))
        uniques_7d = cur.fetchone()[0]

        cur.execute('SELECT COUNT(*) FROM downloads')
        total_downloads = cur.fetchone()[0]

        cur.execute('SELECT COUNT(*) FROM downloads WHERE timestamp >= ?', (one_day_ago,))
        downloads_24h = cur.fetchone()[0]

        cur.execute('''
            SELECT platform, COUNT(*) as cnt 
            FROM downloads 
            GROUP BY platform 
            ORDER BY cnt DESC
        ''')
        downloads_by_platform = [{"platform": row[0], "count": row[1]} for row in cur.fetchall()]

        cur.execute('''
            SELECT os, COUNT(*) as cnt 
            FROM pageviews 
            WHERE os IS NOT NULL AND os != ''
            GROUP BY os 
            ORDER BY cnt DESC 
            LIMIT 8
        ''')
        os_breakdown = [{"os": row[0], "count": row[1]} for row in cur.fetchall()]

        cur.execute('''
            SELECT referrer, COUNT(*) as cnt 
            FROM pageviews 
            WHERE referrer IS NOT NULL AND referrer != ''
            GROUP BY referrer 
            ORDER BY cnt DESC 
            LIMIT 8
        ''')
        referrers = [{"referrer": row[0], "count": row[1]} for row in cur.fetchall()]

        daily_trends = []
        for i in range(6, -1, -1):
            day_start = now - ((i + 1) * 86400)
            day_end = day_start + 86400
            day_label = datetime.fromtimestamp(day_start, tz=timezone.utc).strftime('%b %d')
            cur.execute('SELECT COUNT(*), COUNT(DISTINCT visitor_hash) FROM pageviews WHERE timestamp >= ? AND timestamp < ?', (day_start, day_end))
            pv, uv = cur.fetchone()
            cur.execute('SELECT COUNT(*) FROM downloads WHERE timestamp >= ? AND timestamp < ?', (day_start, day_end))
            dl = cur.fetchone()[0]
            daily_trends.append({
                "date": day_label,
                "views": pv,
                "uniques": uv,
                "downloads": dl
            })

        cur.execute('''
            SELECT timestamp, 'download' as event_type, platform as detail, asset_name as extra 
            FROM downloads 
            ORDER BY timestamp DESC LIMIT 10
        ''')
        recent_dls = cur.fetchall()

        cur.execute('''
            SELECT timestamp, 'pageview' as event_type, os as detail, country as extra 
            FROM pageviews 
            ORDER BY timestamp DESC LIMIT 10
        ''')
        recent_pvs = cur.fetchall()

        all_events = sorted(recent_dls + recent_pvs, key=lambda x: x[0], reverse=True)[:15]
        recent_activity = [{
            "timestamp": row[0],
            "time_ago": format_time_ago(row[0]),
            "type": row[1],
            "detail": row[2] or "Unknown",
            "extra": row[3] or ""
        } for row in all_events]

        conn.close()

        return {
            "summary": {
                "total_views": total_views,
                "views_24h": views_24h,
                "total_uniques": total_uniques,
                "uniques_24h": uniques_24h,
                "uniques_7d": uniques_7d,
                "total_downloads": total_downloads,
                "downloads_24h": downloads_24h
            },
            "downloads_by_platform": downloads_by_platform,
            "os_breakdown": os_breakdown,
            "referrers": referrers,
            "daily_trends": daily_trends,
            "recent_activity": recent_activity
        }

def format_time_ago(ts):
    now = int(time.time())
    delta = max(0, now - ts)
    if delta < 60:
        return f"{delta}s ago"
    elif delta < 3600:
        return f"{delta // 60}m ago"
    elif delta < 86400:
        return f"{delta // 3600}h ago"
    else:
        return f"{delta // 86400}d ago"

def run():
    get_admin_credentials()
    server_address = ('', PORT)
    httpd = HTTPServer(server_address, ShulkHandler)
    print(f"Shulk Web & Admin Server running on http://0.0.0.0:{PORT} (Serving {WEB_DIR})")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()

if __name__ == '__main__':
    run()
