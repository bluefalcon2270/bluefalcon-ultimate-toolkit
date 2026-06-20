# /opt/bluefalcon-ultimate-toolkit/panel/app.py
from flask import Flask, render_template, request, redirect, url_for, session, send_file, Response, jsonify
import sqlite3, os, time, subprocess, re, psutil

app = Flask(__name__)
app.secret_key = 'BlueFalcon_Enterprise_Secret_Key_2026'
APP_DIR = '/opt/bluefalcon-ultimate-toolkit'
DB_PATH = f'{APP_DIR}/panel.db'
LOG_PATH = '/var/log/openvpn/status.log'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    conn.execute('CREATE TABLE IF NOT EXISTS admin (username TEXT, password TEXT)')
    conn.execute('CREATE TABLE IF NOT EXISTS settings (server_name TEXT, protocol TEXT, port INTEGER, dns TEXT, dns2 TEXT, conn_limit TEXT, panel_port INTEGER, is_installed INTEGER DEFAULT 0)')
    conn.execute('CREATE TABLE IF NOT EXISTS users (display_name TEXT, system_name TEXT, password TEXT, exp_days INTEGER, status TEXT, rx INTEGER DEFAULT 0, tx INTEGER DEFAULT 0)')
    conn.execute('CREATE TABLE IF NOT EXISTS warp (is_installed INTEGER DEFAULT 0)')
    conn.commit()
    conn.close()

init_db()

# --- Utility Functions ---
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

def format_bytes(b):
    if not isinstance(b, (int, float)): return "0.0 KB"
    if b < 1048576: return f"{b/1024:.1f} KB"
    elif b < 1073741824: return f"{b/1048576:.1f} MB"
    else: return f"{b/1073741824:.2f} GB"

app.jinja_env.filters['format_bytes'] = format_bytes

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

# --- Core Routing ---
@app.route('/')
def index():
    admin = get_db().execute('SELECT * FROM admin').fetchone()
    settings = get_db().execute('SELECT * FROM settings').fetchone()
    
    if not admin or not settings or settings['is_installed'] == 0: 
        return redirect(url_for('wizard'))
    
    if 'admin_logged_in' not in session: 
        return redirect(url_for('login'))
        
    return redirect(url_for('dashboard'))

# --- Master Setup Wizard ---
@app.route('/wizard', methods=['GET', 'POST'])
def wizard():
    if request.method == 'POST':
        conn = get_db()
        server_name = request.form.get('server_name', 'BlueFalcon Server')
        admin_user = request.form.get('admin_user', 'admin')
        admin_pass = request.form.get('admin_pass', 'admin')
        panel_port = int(request.form.get('panel_port', 2020))
        
        selected_protocol = request.form.get('protocol', 'udp')
        selected_port = int(request.form.get('port', 1194))
        preset = request.form.get('dns_preset', '1.1.1.1')
        dns1 = request.form.get('custom_dns1', '8.8.8.8') if preset == 'custom' else preset
        dns2 = request.form.get('custom_dns2', '') if preset == 'custom' else '1.0.0.1' if dns1=='1.1.1.1' else '8.8.4.4' if dns1=='8.8.8.8' else '149.112.112.112' if dns1=='9.9.9.9' else '94.140.15.15' if dns1=='94.140.14.14' else ''
        conn_limit = request.form.get('conn_limit', 'unlimited')

        install_warp = request.form.get('install_warp') == 'on'
        warp_target = request.form.get('warp_target', '3')
        warp_license = request.form.get('warp_license', 'free')

        os.system(f"ufw allow {selected_port}/{selected_protocol} >/dev/null 2>&1")
        os.system(f"iptables -I INPUT -p {selected_protocol} --dport {selected_port} -j ACCEPT")
        os.system("netfilter-persistent save > /dev/null 2>&1")

        conn.execute('DELETE FROM admin')
        conn.execute('INSERT INTO admin (username, password) VALUES (?, ?)', (admin_user, admin_pass))
        
        conn.execute('DELETE FROM settings')
        conn.execute('INSERT INTO settings (server_name, protocol, port, dns, dns2, conn_limit, panel_port, is_installed) VALUES (?, ?, ?, ?, ?, ?, ?, 0)', 
                    (server_name, selected_protocol, selected_port, dns1, dns2, conn_limit, panel_port))
        
        conn.execute('DELETE FROM warp')
        warp_status = -1 if install_warp else 0 
        conn.execute('INSERT INTO warp (is_installed) VALUES (?)', (warp_status,))
        
        conn.commit(); conn.close()
        
        if install_warp:
            with open('/tmp/warp_intent.txt', 'w') as f:
                f.write(f"{warp_target}\n{warp_license}")

        return redirect(url_for('stream_ui'))
    return render_template('wizard.html')

@app.route('/stream_ui')
def stream_ui():
    return render_template('stream.html')

@app.route('/api/install_execute')
def install_execute():
    def generate():
        conn = get_db()
        warp_pending = conn.execute('SELECT is_installed FROM warp').fetchone()[0] == -1
        conn.close()

        yield "data: 🦅 INITIALIZING BLUEFALCON DEPLOYMENT SEQUENCE\n\n"
        time.sleep(1)
        
        yield "data: \n\n"
        yield "data: [OPENVPN] Starting Core Configuration...\n\n"
        process = subprocess.Popen(['bash', f'{APP_DIR}/scripts/core_setup.sh'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in iter(process.stdout.readline, ''): yield f"data: {line}\n\n"
        process.stdout.close(); process.wait()
        
        if warp_pending:
            yield "data: \n\n"
            yield "data: [WARP] Starting Cloudflare Engine Deployment...\n\n"
            try:
                with open('/tmp/warp_intent.txt', 'r') as f:
                    target, license_key = f.read().splitlines()
            except:
                target, license_key = "3", "free"
                
            process2 = subprocess.Popen(['bash', f'{APP_DIR}/scripts/action.sh', 'install', target, license_key], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for line in iter(process2.stdout.readline, ''): yield f"data: {line}\n\n"
            process2.stdout.close(); process2.wait()
            
            conn = get_db()
            conn.execute('UPDATE warp SET is_installed=1')
            conn.commit(); conn.close()

        conn = get_db()
        conn.execute('UPDATE settings SET is_installed=1')
        conn.commit(); conn.close()
        
        yield "data: \n\n"
        yield "data: 🟢 DEPLOYMENT COMPLETE. REDIRECTING...\n\n"
        yield "data: [DONE]\n\n"

    return Response(generate(), mimetype='text/event-stream')

# --- Login & Dashboards ---
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

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/dashboard')
def dashboard():
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    settings = conn.execute('SELECT * FROM settings').fetchone()
    conn.close()
    _, t_rx, t_tx = get_traffic()
    return render_template('dashboard.html', settings=settings, t_rx=t_rx, t_tx=t_tx)

# --- OpenVPN Management (Split Route) ---
@app.route('/openvpn', methods=['GET', 'POST'])
def openvpn_dashboard():
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
            os.system(f"bash {APP_DIR}/scripts/add_user.sh {sys_name} {p}")
        return redirect(url_for('openvpn_dashboard'))

    users = conn.execute('SELECT * FROM users').fetchall()
    settings = conn.execute('SELECT * FROM settings').fetchone()
    conn.close()
    
    live_traffic, _, _ = get_traffic()
    user_stats = {}
    
    for u in users:
        sys = u['system_name']
        saved_rx = int(u['rx']) if u['rx'] else 0
        saved_tx = int(u['tx']) if u['tx'] else 0
        active_rx = live_traffic.get(sys, {}).get('rx', 0)
        active_tx = live_traffic.get(sys, {}).get('tx', 0)
        user_stats[sys] = {"usage": saved_rx + saved_tx + active_rx + active_tx, "online": sys in live_traffic}

    return render_template('openvpn.html', users=users, settings=settings, stats=user_stats, current_time=int(time.time()))

# --- WARP Routing ---
def get_warp_trace():
    vps_v4 = os.popen("ip -4 addr show $(ip route | awk '/default/ {print $5}' | head -1) | grep -oP '(?<=inet\s)\d+(\.\d+){3}'").read().strip() or "N/A"
    vps_v6 = os.popen("hostname -I | awk '{ for(i=1;i<=NF;i++) if($i~/^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{1,4}$/) {print $i; exit} }'").read().strip() or "N/A"
    trace_v4 = os.popen("curl -s4 https://www.cloudflare.com/cdn-cgi/trace --connect-timeout 2").read()
    trace_v6 = os.popen("curl -s6 https://www.cloudflare.com/cdn-cgi/trace --connect-timeout 2").read()
    
    def parse(trace):
        status, ip = "off", "------------"
        for line in trace.split('\n'):
            if line.startswith('warp='): status = line.split('=')[1]
            if line.startswith('ip='): ip = line.split('=')[1]
        return status, ip

    w4_stat, w4_ip = parse(trace_v4)
    w6_stat, w6_ip = parse(trace_v6)
    return {"v4_vps": vps_v4, "v4_warp": w4_ip, "v4_status": w4_stat, "v6_vps": vps_v6, "v6_warp": w6_ip, "v6_status": w6_stat}

@app.route('/warp')
def warp_dashboard():
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    conn = get_db()
    settings = conn.execute('SELECT server_name FROM settings').fetchone()
    conn.close()
    trace = get_warp_trace()
    wgcf_exists = os.path.exists('/etc/wireguard/wgcf.conf')
    return render_template('warp.html', trace=trace, is_installed=wgcf_exists, settings=settings)

@app.route('/warp/action/<action>', methods=['POST', 'GET'])
def warp_action(action):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    script_path = f"{APP_DIR}/scripts/action.sh"
    if action == "install":
        target = request.form.get('target', '3')
        key = request.form.get('license', 'free')
        subprocess.Popen(['bash', script_path, 'install', target, key])
        time.sleep(4)
    elif action == "toggle": os.system(f"bash {script_path} toggle")
    elif action == "uninstall": os.system(f"bash {script_path} uninstall")
    return redirect(url_for('warp_dashboard'))

# --- Log Center ---
@app.route('/logs')
def logs_viewer():
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    log_type = request.args.get('type', 'panel')
    conn = get_db()
    settings = conn.execute('SELECT server_name FROM settings').fetchone()
    conn.close()

    logs = ""
    try:
        if log_type == 'panel': logs = os.popen("journalctl -u bluefalcon-panel -n 100 --no-pager").read()
        elif log_type == 'openvpn': logs = os.popen("journalctl -u openvpn-server@server -n 100 --no-pager").read()
        elif log_type == 'warp': logs = os.popen("journalctl -u wg-quick@wgcf -n 100 --no-pager").read()
        elif log_type == 'system': logs = os.popen("tail -n 100 /var/log/syslog 2>/dev/null || tail -n 100 /var/log/messages").read()
    except Exception as e: logs = f"Error reading logs: {e}"
    return render_template('logs.html', logs=logs, current_type=log_type, settings=settings)

# --- General Handlers ---
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
                with open('/etc/openvpn/server/server.conf', 'r') as f: lines = f.readlines()
                with open('/etc/openvpn/server/server.conf', 'w') as f:
                    for line in lines:
                        if 'push "dhcp-option DNS' in line or 'duplicate-cn' in line: continue
                        f.write(line)
                    f.write(f'push "dhcp-option DNS {dns1}"\n')
                    if dns2: f.write(f'push "dhcp-option DNS {dns2}"\n')
                    if new_limit == "unlimited": f.write('duplicate-cn\n')
                needs_vpn_restart = True
            except: pass

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
        for u in conn.execute('SELECT system_name, password FROM users').fetchall(): os.system(f"bash {APP_DIR}/scripts/add_user.sh {u['system_name']} {u['password']}")

        if new_panel_port != old_panel_port:
            os.system(f"ufw delete allow {old_panel_port}/tcp >/dev/null 2>&1")
            os.system(f"ufw allow {new_panel_port}/tcp >/dev/null 2>&1")
            os.system(f"iptables -D INPUT -p tcp --dport {old_panel_port} -j ACCEPT")
            os.system(f"iptables -I INPUT -p tcp --dport {new_panel_port} -j ACCEPT")
            os.system("netfilter-persistent save > /dev/null 2>&1")
            os.system(f"sed -i 's/:{old_panel_port} /:{new_panel_port} /g' /etc/systemd/system/bluefalcon-panel.service")
            os.system("nohup bash -c 'sleep 1 && systemctl daemon-reload && systemctl restart bluefalcon-panel' >/dev/null 2>&1 &")
            
        return redirect(url_for('settings'))
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
    return redirect(url_for('openvpn_dashboard'))

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
    return redirect(url_for('openvpn_dashboard'))

@app.route('/download/<sys_name>')
def download(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    u = get_db().execute('SELECT display_name FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    s = get_db().execute('SELECT server_name FROM settings').fetchone()
    file_path = f'{APP_DIR}/configs/{sys_name}.ovpn'
    if not os.path.exists(file_path): return "Error 404: Configuration file not found.", 404
    custom_name = f"{s['server_name']} - {u['display_name']} (Auto).ovpn"
    return send_file(file_path, as_attachment=True, download_name=custom_name)

@app.route('/download_manual/<sys_name>')
def download_manual(sys_name):
    if 'admin_logged_in' not in session: return redirect(url_for('login'))
    u = get_db().execute('SELECT display_name FROM users WHERE system_name = ?', (sys_name,)).fetchone()
    s = get_db().execute('SELECT server_name FROM settings').fetchone()
    file_path = f'{APP_DIR}/configs/{sys_name}_manual.ovpn'
    if not os.path.exists(file_path): return "Error 404: Configuration file not found.", 404
    custom_name = f"{s['server_name']} - {u['display_name']} (Manual).ovpn"
    return send_file(file_path, as_attachment=True, download_name=custom_name)

if __name__ == '__main__': app.run(host='0.0.0.0', port=2020)