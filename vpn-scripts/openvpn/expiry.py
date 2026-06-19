import sqlite3, time, os
APP_DIR = '/opt/bluefalcon-ultimate-toolkit'
conn = sqlite3.connect(f'{APP_DIR}/panel.db')
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
conn.commit()
conn.close()