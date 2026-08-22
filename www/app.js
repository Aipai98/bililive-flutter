(() => {
  'use strict';

  const STORAGE_KEY = 'bililive.mobile.v1';
  const SERVER_KEY = 'bililive.mobile.server';

  const state = {
    tasks: [],
    filter: 'all',
    route: 'record',
    server: '',
  };

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) Object.assign(state, JSON.parse(raw));
    } catch (e) { /* first run */ }
    state.server = localStorage.getItem(SERVER_KEY) || '';
  }

  function persist() {
    const { tasks, filter } = state;
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ tasks, filter }));
    if (state.server) localStorage.setItem(SERVER_KEY, state.server);
  }

  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => Array.from(document.querySelectorAll(sel));

  function uid() {
    return 't_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  }

  function toast(msg, ttl = 2200) {
    const el = $('#toast');
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(toast._t);
    toast._t = setTimeout(() => el.classList.remove('show'), ttl);
  }

  function fmtDuration(ms) {
    const s = Math.max(0, Math.floor(ms / 1000));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const sec = s % 60;
    const pad = (n) => String(n).padStart(2, '0');
    return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`;
  }

  function reorder(taskId, dir) {
    const list = state.tasks.slice().sort((a, b) => a.priority - b.priority || a.createdAt - b.createdAt);
    const idx = list.findIndex((t) => t.id === taskId);
    if (idx < 0) return;
    const swap = dir === 'up' ? idx - 1 : idx + 1;
    if (swap < 0 || swap >= list.length) return;
    [list[idx], list[swap]] = [list[swap], list[idx]];
    list.forEach((t, i) => (t.priority = i));
    state.tasks = list;
    persist();
    renderQueue();
  }

  function enqueue(payload) {
    const now = Date.now();
    const task = {
      id: uid(),
      ...payload,
      status: 'waiting',
      progress: 0,
      createdAt: now,
      updatedAt: now,
      priority: state.tasks.length,
    };
    state.tasks.push(task);
    persist();
    renderQueue();
    renderActive();
    toast('已加入录制队列');
    simulateProgress(task.id);
  }

  function remove(id) {
    state.tasks = state.tasks.filter((t) => t.id !== id);
    persist();
    renderQueue();
    renderActive();
    toast('已移除任务');
  }

  function retry(id) {
    const t = state.tasks.find((x) => x.id === id);
    if (!t) return;
    Object.assign(t, { status: 'waiting', progress: 0, error: null, updatedAt: Date.now() });
    persist();
    renderQueue();
    renderActive();
    simulateProgress(t.id);
  }

  function simulateProgress(id) {
    const tick = () => {
      const t = state.tasks.find((x) => x.id === id);
      if (!t || t.status === 'done' || t.status === 'failed') return;
      promote(t);
      const step = 2 + Math.random() * 6;
      t.progress = Math.min(100, t.progress + step);
      if (t.progress >= 100) {
        t.status = 'done';
        t.progress = 100;
        t.updatedAt = Date.now();
        toast('任务完成 ✅');
      } else if (Math.random() < 0.04 && t.status === 'running') {
        t.status = 'failed';
        t.error = '网络抖动，已停止录制';
        t.updatedAt = Date.now();
        toast('录制失败，可点击重试');
      } else {
        t.updatedAt = Date.now();
        setTimeout(tick, 1000 + Math.random() * 1500);
      }
      persist();
      renderQueue();
      renderActive();
    };
    setTimeout(tick, 800 + Math.random() * 600);
  }

  function promote(t) {
    if (t.status === 'waiting') {
      const hasRunning = state.tasks.some((x) => x.status === 'running');
      if (!hasRunning) t.status = 'running';
    }
  }

  async function checkServer() {
    const btn = $('#server-status');
    if (!state.server) {
      btn.dataset.state = '';
      btn.querySelector('.status-text').textContent = '本地模式';
      return;
    }
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 4000);
      const r = await fetch(state.server + '/api/status', { signal: ctrl.signal });
      clearTimeout(timer);
      if (r.ok) {
        btn.dataset.state = 'connected';
        btn.querySelector('.status-text').textContent = '已连接';
      } else {
        btn.dataset.state = 'error';
        btn.querySelector('.status-text').textContent = '连接失败';
      }
    } catch (e) {
      btn.dataset.state = 'error';
      btn.querySelector('.status-text').textContent = '离线';
    }
  }

  function setServer(url) {
    state.server = (url || '').trim();
    persist();
    checkServer();
  }

  function renderTabs() {
    $$('.tab').forEach((el) => {
      el.classList.toggle('tab-active', el.dataset.route === state.route);
    });
    $$('.view').forEach((el) => {
      el.classList.toggle('view-active', el.id === 'view-' + state.route);
    });
  }

  function statusLabel(s) {
    return { waiting: '等待中', running: '进行中', done: '已完成', failed: '失败' }[s] || s;
  }

  function renderActive() {
    const t = state.tasks.find((x) => x.status === 'running');
    const el = $('#active-task');
    if (!t) { el.innerHTML = '<span class="muted">暂无正在录制的任务</span>'; return; }
    const elapsed = fmtDuration(Date.now() - t.createdAt);
    el.innerHTML = `
      <div class="live-pill">录制中</div>
      <div><strong>${escapeHtml(t.room)}</strong></div>
      <div class="muted" style="font-size:12px;">
        画质 ${escapeHtml(t.quality)} · 格式 ${escapeHtml(t.format)} · 已运行 ${elapsed}
      </div>`;
  }

  function renderQueue() {
    const list = $('#queue-list');
    const empty = $('#queue-empty');
    const filtered = state.tasks
      .slice()
      .sort((a, b) => a.priority - b.priority || a.createdAt - b.createdAt)
      .filter((t) => state.filter === 'all' || t.status === state.filter);

    if (filtered.length === 0) {
      list.innerHTML = '';
      empty.style.display = '';
      return;
    }
    empty.style.display = 'none';
    list.innerHTML = filtered.map(taskTemplate).join('');
  }

  function taskTemplate(t) {
    const elapsed = Date.now() - t.createdAt;
    const progressStyle = t.status === 'waiting' ? 'width:0%' : `width:${t.progress}%`;
    const progressVisible = t.status !== 'waiting';
    return `
      <li class="queue-item" data-id="${t.id}">
        <div class="queue-head">
          <div class="queue-room">${escapeHtml(t.room)}</div>
          <div class="queue-status status-${t.status}">${statusLabel(t.status)}</div>
        </div>
        <div class="queue-meta">
          <span>画质 ${escapeHtml(t.quality)}</span>
          <span>格式 ${escapeHtml(t.format)}</span>
          <span>路径 ${escapeHtml(t.savePath)}</span>
          <span>${t.autoSplit ? `分段 ${t.splitSize}GB` : '不分段'}</span>
          <span>已 ${fmtDuration(elapsed)}</span>
        </div>
        ${progressVisible ? `<div class="progress"><span style="${progressStyle}"></span></div>` : ''}
        ${t.error ? `<div class="muted" style="margin-top:6px;font-size:12px;color:var(--danger)">${escapeHtml(t.error)}</div>` : ''}
        <div class="queue-actions">
          <button class="mini" data-action="up" ${t.priority === 0 ? 'disabled' : ''}>上移</button>
          <button class="mini" data-action="down">下移</button>
          ${t.status === 'failed' ? '<button class="mini" data-action="retry">重试</button>' : ''}
          <button class="mini danger" data-action="remove">删除</button>
        </div>
      </li>`;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  function bind() {
    $$('.tab').forEach((btn) => btn.addEventListener('click', () => {
      state.route = btn.dataset.route;
      renderTabs();
    }));

    $$('.chip').forEach((c) => c.addEventListener('click', () => {
      $$('.chip').forEach((x) => x.classList.remove('chip-active'));
      c.classList.add('chip-active');
      state.filter = c.dataset.filter;
      persist();
      renderQueue();
    }));

    $('#record-form').addEventListener('submit', (e) => {
      e.preventDefault();
      const payload = {
        room: $('#room-input').value.trim(),
        quality: $('#quality').value,
        format: $('#format').value,
        savePath: $('#save-path').value.trim() || './recordings',
        autoSplit: $('#auto-split').checked,
        splitSize: Number($('#split-size').value) || 2,
      };
      if (!payload.room) return toast('请输入直播间 URL 或房间号');
      enqueue(payload);
      $('#room-input').value = '';
    });

    $('#queue-list').addEventListener('click', (e) => {
      const btn = e.target.closest('button[data-action]');
      if (!btn) return;
      const li = btn.closest('.queue-item');
      const id = li && li.dataset.id;
      if (!id) return;
      const action = btn.dataset.action;
      if (action === 'up') reorder(id, 'up');
      else if (action === 'down') reorder(id, 'down');
      else if (action === 'remove') remove(id);
      else if (action === 'retry') retry(id);
    });

    $('#server-status').addEventListener('click', () => {
      const url = prompt('输入 biliLive-tools 服务端地址（例如 http://192.168.1.10:23333），留空使用本地模式', state.server || '');
      if (url === null) return;
      setServer(url);
      toast(url ? '服务器已更新' : '已切换到本地模式');
    });

    document.querySelectorAll('[data-filter]').forEach((c) => {
      if (c.dataset.filter === state.filter) {
        $$('.chip').forEach((x) => x.classList.remove('chip-active'));
        c.classList.add('chip-active');
      }
    });

    setInterval(renderActive, 1000);
    window.addEventListener('online', checkServer);
    window.addEventListener('offline', checkServer);
  }

  document.addEventListener('DOMContentLoaded', () => {
    load();
    bind();
    renderTabs();
    renderQueue();
    renderActive();
    checkServer();
  });
})();