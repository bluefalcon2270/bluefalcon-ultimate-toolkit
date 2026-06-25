// Removed Vite CSS import for native browser ES module compatibility
import { icons, tabIcons } from './icons.js'
import { pages, pageMeta } from './pages.js'

const ICON_SIZES = { xs: 16, sm: 18, md: 22, lg: 28, xl: 34 }
let currentPage = 'dashboard'
let notifyCount = 3

const NOTIFICATIONS = [
  { t: 'Successful Transaction', d: 'Sarah Ahmadi — 2,450,000 Tomans', time: '2 mins ago', unread: true },
  { t: 'New User', d: 'Reza Akbari registered', time: '15 mins ago', unread: true },
  { t: 'Server Alert', d: 'CPU Load reached 78%', time: '1 hour ago', unread: true },
  { t: 'Weekly Report', d: 'Ready for download', time: 'Yesterday', unread: false },
]

function renderIcon(name, size = 'md') {
  const raw = icons[name]
  if (!raw) return ''
  const px = ICON_SIZES[size] ?? ICON_SIZES.md
  const once = raw.match(/width="\d+" height="\d+"/)
  if (!once) return raw
  return raw.replace(once[0], `width="${px}" height="${px}"`)
}

function getIconTargets(root) {
  const all = [...root.querySelectorAll('[data-icon]')]
  return all.filter((el) => !all.some((other) => other !== el && other.contains(el)))
}

let iconInjectLock = false

function injectIcons(root) {
  if (!root || iconInjectLock) return
  iconInjectLock = true
  try {
    getIconTargets(root).forEach((el) => {
      const name = el.getAttribute('data-icon')
      const html = renderIcon(name, el.getAttribute('data-icon-size') || 'md')
      if (name && html) el.innerHTML = html
    })

    const slots = {
      'icon-menu': ['menu', 'md'],
      'icon-close': ['close', 'md'],
      'icon-bell': ['bell', 'sm'],
      'icon-logo': ['logo', 'md'],
      'icon-server': ['server', 'md'],
    }
    Object.entries(slots).forEach(([id, [n, s]]) => {
      const el = document.getElementById(id)
      if (el && !el.hasAttribute('data-icon')) el.innerHTML = renderIcon(n, s)
    })

    root.querySelectorAll('[data-tab-icon]').forEach((btn) => {
      const tab = btn.getAttribute('data-tab')
      const iconEl = btn.querySelector('.tab-icon')
      if (iconEl && tabIcons[tab]) {
        iconEl.innerHTML = renderIcon(tabIcons[tab], 'xs')
      }
    })
  } finally {
    iconInjectLock = false
  }
}

function injectLayoutIcons() {
  const sidebar = document.getElementById('sidebar')
  const header = document.querySelector('.header-bar')
  const fab = document.getElementById('fab-new-tx')
  if (sidebar) injectIcons(sidebar)
  if (header) injectIcons(header)
  if (fab) injectIcons(fab)
}

function animateCounters(root = document) {
  root.querySelectorAll('[data-count]').forEach((el) => {
    const target = el.getAttribute('data-count')
    const isPercent = target.includes('%')
    const isM = /M/i.test(target)
    const raw = parseFloat(target.replace(/[^\d.]/g, '').replace(/,/g, ''))
    if (Number.isNaN(raw)) return
    const start = performance.now()
    const dur = 900
    const tick = (now) => {
      const p = Math.min((now - start) / dur, 1)
      const ease = 1 - (1 - p) ** 3
      const v = raw * ease
      if (isM) el.textContent = `${v.toFixed(1)}M`
      else if (isPercent) el.textContent = `${v.toFixed(1)}%`
      else el.textContent = Math.round(v).toLocaleString('en-US')
      if (p < 1) requestAnimationFrame(tick)
      else el.textContent = target
    }
    requestAnimationFrame(tick)
  })
}

function parseHTML(str) {
  const doc = new DOMParser().parseFromString(str, 'text/html')
  return doc.body.firstElementChild || doc.body
}

function renderPage(id) {
  const root = document.getElementById('page-root')
  if (!root) return
  root.innerHTML = ''
  
  // Here we would fetch data from our Flask API, but for now we render static HTML
  const content = parseHTML(`<div>${pages[id]}</div>`)
  while (content.firstChild) root.appendChild(content.firstChild)

  injectIcons(root)
  requestAnimationFrame(() => animateCounters(root))

  const titleEl = document.querySelector('[data-page-title]')
  const subEl = document.querySelector('[data-page-subtitle]')
  const meta = pageMeta[id]
  if (meta) {
    if (titleEl) titleEl.textContent = meta.title
    if (subEl) subEl.textContent = meta.subtitle
  }

  document.querySelectorAll('.nav-link').forEach((n) => {
    n.classList.toggle('nav-link-active', n.getAttribute('data-nav') === id)
  })
}

function initNavigation() {
  document.querySelectorAll('.nav-link').forEach((el) => {
    el.addEventListener('click', (e) => {
      e.preventDefault()
      const id = el.getAttribute('data-nav')
      if (id && id !== currentPage) {
        currentPage = id
        document.body.classList.remove('sidebar-open')
        renderPage(id)
      }
    })
  })

  document.getElementById('menu-btn')?.addEventListener('click', () => {
    document.body.classList.add('sidebar-open')
  })
  document.getElementById('close-btn')?.addEventListener('click', () => {
    document.body.classList.remove('sidebar-open')
  })
}

function showToast(msg, type = 'success') {
  const stack = document.getElementById('toast-stack')
  if (!stack) return
  const isErr = type === 'error'
  const ico = isErr ? 'alert' : 'check'
  const bg = isErr ? 'bg-rose-50 text-rose-600 border-rose-100' : 'bg-emerald-50 text-emerald-600 border-emerald-100'
  const el = parseHTML(`
    <div class="toast-item anim-fade-up border ${bg} shadow-sm">
      <span data-icon="${ico}" data-icon-size="sm"></span>
      <p class="text-[13px] font-medium text-ink">${msg}</p>
    </div>
  `)
  injectIcons(el)
  stack.appendChild(el)
  setTimeout(() => {
    el.style.opacity = '0'
    el.style.transform = 'translateY(10px) scale(0.95)'
    setTimeout(() => el.remove(), 300)
  }, 3000)
}

function initModals() {
  const bd = document.getElementById('modal-backdrop')
  const mod = document.getElementById('modal-tx')
  const op = () => { if (bd && mod) { bd.classList.remove('hidden'); mod.classList.remove('hidden') } }
  const cl = () => { if (bd && mod) { bd.classList.add('hidden'); mod.classList.add('hidden') } }

  document.getElementById('btn-new-tx')?.addEventListener('click', op)
  document.getElementById('fab-new-tx')?.addEventListener('click', op)
  document.getElementById('modal-close')?.addEventListener('click', cl)
  bd?.addEventListener('click', (e) => { if (e.target === bd) cl() })

  document.getElementById('form-tx')?.addEventListener('submit', (e) => {
    // Form submits normally to /openvpn
    showToast('Provisioning client...')
  })

  // Global event delegation for dynamic elements injected by pages.js
  document.addEventListener('click', (e) => {
    const target = e.target.closest('button, a')
    if (!target) return

    // Dynamic 'New Client' button in the Users tab
    if (target.id === 'btn-add-user') {
      op()
    }

    // Dynamic Tabs
    if (target.matches('[data-tab]')) {
      const tabId = target.getAttribute('data-tab')
      const tabContainer = target.closest('.tabs')
      if (tabContainer) {
        tabContainer.querySelectorAll('[data-tab]').forEach(t => t.classList.remove('tab-on'))
        target.classList.add('tab-on')
        // Filter table rows if inside transactions table
        const table = document.getElementById('table')
        if (table) {
          table.querySelectorAll('tbody tr').forEach(row => {
            if (tabId === 'all') row.style.display = ''
            else if (row.getAttribute('data-status') === tabId) row.style.display = ''
            else row.style.display = 'none'
          })
        }
      }
    }

    // Dynamic Theme Chips
    if (target.matches('.theme-chip')) {
      const themeContainer = target.closest('div')
      if (themeContainer) {
        themeContainer.querySelectorAll('.theme-chip').forEach(t => t.classList.remove('theme-chip-on'))
        target.classList.add('theme-chip-on')
      }
    }
    
    // Dynamic Settings Save Button
    if (target.id === 'btn-save-settings') {
      showToast('Settings saved successfully!')
    }
  })
}

document.addEventListener('DOMContentLoaded', () => {
  injectLayoutIcons()
  renderPage(currentPage)
  initNavigation()
  initModals()
})
