/**
 * Firebase Auth: /verify?oobCode= (App-First), optional mode= (PWA/action links),
 * Passwort-Reset-Formular. l10n: /vb/lang/*.js
 */
import { initializeApp } from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-app.js';
import {
  getAuth,
  applyActionCode,
  confirmPasswordReset,
} from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-auth.js';

const firebaseConfig = {
  apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
  authDomain: 'dj-ollerganove.firebaseapp.com',
  projectId: 'dj-ollerganove',
  storageBucket: 'dj-ollerganove.firebasestorage.app',
  messagingSenderId: '567845942758',
  appId: '1:567845942758:web:8549e7d5abb8b3b81bd227',
};

function getLangCode() {
  try {
    const p = new URLSearchParams(window.location.search);
    const q = (p.get('lang') || '').trim().toLowerCase();
    if (q) return q.split('-')[0];
  } catch (e) {}
  try {
    const stored = window.localStorage.getItem('permanent_user_locale');
    if (stored) return String(stored).split('-')[0].toLowerCase();
  } catch (e) {}
  const nav = (navigator.language || 'en').split('-')[0].toLowerCase();
  const supported = ['de', 'en', 'fr', 'ru', 'zh', 'es', 'tr', 'pt', 'ar'];
  return supported.includes(nav) ? nav : 'de';
}

function loadLangScript(code) {
  return new Promise((resolve) => {
    const path = `/vb/lang/${code}.js`;
    const key = 'lang_' + code;
    if (typeof window !== 'undefined' && window[key]) {
      resolve(code);
      return;
    }
    const existing = document.head.querySelector(`script[src="${path}"], script[src^="${path}?"]`);
    if (existing) {
      existing.addEventListener('load', function () {
        resolve(code);
      });
      existing.addEventListener('error', function () {
        resolve(null);
      });
      return;
    }
    const s = document.createElement('script');
    s.src = path;
    s.async = true;
    s.onload = function () {
      resolve(code);
    };
    s.onerror = function () {
      resolve(null);
    };
    document.head.appendChild(s);
  });
}

function getStrings(code) {
  const key = 'lang_' + code;
  const bundle = typeof window !== 'undefined' ? window[key] : null;
  return bundle || window.lang_de || {};
}

function t(strings, key) {
  const v = strings[key];
  return typeof v === 'string' && v.length > 0 ? v : key;
}

function parseParams() {
  const p = new URLSearchParams(window.location.search);
  const mode = (p.get('mode') || '').trim();
  const oobCode = (p.get('oobCode') || p.get('oobcode') || '').trim();
  return { mode, oobCode };
}

function el(id) {
  return document.getElementById(id);
}

function showPhaseProcessing(strings) {
  el('phaseResult').classList.add('hidden');
  el('phaseProcessing').classList.remove('hidden');
  el('statusProcessing').classList.remove('hidden');
  el('pageTitle').textContent = t(strings, 'auth_verify_title');
  el('statusProcessing').textContent = t(strings, 'auth_verify_processing');
}

function showVerifySuccess(strings, bodyKey) {
  el('phaseProcessing').classList.add('hidden');
  el('phaseResult').classList.remove('hidden');
  const title = el('resultTitle');
  const body = el('resultBody');
  title.className = 'verify-result-title title-success';
  title.textContent = t(strings, 'verify_success_title');
  body.textContent = t(strings, bodyKey || 'verify_success_instruction');
}

/** Fehler: Nutzer-Support (abgelaufener Code etc.) */
function showVerifyError(strings, useLoginInstruction) {
  el('phaseProcessing').classList.add('hidden');
  el('phaseResult').classList.remove('hidden');
  const title = el('resultTitle');
  const body = el('resultBody');
  title.className = 'verify-result-title title-error';
  title.textContent = t(strings, 'verify_error_title');
  body.textContent = useLoginInstruction
    ? t(strings, 'verify_error_instruction_login')
    : t(strings, 'auth_verify_error');
}

function showAppButton(btn, strings, mode) {
  btn.textContent = t(strings, 'auth_back_to_app');
  btn.classList.remove('hidden');
  btn.onclick = function () {
    var action = 'verified';
    if (mode === 'resetPassword') {
      action = 'password_reset';
    } else if (mode === 'recoverEmail') {
      action = 'recover_email';
    } else if (!mode) {
      action = 'open';
    }
    try {
      window.location.href =
        'vibesbox://auth/login?action=' + encodeURIComponent(action);
    } catch (e) {}
    setTimeout(function () {
      try {
        window.close();
      } catch (e2) {}
    }, 500);
  };
}

async function main() {
  const langCodeFirst = getLangCode();
  let loaded = await loadLangScript(langCodeFirst);
  if (!loaded) {
    await loadLangScript('de');
    loaded = 'de';
  }
  const strings = getStrings(loaded);

  document.title = 'VibesBox – ' + t(strings, 'auth_verify_title');

  const statusProcessing = el('statusProcessing');
  const formWrap = el('formWrap');
  const btnApp = el('btnApp');

  const { mode: rawMode, oobCode } = parseParams();
  const mode = (rawMode || '').trim() || (oobCode ? 'verifyEmail' : '');

  if (!oobCode) {
    showVerifyError(strings, true);
    showAppButton(btnApp, strings, '');
    return;
  }

  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);

  if (mode === 'resetPassword') {
    el('phaseResult').classList.add('hidden');
    el('phaseProcessing').classList.remove('hidden');
    el('pageTitle').textContent = t(strings, 'auth_verify_title');
    statusProcessing.classList.add('hidden');
    formWrap.classList.remove('hidden');
    formWrap.innerHTML =
      '<form id="pwForm">' +
      '<label for="pw1">' +
      t(strings, 'auth_reset_password_new') +
      '</label>' +
      '<input id="pw1" type="password" autocomplete="new-password" required minlength="6" />' +
      '<label for="pw2">' +
      t(strings, 'auth_reset_password_confirm') +
      '</label>' +
      '<input id="pw2" type="password" autocomplete="new-password" required minlength="6" />' +
      '<p class="hint">' +
      t(strings, 'auth_reset_password_hint') +
      '</p>' +
      '<button type="submit" class="btn">' +
      t(strings, 'auth_reset_password_submit') +
      '</button>' +
      '</form>';

    document.getElementById('pwForm').onsubmit = async function (ev) {
      ev.preventDefault();
      const p1 = document.getElementById('pw1').value;
      const p2 = document.getElementById('pw2').value;
      if (p1 !== p2) {
        formWrap.classList.add('hidden');
        showVerifyError(strings, false);
        return;
      }
      try {
        await confirmPasswordReset(auth, oobCode, p1);
        formWrap.classList.add('hidden');
        showVerifySuccess(strings, 'auth_verify_success_password');
        showAppButton(btnApp, strings, mode);
      } catch (err) {
        console.error(err);
        formWrap.classList.add('hidden');
        showVerifyError(strings, false);
        showAppButton(btnApp, strings, mode);
      }
    };
    return;
  }

  showPhaseProcessing(strings);

  if (mode === 'verifyEmail' || mode === 'recoverEmail') {
    try {
      await applyActionCode(auth, oobCode);
      showVerifySuccess(strings, 'verify_success_instruction');
      showAppButton(btnApp, strings, mode);
    } catch (err) {
      console.error(err);
      showVerifyError(strings, true);
      showAppButton(btnApp, strings, mode);
    }
    return;
  }

  showVerifyError(strings, true);
  showAppButton(btnApp, strings, mode);
}

main();
