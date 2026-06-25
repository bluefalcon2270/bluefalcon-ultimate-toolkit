export const pageMeta = {
  dashboard: { title: 'Dashboard', subtitle: 'Welcome back, Administrator' },
  users: { title: 'OpenVPN Users', subtitle: 'Managing 12 Active Clients' },
  logs: { title: 'VPN Logs', subtitle: 'Live Connection History' },
  analytics: { title: 'Network Stats', subtitle: 'Performance & Bandwidth' },
  settings: { title: 'Settings', subtitle: 'System Configuration' },
}

export const pages = {
  dashboard: `
    <section class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4 anim-stagger">
      <article class="metric metric-d1"><div class="relative z-[1] flex justify-between gap-3"><div><p class="text-[12px] font-medium text-ink-faint">Data Downloaded</p><p class="metric-val text-lg font-bold" data-count="${window.APP_DATA?.total_rx || '0'}">${window.APP_DATA?.total_rx || '0'}</p><span class="trend-up mt-2"><span data-icon="trendUp" data-icon-size="sm"></span>Live</span></div><div class="metric-ico metric-ico--blue anim-pop"><span data-icon="revenue" data-icon-size="xl"></span></div></div><svg class="spark anim-draw" viewBox="0 0 120 32" preserveAspectRatio="none"><defs><linearGradient id="s1" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#2563eb" stop-opacity="0.25"/><stop offset="100%" stop-color="#2563eb" stop-opacity="0"/></linearGradient></defs><path class="spark-line" d="M0 22 L20 18 L40 20 L60 12 L80 14 L100 8 L120 6" fill="none" stroke="#2563eb" stroke-width="2.5" stroke-linecap="round"/><path d="M0 22 L20 18 L40 20 L60 12 L80 14 L100 8 L120 6 L120 32 L0 32Z" fill="url(#s1)"/></svg></article>
      <article class="metric metric-d2"><div class="relative z-[1] flex justify-between gap-3"><div><p class="text-[12px] font-medium text-ink-faint">Data Uploaded</p><p class="metric-val text-lg font-bold" data-count="${window.APP_DATA?.total_tx || '0'}">${window.APP_DATA?.total_tx || '0'}</p><span class="trend-up mt-2"><span data-icon="trendUp" data-icon-size="sm"></span>Live</span></div><div class="metric-ico metric-ico--purple anim-pop"><span data-icon="orders" data-icon-size="xl"></span></div></div><svg class="spark anim-draw" viewBox="0 0 120 32" preserveAspectRatio="none"><defs><linearGradient id="s2" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#7c3aed" stop-opacity="0.22"/><stop offset="100%" stop-color="#7c3aed" stop-opacity="0"/></linearGradient></defs><path class="spark-line" d="M0 24 L25 20 L50 22 L75 14 L100 10 L120 8" fill="none" stroke="#7c3aed" stroke-width="2.5" stroke-linecap="round"/><path d="M0 24 L25 20 L50 22 L75 14 L100 10 L120 8 L120 32 L0 32Z" fill="url(#s2)"/></svg></article>
      <article class="metric metric-d3"><div class="relative z-[1] flex justify-between gap-3"><div><p class="text-[12px] font-medium text-ink-faint">Active Users</p><p class="metric-val text-lg font-bold" data-count="${window.APP_DATA?.users_count || '0'}">${window.APP_DATA?.users_count || '0'}</p><span class="trend-up mt-2"><span data-icon="trendUp" data-icon-size="sm"></span>Total</span></div><div class="metric-ico metric-ico--green anim-pop"><span data-icon="customers" data-icon-size="xl"></span></div></div><svg class="spark anim-draw" viewBox="0 0 120 32" preserveAspectRatio="none"><defs><linearGradient id="s3" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#10b981" stop-opacity="0.22"/><stop offset="100%" stop-color="#10b981" stop-opacity="0"/></linearGradient></defs><path class="spark-line" d="M0 26 L30 22 L60 24 L90 16 L120 12" fill="none" stroke="#10b981" stroke-width="2.5" stroke-linecap="round"/><path d="M0 26 L30 22 L60 24 L90 16 L120 12 L120 32 L0 32Z" fill="url(#s3)"/></svg></article>
      <article class="metric metric-d4"><div class="relative z-[1] flex justify-between gap-3"><div><p class="text-[12px] font-medium text-ink-faint">Avg Latency (ms)</p><p class="metric-val" data-count="45">0</p><span class="trend-down mt-2"><span data-icon="trendDown" data-icon-size="sm"></span>−5.3%</span></div><div class="metric-ico metric-ico--orange anim-pop"><span data-icon="growth" data-icon-size="xl"></span></div></div><svg class="spark anim-draw" viewBox="0 0 120 32" preserveAspectRatio="none"><defs><linearGradient id="s4" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#f59e0b" stop-opacity="0.2"/><stop offset="100%" stop-color="#f59e0b" stop-opacity="0"/></linearGradient></defs><path class="spark-line" d="M0 10 L30 14 L60 12 L90 18 L120 16" fill="none" stroke="#f59e0b" stroke-width="2.5" stroke-linecap="round"/><path d="M0 10 L30 14 L60 12 L90 18 L120 16 L120 32 L0 32Z" fill="url(#s4)"/></svg></article>
    </section>
    <section class="table-panel anim-fade-up">${transactionsTable()}</section>
  `,

  users: `
    <section class="panel p-5 anim-fade-up">
      <div class="relative z-[1] mb-4 flex flex-col gap-3 sm:mb-5 sm:flex-row sm:items-center sm:justify-between">
        <div><h2 class="text-base font-bold text-ink sm:text-lg">Client Roster</h2><p class="text-[11px] text-ink-faint sm:text-[12px]">${window.APP_DATA?.users_count || '0'} Registered Clients</p></div>
        <button type="button" class="btn-fill w-full justify-center sm:w-auto" id="btn-add-user"><span data-icon="plus" data-icon-size="sm"></span>New Client</button>
      </div>
      <div class="relative z-[1] grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 anim-stagger">
        ${userCards()}
      </div>
    </section>
  `,

  logs: `
    <section class="table-panel anim-fade-up">${transactionsTable(true)}</section>
  `,

  analytics: `
    <section class="grid grid-cols-1 gap-4 lg:grid-cols-2 anim-stagger">
      <article class="panel p-5 anim-scale-in">
        <h3 class="relative z-[1] mb-4 text-base font-bold text-ink">Weekly Bandwidth</h3>
        <div class="chart-bars relative z-[1] flex items-end justify-between gap-1 sm:gap-2">
          ${[65, 45, 80, 55, 90, 70, 95].map((h, i) => `<div class="bar-col flex-1"><div class="bar-fill" style="--h:${h}%;--d:${i * 0.08}s"></div><span class="mt-2 block text-center text-[10px] text-ink-faint">${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i]}</span></div>`).join('')}
        </div>
      </article>
      <article class="panel p-5 anim-scale-in" style="animation-delay:.1s">
        <h3 class="relative z-[1] mb-4 text-base font-bold text-ink">Protocols</h3>
        <div class="relative z-[1] space-y-4">
          ${[{l:'UDP',p:72,c:'#2563eb'},{l:'TCP',p:20,c:'#7c3aed'},{l:'ICMP',p:5,c:'#10b981'},{l:'Other',p:3,c:'#f59e0b'}].map(x => `<div><div class="mb-1 flex justify-between text-[12px]"><span class="font-medium text-ink">${x.l}</span><span class="text-ink-faint">${x.p}%</span></div><div class="progress-track"><div class="progress-fill" style="--w:${x.p}%;--c:${x.c}"></div></div></div>`).join('')}
        </div>
      </article>
    </section>
    <section class="panel mt-4 p-5 anim-fade-up">
      <h3 class="relative z-[1] mb-3 text-base font-bold text-ink">Monthly Summary</h3>
      <div class="relative z-[1] grid grid-cols-2 gap-3 sm:grid-cols-4">
        ${[{n:'124.5',l:'GB Down',i:'revenue'},{n:'89.2',l:'GB Up',i:'orders'},{n:'12',l:'Clients',i:'customers'},{n:'99.9%',l:'Uptime',i:'growth'}].map((x,i)=>`<div class="mini-stat anim-pop" style="animation-delay:${i*0.08}s"><span data-icon="${x.i}" data-icon-size="md"></span><p class="mt-2 text-lg font-bold text-ink">${x.n}</p><p class="text-[11px] text-ink-faint">${x.l}</p></div>`).join('')}
      </div>
    </section>
  `,

  settings: `
    <section class="grid grid-cols-1 gap-4 lg:grid-cols-2 anim-stagger">
      <article class="panel p-5 anim-fade-up">
        <h3 class="relative z-[1] mb-4 text-base font-bold text-ink">Server Details</h3>
        <div class="relative z-[1] space-y-3">
          <label class="block"><span class="mb-1 block text-[12px] text-ink-faint">Host Name</span><input class="input-field" value="bluefalcon-srv-1" /></label>
          <label class="block"><span class="mb-1 block text-[12px] text-ink-faint">Admin Email</span><input class="input-field" value="admin@bluefalcon.local" dir="ltr" /></label>
          <button type="button" class="btn-fill w-full justify-center" id="btn-save-settings">Save Changes</button>
        </div>
      </article>
      <article class="panel p-5 anim-fade-up" style="animation-delay:.08s">
        <h3 class="relative z-[1] mb-4 text-base font-bold text-ink">Alerts</h3>
        <div class="relative z-[1] space-y-3">
          ${[{l:'Connection Drops',on:true},{l:'High CPU Load',on:true},{l:'Daily Reports',on:false},{l:'New Client Provision',on:true}].map((t,i)=>`<label class="toggle-row anim-pop" style="animation-delay:${i*0.06}s"><span class="text-[13px] font-medium text-ink">${t.l}</span><input type="checkbox" class="toggle-input" ${t.on?'checked':''} /><span class="toggle-ui"></span></label>`).join('')}
        </div>
      </article>
      <article class="panel p-5 lg:col-span-2 anim-fade-up" style="animation-delay:.12s">
        <h3 class="relative z-[1] mb-4 text-base font-bold text-ink">Appearance</h3>
        <div class="relative z-[1] flex flex-wrap gap-2">
          <button type="button" class="theme-chip theme-chip-on" data-theme="light">Light</button>
          <button type="button" class="theme-chip" data-theme="dark">Dark</button>
          <button type="button" class="theme-chip" data-theme="auto">System</button>
        </div>
      </article>
    </section>
  `,
}

function userCards() {
  const users = window.APP_DATA?.users || []
  if (users.length === 0) return '<p class="text-ink-faint py-4">No users found.</p>'

  const bg = { active: 'bg-emerald-500/15 text-emerald-400', inactive: 'bg-rose-500/15 text-rose-400', default: 'bg-brand-blue/15 text-brand-blue' }
  return users.map((u, i) => `
    <div class="user-card anim-pop" data-searchable style="animation-delay:${i * 0.05}s">
      <div class="flex items-center gap-3">
        <span class="user-dot ${u.status === 'active' ? bg.active : bg.inactive}">${u.name.charAt(0).toUpperCase()}</span>
        <div><p class="font-semibold text-ink">${u.name}</p><p class="text-[11px] text-ink-faint">${u.usage} Usage</p></div>
      </div>
      <div class="flex gap-2 mt-3">
        <a href="/download/${u.id}" class="row-btn w-full justify-center" aria-label="Download"><span data-icon="download" data-icon-size="sm"></span></a>
        <a href="/toggle/${u.id}" class="row-btn w-full justify-center" aria-label="Toggle"><span data-icon="settings" data-icon-size="sm"></span></a>
        <a href="/revoke/${u.id}" class="row-btn w-full justify-center text-rose-500" aria-label="Revoke"><span data-icon="close" data-icon-size="sm"></span></a>
      </div>
    </div>
  `).join('')
}

function transactionsTable(full = false) {
  const rows = [
    ['#LOG-9821', 'S', 'Sarah Ahmed', 'blue', '1.2 GB', '2026-06-25 10:32', 'success', 'Connected', 'chip-ok'],
    ['#LOG-9820', 'M', 'Michael R.', 'purple', '0.5 GB', '2026-06-25 09:15', 'pending', 'Connecting', 'chip-wait'],
    ['#LOG-9819', 'J', 'John Doe', 'green', '5.1 GB', '2026-06-24 18:44', 'success', 'Connected', 'chip-ok'],
    ['#LOG-9818', 'A', 'Alice M.', 'rose', '0.0 GB', '2026-06-24 14:02', 'failed', 'Auth Failed', 'chip-fail'],
    ['#LOG-9817', 'K', 'Kevin H.', 'amber', '3.7 GB', '2026-06-23 11:20', 'success', 'Connected', 'chip-ok'],
    ['#LOG-9816', 'F', 'Fiona N.', 'sky', '0.6 GB', '2026-06-23 08:55', 'pending', 'Idle', 'chip-info'],
  ]
  const bg = { blue: 'bg-brand-blue/15 text-brand-blue', purple: 'bg-brand-purple/15 text-brand-purple', green: 'bg-emerald-500/15 text-emerald-400', rose: 'bg-rose-500/15 text-rose-400', amber: 'bg-amber-500/15 text-amber-400', sky: 'bg-sky-500/15 text-sky-400' }
  const extra = full ? rows : rows
  const cell = (label, html, extraClass = '') => `<td class="data-cell px-4 py-3.5 ${extraClass}" data-label="${label}">${html}</td>`
  return `
    <div class="table-toolbar relative z-[1] mb-4 flex flex-col gap-3 sm:mb-5 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:gap-4">
      <div class="flex min-w-0 items-center gap-3">
        <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-brand-blue/10 text-brand-blue anim-pop sm:h-11 sm:w-11"><span data-icon="transactions" data-icon-size="md"></span></div>
        <div class="min-w-0"><h2 class="text-base font-bold text-ink sm:text-lg">Latest Connections</h2><p class="text-[11px] text-ink-faint sm:text-[12px]">Live Updates</p></div>
      </div>
      <div class="flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:items-center">
        <div id="tabs" class="tabs tabs-scroll w-full sm:w-auto" role="tablist">
          <button type="button" role="tab" data-tab="all" data-tab-icon class="tab tab-on" aria-selected="true"><span class="tab-icon"></span>All</button>
          <button type="button" role="tab" data-tab="success" data-tab-icon class="tab" aria-selected="false"><span class="tab-icon"></span>Success</button>
          <button type="button" role="tab" data-tab="pending" data-tab-icon class="tab" aria-selected="false"><span class="tab-icon"></span>Pending</button>
          <button type="button" role="tab" data-tab="failed" data-tab-icon class="tab" aria-selected="false"><span class="tab-icon"></span>Failed</button>
        </div>
        <button type="button" class="btn-ghost w-full justify-center sm:w-auto" id="btn-download" aria-label="Download"><span data-icon="download" data-icon-size="sm"></span><span class="ms-2 text-[12px] sm:hidden">Download</span></button>
      </div>
    </div>
    <div class="table-scroll relative z-[1] -mx-1 px-1 sm:mx-0 sm:px-0">
      <table class="data-table data-table--responsive" id="table">
        <thead><tr class="text-left"><th>ID</th><th>Client</th><th>Traffic</th><th>Timestamp</th><th>Status</th><th class="col-actions"></th></tr></thead>
        <tbody id="rows">${extra.map((r, i) => `<tr class="data-row" data-searchable data-status="${r[6]}" style="animation-delay:${0.35 + i * 0.06}s">
          ${cell('ID', `<span class="font-mono text-[12px] text-ink-faint">${r[0]}</span>`)}
          ${cell('Client', `<div class="flex items-center gap-2"><span class="user-dot ${bg[r[3]]}">${r[1]}</span><span class="font-semibold">${r[2]}</span></div>`)}
          ${cell('Traffic', `<span class="font-semibold">${r[4]}</span>`)}
          ${cell('Timestamp', `<span class="text-ink-faint">${r[5]}</span>`)}
          ${cell('Status', `<span class="chip ${r[8]}">${r[7]}</span>`)}
          ${cell('Action', `<div class="flex gap-1"><button class="row-btn" type="button" data-action="view-tx"><span data-icon="eye" data-icon-size="sm"></span></button><button class="row-btn" type="button"><span data-icon="more" data-icon-size="sm"></span></button></div>`, 'col-actions')}
        </tr>`).join('')}</tbody>
      </table>
    </div>
    <p id="empty" class="relative z-[1] hidden py-10 text-center text-[13px] text-ink-faint">No records found.</p>
  `
}
