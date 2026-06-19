#!/usr/bin/env bash
# module_panel.sh
# Universal Web Dashboard Deployment Engine

export APP_DIR="/opt/bluefalcon-ultimate-toolkit"

# ==============================================================================
# 1. Backend Logic
# ==============================================================================

setup_panel_environment() {
    mkdir -p "${APP_DIR}/panel/templates" "${APP_DIR}/configs" /var/log/bluefalcon-panel
    
    export DEBIAN_FRONTEND=noninteractive
    echo "iptables-persistent iptables-persistent/ensure-ipv4-rules boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/ensure-ipv6-rules boolean true" | debconf-set-selections
    apt-get update -y
    apt-get install -y python3-flask python3-gunicorn python3-psutil sqlite3 curl cron gunicorn iptables iptables-persistent iproute2 netcat-openbsd

    # Swapfile protection for low-RAM servers
    if ! grep -q "/swapfile" /etc/fstab; then
        fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # Web Panel Firewall
    iptables -I INPUT -p tcp --dport 2020 -j ACCEPT
    netfilter-persistent save > /dev/null 2>&1

    # ==========================================
    # --- FLASK PYTHON ENGINE (app.py) ---
    # ==========================================
    cat << 'EOF_APP' > "${APP_DIR}/panel/app.py"
from flask import Flask, render_template, request, redirect, url_for, session, send_file, Response
import sqlite3, os, time, subprocess, re, psutil

app = Flask(__name__)
app.secret_key = 'BlueFalcon_Enterprise_Secret_Key_2026'
APP_DIR = '/opt/bluefalcon-ultimate-toolkit'
DB_PATH = f'{APP_DIR}/panel/panel.db'
LOG_PATH = '/var/log/openvpn/status.log'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = get_db()
    conn.execute('CREATE TABLE IF NOT EXISTS admin (username TEXT, password TEXT)')
    conn.execute('CREATE TABLE IF NOT EXISTS settings (server_name TEXT, protocol TEXT, port INTEGER, dns TEXT, dns2 TEXT, conn_limit TEXT, panel_port INTEGER, is_installed INTEGER DEFAULT 0)')
    conn.execute('CREATE TABLE IF NOT EXISTS users (display_name TEXT, system_name TEXT, password TEXT, exp_days INTEGER, status TEXT, rx INTEGER DEFAULT 0, tx INTEGER DEFAULT 0)')
    try: conn.execute('ALTER TABLE settings ADD COLUMN dns2 TEXT')
    except: pass
    try: conn.execute('ALTER TABLE users ADD COLUMN rx INTEGER DEFAULT 0')
    except: pass
    try: conn.execute('ALTER TABLE users ADD COLUMN tx INTEGER DEFAULT 0')
    except: pass
    conn.commit()
    conn.close()

init_db()

def format_bytes(b):
    if not isinstance(b, (int, float)): return "0.0 KB"
    if b < 1048576: return f"{b/1024:.1f} KB"
    elif b < 1073741824: return f"{b/1048576:.1f} MB"
    else: return f"{b/1073741824:.2f} GB"

app.jinja_env.filters['format_bytes'] = format_bytes

def get_traffic():
    live_traffic = {}; live_rx = 0; live_tx = 0
    try:
        with open(LOG_PATH, "r") as f:
            for line in f.readlines():
                parts = line.strip().split(",")
                if parts[0] == "CLIENT_LIST" and len(parts) >= 7:
                    user = parts[1]
                    try:
                        rx = int(parts[5]); tx = int(parts[6])
                        live_traffic[user] = {"rx": rx, "tx": tx}
                        live_rx += rx; live_tx += tx
                    except ValueError: pass
    except Exception: pass
    return live_traffic, live_rx, live_tx

def get_warp_status():
    try:
        out = subprocess.check_output(['wg-quick', 'show', 'wgcf'], stderr=subprocess.STDOUT).decode('utf-8')
        if 'interface: wgcf' in out: return 'Active (Connected)'
        return 'Disconnected'
    except Exception:
        return 'Not Installed'

@app.route('/api/sysinfo')
def sysinfo():
    if 'admin_logged_in' not in session: return {"error": "unauthorized"}, 401
    return {
        "cpu": psutil.cpu_percent(interval=None),
        "cpu_cores": psutil.cpu_percent(interval=None, percpu=True),
        "ram_percent": psutil.virtual_memory().percent,
        "ram_used": format_bytes(psutil.virtual_memory().used),
        "ram_total": format_bytes(psutil.virtual_memory().total),
        "disk_percent": psutil.disk_usage('/').percent,
        "disk_used": format_bytes(psutil.disk_usage('/').used),
        "disk_total": format_bytes(psutil.disk_usage('/').total),
        "net_rx": psutil.net_io_counters().bytes_recv,
        "net_tx": psutil.net_io_counters().bytes_sent
    }

@app.route('/')
def index():
    admin = get_db().execute('SELECT * FROM admin').fetchone()
    if not admin: return redirect(url_for('setup_wizard'))
    settings = get_db().execute('SELECT * FROM settings').fetchone()
    if settings and settings['is_installed'] == 0: return render_template('loading.html')
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    return redirect(url_for('dashboard'))

@app.route('/setup', methods=['GET', 'POST'])
def setup_wizard():
    if request.method == 'POST':
        conn = get_db()
        preset = request.form['dns_preset']
        dns1 = request.form.get('custom_dns1', '8.8.8.8') if preset == 'custom' else preset
        dns2 = request.form.get('custom_dns2', '') if preset == 'custom' else '1.0.0.1' if dns1=='1.1.1.1' else '8.8.4.4' if dns1=='8.8.8.8' else '149.112.112.112' if dns1=='9.9.9.9' else '94.140.15.15' if dns1=='94.140.14.14' else ''
        selected_protocol = request.form.get('protocol')
        selected_port = request.form.get('port')

        os.system(f"ufw allow {selected_port}/{selected_protocol} >/dev/null 2>&1")
        os.system(f"iptables -I INPUT -p {selected_protocol} --dport {selected_port} -j ACCEPT")
        os.system("netfilter-persistent save > /dev/null 2>&1")

        conn.execute('INSERT INTO admin (username, password) VALUES (?, ?)', (request.form['admin_user'], request.form['admin_pass']))
        conn.execute('INSERT INTO settings (server_name, protocol, port, dns, dns2, conn_limit, panel_port, is_installed) VALUES (?, ?, ?, ?, ?, ?, 2020, 0)', 
                    (request.form.get('server_name'), selected_protocol, selected_port, dns1, dns2, request.form.get('conn_limit')))
        conn.commit(); conn.close()
        return redirect(url_for('index'))
    return render_template('setup.html')

@app.route('/stream')
def stream():
    conn = get_db()
    settings = conn.execute('SELECT is_installed FROM settings').fetchone()
    conn.close()
    if settings and settings['is_installed'] == 1:
        def fake_generate(): yield "data: [DONE]\n\n"
        return Response(fake_generate(), mimetype='text/event-stream')

    def generate():
        process = subprocess.Popen(['bash', f'{APP_DIR}/module_openvpn.sh', '--install'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in iter(process.stdout.readline, ''): yield f"data: {line}\n\n"
        process.stdout.close()
        conn = get_db()
        conn.execute('UPDATE settings SET is_installed = 1')
        conn.commit(); conn.close()
        yield "data: [DONE]\n\n"
    return Response(generate(), mimetype='text/event-stream')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        conn = get_db()
        admin = conn.execute('SELECT * FROM admin WHERE username = ? AND password = ?', (request.form['username'], request.form['password'])).fetchone()
        conn.close()
        if admin:
            session['admin_logged_in'] = True
            return redirect(url_for('dashboard'))
        return render_template('login.html', error="Invalid Credentials")
    return render_template('login.html')

@app.route('/dashboard', methods=['GET', 'POST'])
def dashboard():
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    if request.method == 'POST':
        disp_name = request.form.get('new_user')
        sys_name = re.sub(r'[^a-zA-Z0-9]', '_', disp_name).lower()
        p = request.form.get('new_pass')
        exp = int(request.form.get('exp_days', 0))
        ts = 0 if exp == 0 else int(time.time()) + (exp * 86400)
        
        if not conn.execute('SELECT 1 FROM users WHERE system_name = ?', (sys_name,)).fetchone():
            conn.execute('INSERT INTO users (display_name, system_name, password, exp_days, status, rx, tx) VALUES (?, ?, ?, ?, ?, 0, 0)', (disp_name, sys_name, p, ts, 'active'))
            conn.commit()
            with open("/etc/openvpn/server/auth/users.db", "w") as f:
                for u in conn.execute('SELECT system_name, password, exp_days, status FROM users').fetchall():
                    f.write(f"{u['system_name']}:{u['password']}:{u['exp_days']}:{u['status']}\n")
            os.system(f"bash {APP_DIR}/module_openvpn.sh --add-user {sys_name} {p}")
        return redirect(url_for('dashboard'))

    users = conn.execute('SELECT * FROM users').fetchall()
    settings = conn.execute('SELECT * FROM settings').fetchone()
    conn.close()
    
    live_traffic, live_t_rx, live_t_tx = get_traffic()
    user_stats = {}
    total_server_rx = live_t_rx
    total_server_tx = live_t_tx
    
    for u in users:
        sys = u['system_name']
        saved_rx = int(u['rx']) if u['rx'] else 0
        saved_tx = int(u['tx']) if u['tx'] else 0
        active_rx = live_traffic.get(sys, {}).get('rx', 0)
        active_tx = live_traffic.get(sys, {}).get('tx', 0)
        user_stats[sys] = {"usage": saved_rx + saved_tx + active_rx + active_tx, "online": sys in live_traffic}
        total_server_rx += saved_rx; total_server_tx += saved_tx

    warp_stat = get_warp_status()
    psutil.cpu_percent(interval=None); psutil.cpu_percent(interval=None, percpu=True)
    return render_template('dashboard.html', users=users, settings=settings, stats=user_stats, t_rx=total_server_rx, t_tx=total_server_tx, current_time=int(time.time()), warp_status=warp_stat)

@app.route('/settings', methods=['GET', 'POST'])
def sys_settings():
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    if request.method == 'POST':
        curr_settings = conn.execute('SELECT * FROM settings').fetchone()
        old_panel_port = curr_settings['panel_port']
        old_vpn_port = curr_settings['port']
        old_vpn_proto = curr_settings['protocol']
        
        preset = request.form['dns_preset']
        dns1 = request.form.get('custom_dns1', '8.8.8.8') if preset == 'custom' else preset
        dns2 = request.form.get('custom_dns2', '') if preset == 'custom' else '1.0.0.1' if dns1=='1.1.1.1' else '8.8.4.4' if dns1=='8.8.8.8' else '149.112.112.112' if dns1=='9.9.9.9' else '94.140.15.15' if dns1=='94.140.14.14' else ''

        new_limit = request.form.get('conn_limit')
        new_panel_port = int(request.form.get('panel_port'))
        new_vpn_port = int(request.form.get('vpn_port'))
        new_vpn_proto = request.form.get('vpn_protocol')
        
        conn.execute('UPDATE settings SET dns=?, dns2=?, conn_limit=?, panel_port=?, port=?, protocol=?', (dns1, dns2, new_limit, new_panel_port, new_vpn_port, new_vpn_proto))
                     
        if request.form.get('admin_user') and request.form.get('admin_pass'):
            conn.execute('DELETE FROM admin')
            conn.execute('INSERT INTO admin (username, password) VALUES (?, ?)', (request.form['admin_user'], request.form['admin_pass']))
        conn.commit()

        needs_vpn_restart = False
        if dns1 != curr_settings['dns'] or dns2 != dict(curr_settings).get('dns2') or new_limit != curr_settings['conn_limit']:
            try:
                with open('/etc/openvpn/server/server.conf', 'r') as f:
                    lines = f.readlines()
                with open('/etc/openvpn/server/server.conf', 'w') as f:
                    for line in lines:
                        if 'push "dhcp-option DNS' in line or 'duplicate-cn' in line:
                            continue
                        f.write(line)
                    f.write(f'push "dhcp-option DNS {dns1}"\n')
                    if dns2: f.write(f'push "dhcp-option DNS {dns2}"\n')
                    if new_limit == "unlimited": f.write('duplicate-cn\n')
                needs_vpn_restart = True
            except Exception as e:
                pass

        if new_vpn_port != old_vpn_port or new_vpn_proto != old_vpn_proto:
            os.system(f"sed -i 's/^port .*/port {new_vpn_port}/' /etc/openvpn/server/server.conf")
            os.system(f"sed -i 's/^proto .*/proto {new_vpn_proto}/' /etc/openvpn/server/server.conf")
            os.system(f"ufw delete allow {old_vpn_port}/{old_vpn_proto} >/dev/null 2>&1")
            os.system(f"ufw allow {new_vpn_port}/{new_vpn_proto} >/dev/null 2>&1")
            os.system(f"iptables -D INPUT -p {old_vpn_proto} --dport {old_vpn_port} -j ACCEPT")
            os.system(f"iptables -I INPUT -p {new_vpn_proto} --dport {new_vpn_port} -j ACCEPT")
            os.system("netfilter-persistent save > /dev/null 2>&1")
            needs_vpn_restart = True

        if needs_vpn_restart: os.system("systemctl restart openvpn-server@server")

        if new_panel_port != old_panel_port:
            os.system(f"ufw delete allow {old_panel_port}/tcp >/dev/null 2>&1")
            os.system(f"ufw allow {new_panel_port}/tcp >/dev/null 2>&1")
            os.system(f"iptables -D INPUT -p tcp --dport {old_panel_port} -j ACCEPT")
            os.system(f"iptables -I INPUT -p tcp --dport {new_panel_port} -j ACCEPT")
            os.system("netfilter-persistent save > /dev/null 2>&1")
            os.system(f"sed -i 's/:{old_panel_port} /:{new_panel_port} /g' /etc/systemd/system/bluefalcon-panel.service")
            os.system("nohup bash -c 'sleep 1 && systemctl daemon-reload && systemctl restart bluefalcon-panel' >/dev/null 2>&1 &")
            
        return redirect(url_for('dashboard'))
        
    settings = conn.execute('SELECT * FROM settings').fetchone()
    admin = conn.execute('SELECT * FROM admin').fetchone()
    return render_template('settings.html', settings=settings, admin=admin)

@app.route('/toggle/<sys_name>')
def toggle(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    user = conn.execute('SELECT status FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    new_status = 'paused' if user['status'] == 'active' else 'active'
    conn.execute('UPDATE users SET status = ? WHERE system_name = ?', (new_status, sys_name))
    conn.commit()
    with open("/etc/openvpn/server/auth/users.db", "w") as f:
        for u in conn.execute('SELECT system_name, password, exp_days, status FROM users').fetchall(): 
            f.write(f"{u['system_name']}:{u['password']}:{u['exp_days']}:{u['status']}\n")
    if new_status == 'paused': os.system(f"echo -e 'kill {sys_name}\\nquit' | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &")
    return redirect(url_for('dashboard'))

@app.route('/revoke/<sys_name>')
def revoke(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    get_db().execute('DELETE FROM users WHERE system_name = ?', (sys_name,)).connection.commit()
    os.system(f"sed -i '/^{sys_name}:/d' /etc/openvpn/server/auth/users.db")
    os.system(f"echo -e 'kill {sys_name}\\nquit' | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &")
    os.system(f"cd {APP_DIR}/easy-rsa && ./easyrsa --batch revoke {sys_name} && ./easyrsa gen-crl")
    os.system(f"cp {APP_DIR}/easy-rsa/pki/crl.pem /etc/openvpn/server/ && chmod 644 /etc/openvpn/server/crl.pem")
    os.system(f"rm -f {APP_DIR}/configs/{sys_name}.ovpn")
    os.system(f"rm -f {APP_DIR}/configs/{sys_name}_manual.ovpn")
    return redirect(url_for('dashboard'))

@app.route('/download/<sys_name>')
def download(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    u = get_db().execute('SELECT display_name FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    s = get_db().execute('SELECT server_name FROM settings').fetchone()
    file_path = f'{APP_DIR}/configs/{sys_name}.ovpn'
    if not os.path.exists(file_path): return "Error 404: Configuration file not found.", 404
    custom_name = f"{s['server_name']} - {u['display_name']} (Auto-Login).ovpn"
    try: return send_file(file_path, as_attachment=True, download_name=custom_name)
    except TypeError: return send_file(file_path, as_attachment=True, attachment_filename=custom_name)

@app.route('/download_manual/<sys_name>')
def download_manual(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    u = get_db().execute('SELECT display_name FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    s = get_db().execute('SELECT server_name FROM settings').fetchone()
    file_path = f'{APP_DIR}/configs/{sys_name}_manual.ovpn'
    if not os.path.exists(file_path): return "Error 404: Configuration file not found.", 404
    custom_name = f"{s['server_name']} - {u['display_name']} (User-Login).ovpn"
    try: return send_file(file_path, as_attachment=True, download_name=custom_name)
    except TypeError: return send_file(file_path, as_attachment=True, attachment_filename=custom_name)

@app.route('/warp/<action>')
def warp_engine(action):
    if 'admin_logged_in' in session and action in ['install', 'toggle', 'uninstall']:
        os.system(f"cd {APP_DIR} && bash module_warp.sh --{action}")
    return redirect(url_for('dashboard'))

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

if __name__ == '__main__': app.run(host='0.0.0.0', port=2020)
EOF_APP

    # ==========================================
    # --- HTML TEMPLATES ---
    # ==========================================
    cat << 'EOF_BASE' > "${APP_DIR}/panel/templates/base.html"
<!DOCTYPE html><html lang="en"><head><title>{% block title %}{% endblock %} | BlueFalcon Panel</title>
<script src="https://cdn.tailwindcss.com"></script><script src="https://cdn.jsdelivr.net/npm/chart.js"></script></head>
<body class="bg-gray-900 text-gray-200 font-sans min-h-screen">
<nav class="bg-gray-800 border-b border-gray-700 px-6 py-4 flex justify-between items-center">
<div class="text-2xl font-bold text-emerald-400 tracking-wider">🦅 BlueFalcon Panel</div>
<div class="flex items-center gap-4">
<a href="/dashboard" class="text-gray-400 hover:text-emerald-400 transition">📊 Dashboard</a>
<a href="/settings" class="text-gray-400 hover:text-emerald-400 transition">⚙️ Settings</a>
<a href="/logout" class="text-gray-400 hover:text-rose-400 transition">Logout</a>
</div></nav>
<div class="max-w-6xl mx-auto px-6 py-8">{% block content %}{% endblock %}</div></body></html>
EOF_BASE

    cat << 'EOF_SETUP_HTML' > "${APP_DIR}/panel/templates/setup.html"
<!DOCTYPE html><html lang="en"><head><title>Setup | BlueFalcon Web Panel</title><script src="https://cdn.tailwindcss.com"></script></head>
<body class="bg-gray-900 text-gray-200 min-h-screen flex items-center justify-center p-6">
<div class="bg-gray-800 p-8 rounded-xl shadow-2xl w-full max-w-2xl border border-gray-700">
<h1 class="text-3xl font-bold text-emerald-400 text-center mb-8">🦅 BlueFalcon Web Panel</h1>
<form action="/setup" method="POST" class="space-y-6">
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
<input type="text" name="admin_user" placeholder="Admin Username" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="password" name="admin_pass" placeholder="Admin Password" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="text" name="server_name" value="VPN-Server" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<select name="protocol" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="udp">UDP</option><option value="tcp">TCP</option></select>
<input type="number" name="port" value="1194" required class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<select name="conn_limit" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="1">Limit: 1 Device per User</option><option value="unlimited">Limit: Unlimited Devices</option></select>
<select name="dns_preset" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white md:col-span-2" onchange="document.getElementById('custom_dns_div').style.display = this.value === 'custom' ? 'grid' : 'none';">
<option value="1.1.1.1">Cloudflare (1.1.1.1 / 1.0.0.1)</option><option value="8.8.8.8">Google (8.8.8.8 / 8.8.4.4)</option><option value="9.9.9.9">Quad9 (9.9.9.9)</option><option value="94.140.14.14">AdGuard (94.140.14.14)</option><option value="custom">Custom IP...</option></select>
<div id="custom_dns_div" class="grid grid-cols-1 md:grid-cols-2 gap-4 md:col-span-2" style="display:none;">
<input type="text" name="custom_dns1" placeholder="Primary DNS (e.g. 1.0.0.1)" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="text" name="custom_dns2" placeholder="Secondary DNS (Optional)" class="w-full bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white">
</div></div>
<button type="submit" class="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-3 px-4 rounded-lg">Initialize System</button>
</form></div></body></html>
EOF_SETUP_HTML

    cat << 'EOF_SETTINGS_HTML' > "${APP_DIR}/panel/templates/settings.html"
{% extends 'base.html' %}
{% block title %}Settings{% endblock %}
{% block content %}
<div class="max-w-2xl mx-auto px-6 py-8">
<form action="/settings" method="POST" class="space-y-6">
<div class="bg-gray-800 p-6 rounded-xl border border-gray-700"><h2 class="text-xl font-bold text-white mb-4">VPN Routing & Limits</h2>
<div class="space-y-4">
<div><label class="block text-gray-400 text-sm mb-1">OpenVPN Protocol</label>
<select name="vpn_protocol" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="udp" {% if settings['protocol'] == 'udp' %}selected{% endif %}>UDP</option><option value="tcp" {% if settings['protocol'] == 'tcp' %}selected{% endif %}>TCP</option></select></div>
<div><label class="block text-gray-400 text-sm mb-1">OpenVPN Port</label><input type="number" name="vpn_port" value="{{ settings['port'] }}" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
<div><label class="block text-gray-400 text-sm mb-1">Connection Limit</label><select name="conn_limit" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"><option value="1" {% if settings['conn_limit'] == '1' %}selected{% endif %}>1 Device</option><option value="unlimited" {% if settings['conn_limit'] == 'unlimited' %}selected{% endif %}>Unlimited</option></select></div>
<div><label class="block text-gray-400 text-sm mb-1">DNS Server</label>
<select name="dns_preset" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white" onchange="document.getElementById('custom_dns_div').style.display = this.value === 'custom' ? 'grid' : 'none';">
<option value="1.1.1.1" {% if settings['dns'] == '1.1.1.1' %}selected{% endif %}>Cloudflare</option><option value="8.8.8.8" {% if settings['dns'] == '8.8.8.8' %}selected{% endif %}>Google</option><option value="9.9.9.9" {% if settings['dns'] == '9.9.9.9' %}selected{% endif %}>Quad9</option><option value="custom" {% if settings['dns'] not in ['1.1.1.1', '8.8.8.8', '9.9.9.9', '94.140.14.14'] %}selected{% endif %}>Custom IP...</option></select>
<div id="custom_dns_div" class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2" style="display: {% if settings['dns'] not in ['1.1.1.1', '8.8.8.8', '9.9.9.9', '94.140.14.14'] %}grid{% else %}none{% endif %};">
<input type="text" name="custom_dns1" value="{{ settings['dns'] if settings['dns'] not in ['1.1.1.1', '8.8.8.8', '9.9.9.9', '94.140.14.14'] else '' }}" placeholder="Primary DNS" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="text" name="custom_dns2" value="{{ settings['dns2'] if settings['dns2'] else '' }}" placeholder="Secondary DNS (Optional)" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
</div></div>
</div></div>
<div class="bg-gray-800 p-6 rounded-xl border border-gray-700"><h2 class="text-xl font-bold text-white mb-4">Panel Configuration</h2>
<div class="space-y-4">
<div><label class="block text-gray-400 text-sm mb-1">Web Panel Port</label><input type="number" name="panel_port" value="{{ settings['panel_port'] }}" class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
<div><label class="block text-gray-400 text-sm mb-1">Update Admin Credentials</label>
<div class="grid grid-cols-2 gap-4">
<input type="text" name="admin_user" value="{{ admin['username'] }}" required class="bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="password" name="admin_pass" placeholder="New Password" required class="bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
</div></div></div></div>
<button type="submit" class="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-3 rounded-lg">Save & Apply System Changes</button>
</form></div>
{% endblock %}
EOF_SETTINGS_HTML

    cat << 'EOF_LOGIN_HTML' > "${APP_DIR}/panel/templates/login.html"
<!DOCTYPE html><html lang="en"><head><title>Login | BlueFalcon Panel</title><script src="https://cdn.tailwindcss.com"></script></head>
<body class="bg-gray-900 text-gray-200 min-h-screen flex items-center justify-center p-6">
<div class="bg-gray-800 p-8 rounded-xl shadow-2xl w-full max-w-sm border border-gray-700">
<h1 class="text-2xl font-bold text-emerald-400 mb-6 text-center">🦅 BlueFalcon Panel<br><span class="text-lg text-gray-400">Authentication</span></h1>
{% if error %}<p class="text-red-400 text-sm text-center mb-4">{{ error }}</p>{% endif %}
<form action="/login" method="POST" class="space-y-4">
<input type="text" name="username" placeholder="Username" required class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<input type="password" name="password" placeholder="Password" required class="w-full bg-gray-900 border border-gray-600 rounded-md py-2 px-3 text-white">
<button type="submit" class="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-2 rounded-lg">Log In</button>
</form></div></body></html>
EOF_LOGIN_HTML

    cat << 'EOF_LOADING_HTML' > "${APP_DIR}/panel/templates/loading.html"
<!DOCTYPE html><html lang="en"><head><title>Installing | BlueFalcon Panel</title><script src="https://cdn.tailwindcss.com"></script></head>
<body class="bg-gray-900 text-gray-200 min-h-screen flex items-center justify-center p-6">
<div class="bg-gray-800 p-8 rounded-xl shadow-2xl w-full max-w-3xl border border-gray-700">
<h1 class="text-2xl font-bold text-emerald-400 mb-4 animate-pulse">Installing Core Protocols...</h1>
<div id="terminal" class="bg-black p-4 rounded-lg h-80 overflow-y-auto font-mono text-sm text-green-400 border border-gray-700 whitespace-pre-wrap"></div>
</div>
<script>
const terminal = document.getElementById('terminal');
const source = new EventSource('/stream');
source.onmessage = function(event) {
    if(event.data === '[DONE]') {
        terminal.innerHTML += '\n<span class="text-white bg-emerald-600 px-2 py-1 rounded">INSTALLATION COMPLETE. REDIRECTING...</span>';
        source.close(); setTimeout(() => window.location.href = '/login', 2000); return;
    }
    terminal.innerHTML += event.data + '\n'; terminal.scrollTop = terminal.scrollHeight;
};
</script></body></html>
EOF_LOADING_HTML

    cat << 'EOF_DASHBOARD_HTML' > "${APP_DIR}/panel/templates/dashboard.html"
{% extends 'base.html' %}
{% block title %}Dashboard{% endblock %}
{% block content %}
<div class="bg-gray-800 rounded-xl border border-gray-700 shadow-lg mb-8 p-6">
    <h2 class="text-lg font-bold text-white mb-6">Live System Monitor</h2>
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-start h-full">
            <div class="relative w-full max-w-[160px] aspect-[2/1] mt-2">
                <canvas id="cpuChart"></canvas>
                <div class="absolute inset-0 flex items-end justify-center pb-1">
                    <span class="text-xl font-bold text-emerald-400" id="cpu_val">--%</span>
                </div>
            </div>
            <p class="text-sm text-gray-400 mt-4 font-bold tracking-wider mb-2">CPU</p>
            <div id="cpu_cores_container" class="w-full mt-auto grid grid-cols-2 gap-x-3 gap-y-2"></div>
        </div>
        <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-start h-full">
            <div class="relative w-full max-w-[160px] aspect-[2/1] mt-2">
                <canvas id="ramChart"></canvas>
                <div class="absolute inset-0 flex items-end justify-center pb-1">
                    <span class="text-xl font-bold text-blue-400" id="ram_val">--%</span>
                </div>
            </div>
            <p class="text-sm text-gray-400 mt-4 font-bold tracking-wider">RAM</p>
            <p class="text-xs text-gray-500 mt-1 font-mono" id="ram_detail">-- / --</p>
        </div>
        <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-start h-full">
            <div class="relative w-full max-w-[160px] aspect-[2/1] mt-2">
                <canvas id="diskChart"></canvas>
                <div class="absolute inset-0 flex items-end justify-center pb-1">
                    <span class="text-xl font-bold text-purple-400" id="disk_val">--%</span>
                </div>
            </div>
            <p class="text-sm text-gray-400 mt-4 font-bold tracking-wider">STORAGE</p>
            <p class="text-xs text-gray-500 mt-1 font-mono" id="disk_detail">-- / --</p>
        </div>
        <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 flex flex-col items-center justify-center h-full">
            <p class="text-sm text-gray-400 mb-4 font-bold tracking-wider">NETWORK TRAFFIC</p>
            <div class="flex flex-col gap-3 w-full px-4">
                <div class="bg-gray-800 p-3 rounded border border-gray-700 flex justify-between items-center">
                    <span class="text-emerald-400 font-bold">↓ DL</span>
                    <span class="text-emerald-400 font-mono" id="net_rx_val">0 KB/s</span>
                </div>
                <div class="bg-gray-800 p-3 rounded border border-gray-700 flex justify-between items-center">
                    <span class="text-rose-400 font-bold">↑ UL</span>
                    <span class="text-rose-400 font-mono" id="net_tx_val">0 KB/s</span>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
    <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-lg">
        <h2 class="text-lg font-bold text-white mb-4">🛡️ OpenVPN Engine</h2>
        <div class="grid grid-cols-2 gap-4">
            <div class="bg-gray-900 p-4 rounded-lg border border-gray-700"><h3 class="text-gray-400 text-sm font-medium">Protocol / Port</h3><p class="text-xl text-white mt-1 uppercase">{{ settings['protocol'] }} <span class="text-emerald-400">/ {{ settings['port'] }}</span></p></div>
            <div class="bg-gray-900 p-4 rounded-lg border border-gray-700"><h3 class="text-gray-400 text-sm font-medium">Device Limit</h3><p class="text-xl text-white mt-1 capitalize">{{ settings['conn_limit'] }}</p></div>
            <div class="bg-emerald-900/20 p-4 rounded-lg border border-emerald-700/50 col-span-2"><h3 class="text-emerald-400/80 text-sm font-medium">Server Traffic Masking</h3><p class="text-lg text-emerald-400 mt-1">↓ {{ t_rx|format_bytes }} &nbsp; ↑ {{ t_tx|format_bytes }}</p></div>
        </div>
    </div>
    <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-lg">
        <h2 class="text-lg font-bold text-white mb-4">🌐 Cloudflare WARP Engine</h2>
        <div class="bg-gray-900 p-4 rounded-lg border border-gray-700 mb-4 text-center">
            <h3 class="text-gray-400 text-sm font-medium">Current Status</h3>
            <p class="text-xl font-bold mt-1 {% if 'Connected' in warp_status %}text-emerald-400{% elif 'Disconnected' in warp_status %}text-yellow-400{% else %}text-red-400{% endif %}">{{ warp_status }}</p>
        </div>
        <div class="grid grid-cols-3 gap-2">
            <a href="/warp/install" class="bg-blue-600 hover:bg-blue-500 text-white text-center py-2 rounded text-sm font-bold transition">Install</a>
            <a href="/warp/toggle" class="bg-gray-700 hover:bg-gray-600 text-white text-center py-2 rounded text-sm font-bold transition">Toggle</a>
            <a href="/warp/uninstall" onclick="return confirm('Completely remove WARP routing?')" class="bg-red-600 hover:bg-red-500 text-white text-center py-2 rounded text-sm font-bold transition">Uninstall</a>
        </div>
    </div>
</div>

<div class="bg-gray-800 rounded-xl border border-gray-700 shadow-lg overflow-hidden">
    <div class="p-6 border-b border-gray-700 bg-gray-900">
        <form action="/dashboard" method="POST" class="flex flex-wrap gap-4 items-end">
            <div><label class="block text-sm font-medium text-gray-400 mb-1">Display Name</label><input type="text" name="new_user" required class="bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
            <div><label class="block text-sm font-medium text-gray-400 mb-1">Password</label><input type="text" name="new_pass" required class="bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white"></div>
            <div><label class="block text-sm font-medium text-gray-400 mb-1">Expiry (Days)</label><input type="number" name="exp_days" value="0" min="0" required class="bg-gray-800 border border-gray-600 rounded-md py-2 px-3 text-white w-24"></div>
            <button type="submit" class="bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-2 px-4 rounded transition">+ Generate Profile</button>
        </form>
    </div>
    <div class="p-6 overflow-x-auto">
        <table class="w-full text-left border-collapse">
            <thead>
                <tr class="text-gray-400 text-sm border-b border-gray-700"><th class="pb-3">User</th><th class="pb-3">Status</th><th class="pb-3">Total Data Usage</th><th class="pb-3">Time Left</th><th class="pb-3 text-right">Actions</th></tr>
            </thead>
            <tbody>
                {% for user in users %}
                <tr class="border-b border-gray-700/50">
                    <td class="py-4 text-white font-medium">{{ user['display_name'] }} <span class="text-xs text-gray-500 block">sys: {{ user['system_name'] }}</span></td>
                    <td class="py-4">
                        {% if user['status'] == 'paused' %} <span class="bg-orange-900/50 text-orange-400 px-2 py-1 rounded text-xs">⏸ Paused</span>
                        {% elif stats[user['system_name']]['online'] %} <span class="bg-green-900/50 text-green-400 px-2 py-1 rounded text-xs">● Online</span>
                        {% else %} <span class="bg-gray-700/50 text-gray-400 px-2 py-1 rounded text-xs">Offline</span> {% endif %}
                    </td>
                    <td class="py-4 text-sm text-gray-300">{{ stats[user['system_name']]['usage']|format_bytes }}</td>
                    <td class="py-4 text-sm text-gray-400">{% if user['exp_days'] == 0 %} Unlimited {% elif user['exp_days'] < current_time %} <span class="text-red-400">Expired</span> {% else %} {{ ((user['exp_days'] - current_time) / 86400) | round(1) }} Days {% endif %}</td>
                    <td class="py-4 text-right space-x-2 whitespace-nowrap">
                        <a href="/toggle/{{ user['system_name'] }}" class="bg-gray-700 hover:bg-gray-600 text-white px-2.5 py-1.5 rounded text-sm transition">{% if user['status'] == 'paused' %}▶ Resume{% else %}⏸ Pause{% endif %}</a>
                        <a href="/download/{{ user['system_name'] }}" class="bg-blue-600 hover:bg-blue-500 text-white px-2.5 py-1.5 rounded text-sm transition font-medium">Auto-Login</a>
                        <a href="/download_manual/{{ user['system_name'] }}" class="bg-indigo-600 hover:bg-indigo-500 text-white px-2.5 py-1.5 rounded text-sm transition font-medium">User-Login</a>
                        <a href="/revoke/{{ user['system_name'] }}" onclick="return confirm('Delete and revoke user forever?')" class="bg-red-600 hover:bg-red-500 text-white px-2.5 py-1.5 rounded text-sm transition">Revoke</a>
                    </td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
</div>
<script>
    const chartOptions = { responsive: true, maintainAspectRatio: false, cutout: '82%', circumference: 180, rotation: -90, plugins: { tooltip: { enabled: false }, legend: { display: false } }, animation: { duration: 0 } };
    const createDonut = (ctxId, color) => new Chart(document.getElementById(ctxId).getContext('2d'), { type: 'doughnut', data: { datasets: [{ data: [0, 100], backgroundColor: [color, '#374151'], borderWidth: 0, borderRadius: 2 }] }, options: chartOptions });
    const cpuChart = createDonut('cpuChart', '#34d399'); const ramChart = createDonut('ramChart', '#60a5fa'); const diskChart = createDonut('diskChart', '#c084fc');
    let lastRx = 0, lastTx = 0, firstPoll = true;
    function formatSpeed(bytes) { if (bytes < 1024) return bytes + " B/s"; else if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB/s"; else return (bytes / 1048576).toFixed(2) + " MB/s"; }
    setInterval(() => {
        fetch('/api/sysinfo').then(r => r.json()).then(data => {
            document.getElementById('cpu_val').innerText = data.cpu + '%'; cpuChart.data.datasets[0].data = [data.cpu, 100 - data.cpu]; cpuChart.update();
            const coresContainer = document.getElementById('cpu_cores_container'); coresContainer.innerHTML = '';
            if (data.cpu_cores && data.cpu_cores.length > 0) {
                data.cpu_cores.forEach((coreLoad, index) => {
                    coresContainer.insertAdjacentHTML('beforeend', `<div class="flex flex-col"><div class="flex justify-between text-[10px] text-gray-500 mb-0.5"><span>C${index}</span><span class="text-emerald-400/80">${coreLoad.toFixed(1)}%</span></div><div class="w-full bg-gray-800 rounded-full h-1"><div class="bg-emerald-500 h-1 rounded-full" style="width: ${coreLoad}%"></div></div></div>`);
                });
            }
            document.getElementById('ram_val').innerText = data.ram_percent + '%'; document.getElementById('ram_detail').innerText = data.ram_used + ' / ' + data.ram_total; ramChart.data.datasets[0].data = [data.ram_percent, 100 - data.ram_percent]; ramChart.update();
            document.getElementById('disk_val').innerText = data.disk_percent + '%'; document.getElementById('disk_detail').innerText = data.disk_used + ' / ' + data.disk_total; diskChart.data.datasets[0].data = [data.disk_percent, 100 - data.disk_percent]; diskChart.update();
            if (!firstPoll) {
                let rxSpeed = (data.net_rx - lastRx) / 2; let txSpeed = (data.net_tx - lastTx) / 2;
                document.getElementById('net_rx_val').innerText = formatSpeed(Math.max(0, rxSpeed)); document.getElementById('net_tx_val').innerText = formatSpeed(Math.max(0, txSpeed));
            }
            lastRx = data.net_rx; lastTx = data.net_tx; firstPoll = false;
        }).catch(err => console.error(err));
    }, 2000);
</script>
{% endblock %}
EOF_DASHBOARD_HTML

    # ==========================================
    # --- EXPIRY CRON JOB SCRIPT ---
    # ==========================================
    mkdir -p "${APP_DIR}/panel/scripts"
    cat << 'EOF_EXP' > "${APP_DIR}/panel/scripts/expiry.py"
import sqlite3, time, os
APP_DIR = '/opt/bluefalcon-ultimate-toolkit'
conn = sqlite3.connect(f'{APP_DIR}/panel/panel.db')
users = conn.execute('SELECT system_name, exp_days FROM users WHERE exp_days > 0').fetchall()
now = int(time.time())
for u in users:
    if u[1] < now:
        sys_name = u[0]
        conn.execute('DELETE FROM users WHERE system_name = ?', (sys_name,))
        os.system(f"sed -i '/^{sys_name}:/d' /etc/openvpn/server/auth/users.db")
        os.system(f"echo -e 'kill {sys_name}\\nquit' | nc -w 1 127.0.0.1 7505 > /dev/null 2>&1 &")
        os.system(f"cd {APP_DIR}/easy-rsa && ./easyrsa --batch revoke {sys_name} && ./easyrsa gen-crl")
        os.system(f"cp {APP_DIR}/easy-rsa/pki/crl.pem /etc/openvpn/server/ && chmod 644 /etc/openvpn/server/crl.pem")
        os.system(f"rm -f {APP_DIR}/configs/{sys_name}.ovpn")
        os.system(f"rm -f {APP_DIR}/configs/{sys_name}_manual.ovpn")
conn.commit()
conn.close()
EOF_EXP

    cat > /etc/cron.daily/bluefalcon-panel-expiry << EOF
#!/bin/bash
python3 ${APP_DIR}/panel/scripts/expiry.py
EOF
    chmod +x /etc/cron.daily/bluefalcon-panel-expiry

    # ==========================================
    # --- SYSTEMD SERVICE REGISTRATION ---
    # ==========================================
    cat > /etc/systemd/system/bluefalcon-panel.service << EOF
[Unit]
Description=BlueFalcon Universal Web Panel
After=network.target

[Service]
User=root
WorkingDirectory=${APP_DIR}/panel
ExecStart=/usr/bin/gunicorn -w 2 -b 0.0.0.0:2020 --timeout 600 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now bluefalcon-panel
}

uninstall_panel() {
    clear
    echo -e "\n${BOLD_BLUE}--- Uninstalling OpenVPN & Web Panel ---${NC}\n"
    read -rp "Are you sure? All user data will be lost. (y/N): " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        systemctl stop bluefalcon-panel openvpn-server@server 2>/dev/null
        systemctl disable bluefalcon-panel openvpn-server@server 2>/dev/null
        apt-get remove --purge -y openvpn iptables-persistent python3-psutil
        rm -rf ${APP_DIR} /etc/openvpn /etc/systemd/system/bluefalcon-panel.service /var/log/bluefalcon-panel /var/log/openvpn /etc/cron.daily/bluefalcon-panel-expiry
        systemctl daemon-reload
        echo -e "\n[ ${GREEN}✔${NC} ] System cleanly wiped."
    else
        echo -e "\n[ ${YELLOW}✖${NC} ] Uninstallation canceled."
    fi
}

view_panel_logs() {
    clear
    echo -e "${BOLD_BLUE}--- Web Panel Logs ---${NC}\nStreaming real-time service logs. Press Ctrl+C to exit.\n"
    trap 'true' SIGINT
    journalctl -u bluefalcon-panel -f -n 50
    trap cleanup SIGINT SIGTERM
}

# ==============================================================================
# 2. UI Switchboard (Interactive Menu)
# ==============================================================================
manage_panel_menu() {
    while true; do
        clear
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo -e "${BOLD_BLUE}              Universal Web Dashboard                ${NC}"
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        
        IPV4=$(curl -s -4 ifconfig.me || echo "Unknown")
        PANEL_PORT="2020"
        ADMIN_USER="Not Set"
        
        if [ -f "${APP_DIR}/panel/panel.db" ]; then
            PANEL_PORT=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT panel_port FROM settings LIMIT 1;" 2>/dev/null)
            PANEL_PORT=${PANEL_PORT:-2020}
            ADMIN_USER=$(sqlite3 "${APP_DIR}/panel/panel.db" "SELECT username FROM admin LIMIT 1;" 2>/dev/null)
            ADMIN_USER=${ADMIN_USER:-"Not Set"}
        fi
        
        echo -e " Panel Link:          ${YELLOW}http://$IPV4:$PANEL_PORT${NC}"
        echo -e " Admin Username:      ${CYAN}${ADMIN_USER}${NC}"
        
        if systemctl is-active --quiet bluefalcon-panel; then echo -e " Web Panel:           [ ${GREEN}✔${NC} ] Active"; else echo -e " Web Panel:           [ ${RED}✖${NC} ] Offline"; fi
        
        echo -e "${BOLD_BLUE}-----------------------------------------------------${NC}"
        echo ""
        echo "1. Install & Start Web Panel (Port 2020)"
        echo "2. View Web Panel Logs"
        echo "3. Uninstall Dashboard & OpenVPN Data"
        echo "0. Return"
        echo ""
        
        read -rp "Select option: " p_choice
        case "$p_choice" in
            1) 
                if [ -n "${run_with_spinner:-}" ]; then
                    CURRENT_LOG="${LOG_FILE}" run_with_spinner "Building Web Environment" setup_panel_environment
                else
                    setup_panel_environment
                fi
                if [ -n "${pause_execution:-}" ]; then pause_execution; else sleep 2; fi
                ;;
            2) view_panel_logs ;;
            3) uninstall_panel; if [ -n "${pause_execution:-}" ]; then pause_execution; else sleep 2; fi ;;
            0) break ;;
            *) echo -e "\n[ ${RED}✖${NC} ] Invalid input." ; sleep 1.5 ;;
        esac
    done
}

action="${1:-menu}"
case "$action" in
    --install) setup_panel_environment ;;
    menu) manage_panel_menu ;;
esac