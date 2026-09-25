/**
 * Offene Wünsche per Long-Press am Griff verschieben (wie Flutter OpenWishOrderService).
 * Reihenfolge wird in Firestore gespeichert und auf allen Geräten synchronisiert.
 */
(function (global) {
  const MAX_ORDER_KEYS = 500;
  const LONG_PRESS_MS = 380;

  function parseOrderKeys(raw) {
    if (!Array.isArray(raw)) return [];
    return raw
      .map((k) => String(k || '').trim())
      .filter(Boolean)
      .slice(0, MAX_ORDER_KEYS);
  }

  function orderWithPinsFirst(keys, pinnedKeys) {
    const pinned = pinnedKeys.filter((k) => keys.includes(k));
    const pinnedSet = new Set(pinned);
    const rest = keys.filter((k) => !pinnedSet.has(k));
    return [...pinned, ...rest];
  }

  function buildDocMaps(entries) {
    const groupToDoc = {};
    const docToGroup = {};
    entries.forEach((e) => {
      const gk = String(e.groupKey || '').trim();
      const docId = String(e.primaryId || (e.docIds && e.docIds[0]) || '').trim();
      if (gk && docId) {
        groupToDoc[gk] = docId;
        docToGroup[docId] = gk;
      }
    });
    return { groupToDoc, docToGroup };
  }

  function resolveStoredOrderKey(stored, docToGroup, byKey) {
    const key = String(stored || '').trim();
    if (!key) return null;
    if (byKey[key]) return key;
    const fromDoc = docToGroup[key];
    if (fromDoc && byKey[fromDoc]) return fromDoc;
    return null;
  }

  function storageKeysForGroupOrder(groupKeys, entries) {
    const { groupToDoc } = buildDocMaps(entries);
    return groupKeys.map((gk) => groupToDoc[gk] || gk);
  }

  function resolveStoredPinKeys(storedKeys, entries) {
    const { docToGroup } = buildDocMaps(entries);
    const byKey = {};
    entries.forEach((e) => {
      byKey[e.groupKey] = true;
    });
    const out = [];
    for (const raw of storedKeys) {
      const key = String(raw || '').trim();
      if (!key) continue;
      let groupKey = null;
      if (byKey[key]) groupKey = key;
      else if (docToGroup[key]) groupKey = docToGroup[key];
      if (groupKey && !out.includes(groupKey)) out.push(groupKey);
    }
    return out.slice(0, 3);
  }

  function applyDisplayOrder(orderKeys, entries, pinnedKeys) {
    const byKey = {};
    entries.forEach((e) => {
      byKey[e.groupKey] = e;
    });
    const pinned = pinnedKeys.filter((k) => byKey[k]);
    const pinnedSet = new Set(pinned);
    const unpinned = orderKeys.filter((k) => byKey[k] && !pinnedSet.has(k));
    return [...pinned, ...unpinned].map((k) => byKey[k]).filter(Boolean);
  }

  function buildServerDisplayOrder(entries, serverOrderKeys, pinnedKeys) {
    const byKey = {};
    entries.forEach((e) => {
      byKey[e.groupKey] = e;
    });
    const { docToGroup } = buildDocMaps(entries);
    const defaultKeys = entries.map((e) => e.groupKey);
    let order = [];
    for (const key of serverOrderKeys) {
      const resolved = resolveStoredOrderKey(key, docToGroup, byKey);
      if (resolved && !order.includes(resolved)) order.push(resolved);
    }
    const newKeys = defaultKeys.filter((k) => !order.includes(k));
    const pinnedSet = new Set(pinnedKeys.filter((k) => byKey[k]));
    order = order.filter((k) => !pinnedSet.has(k));
    if (newKeys.length) {
      const newUnpinned = newKeys.filter((k) => !pinnedSet.has(k));
      order = [...newUnpinned, ...order];
    }
    return applyDisplayOrder(order, entries, pinnedKeys);
  }

  function applyLocalInsertAt(keys, key, insertIndex) {
    const list = keys.slice();
    const oldIndex = list.indexOf(key);
    if (oldIndex < 0) return list;
    let target = Math.max(0, Math.min(insertIndex, list.length));
    if (oldIndex < target) target -= 1;
    if (oldIndex === target) return list;
    const item = list.splice(oldIndex, 1)[0];
    list.splice(target, 0, item);
    return list;
  }

  function computeInsertIndex(root, clientY, draggedKey, orderKeys, pinnedKeys) {
    const cards = [...root.querySelectorAll('.wish-card[data-group-key]')];
    if (!cards.length) return null;

    const pinnedCount = orderKeys.filter((k) => pinnedKeys.includes(k)).length;
    const oldIdx = orderKeys.indexOf(draggedKey);
    if (oldIdx < 0) return null;

    let bestIdx = null;
    let bestDist = Infinity;

    for (let i = 0; i <= cards.length; i += 1) {
      if (i < pinnedCount) continue;

      let gapY;
      if (i === 0) {
        gapY = cards[0].getBoundingClientRect().top - 10;
      } else if (i >= cards.length) {
        gapY = cards[cards.length - 1].getBoundingClientRect().bottom + 10;
      } else {
        const prev = cards[i - 1].getBoundingClientRect();
        const next = cards[i].getBoundingClientRect();
        gapY = (prev.bottom + next.top) / 2;
      }

      const dist = Math.abs(clientY - gapY);
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    if (bestIdx == null) return null;

    let target = Math.max(pinnedCount, Math.min(bestIdx, orderKeys.length));
    if (oldIdx < target) target -= 1;
    if (oldIdx === target) return null;
    return bestIdx;
  }

  async function commitWishOrder(state, orderKeys, firebase) {
    if (!state.partyId || !firebase.djRunTransaction) return false;
    const ref = firebase.djDoc(firebase.djFirebaseDb, 'parties', state.partyId);
    const orderList = orderKeys.slice(0, MAX_ORDER_KEYS);
    let ok = false;
    await firebase.djRunTransaction(firebase.djFirebaseDb, async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists()) return;
      const data = snap.data() || {};
      const rev = Number(data.open_wish_order_rev) || 0;
      tx.update(ref, {
        open_wish_order: orderList,
        open_wish_order_rev: rev + 1,
        open_wish_order_updated_at: firebase.djServerTimestamp(),
        open_wish_sort_lock_device_id: firebase.djDeleteField(),
        open_wish_sort_lock_at: firebase.djDeleteField(),
      });
      ok = true;
    });
    return ok;
  }

  function setupWishListReorder(root, options) {
    if (!root || root.dataset.reorderSetup === '1') return;
    root.dataset.reorderSetup = '1';

    let longPressTimer = null;
    let draggingKey = null;
    let insertIndex = null;
    let activePointerId = null;
    let activeHandle = null;
    let dragPending = false;
    let indicator = null;

    function canUseReorder() {
      return options.isOffenTab() && !options.isFavoritesOnly();
    }

    function ensureIndicator() {
      if (indicator) return indicator;
      indicator = document.createElement('div');
      indicator.className = 'wish-insert-indicator';
      indicator.hidden = true;
      document.body.appendChild(indicator);
      return indicator;
    }

    function hideIndicator() {
      if (indicator) indicator.hidden = true;
    }

    function showIndicatorAtIndex(idx) {
      const cards = [...root.querySelectorAll('.wish-card[data-group-key]')];
      const el = ensureIndicator();
      let y;
      if (!cards.length) return;
      if (idx <= 0) {
        y = cards[0].getBoundingClientRect().top;
      } else if (idx >= cards.length) {
        y = cards[cards.length - 1].getBoundingClientRect().bottom;
      } else {
        const prev = cards[idx - 1].getBoundingClientRect();
        const next = cards[idx].getBoundingClientRect();
        y = (prev.bottom + next.top) / 2;
      }
      const rect = root.getBoundingClientRect();
      el.style.top = `${y}px`;
      el.style.left = `${rect.left + 8}px`;
      el.style.width = `${Math.max(0, rect.width - 16)}px`;
      el.hidden = false;
    }

    function clearLongPress() {
      if (longPressTimer != null) {
        clearTimeout(longPressTimer);
        longPressTimer = null;
      }
    }

    function resetActiveDragUi() {
      root.classList.remove('wish-reorder-active');
      root.querySelectorAll('.wish-drag-source').forEach((el) => {
        el.classList.remove('wish-drag-source');
      });
      root.querySelectorAll('.wish-drag-handle.is-pressing').forEach((el) => {
        el.classList.remove('is-pressing');
      });
      hideIndicator();
    }

    function endDrag(commit) {
      const key = draggingKey;
      const idx = insertIndex;
      draggingKey = null;
      insertIndex = null;
      activePointerId = null;
      activeHandle = null;
      dragPending = false;
      resetActiveDragUi();
      if (commit && key != null && idx != null) {
        options.onDrop(key, idx);
      } else {
        options.onCancel();
      }
    }

    function beginDragUi(handle, card, pointerId) {
      draggingKey = card.dataset.groupKey;
      activeHandle = handle;
      handle.classList.add('is-pressing');
      card.classList.add('wish-drag-source');
      root.classList.add('wish-reorder-active');
      try {
        handle.setPointerCapture(pointerId);
      } catch (e) { /* ignore */ }
    }

    function onPointerDown(ev) {
      if (!canUseReorder()) return;
      if (ev.button !== 0) return;

      const handle = ev.target.closest('.wish-drag-handle');
      if (!handle || !root.contains(handle)) return;

      const card = handle.closest('.wish-card[data-group-key]');
      if (!card || !root.contains(card)) return;

      const groupKey = card.dataset.groupKey;
      if (!groupKey || options.isPinned(groupKey)) return;

      ev.preventDefault();

      activePointerId = ev.pointerId;

      clearLongPress();
      longPressTimer = setTimeout(() => {
        longPressTimer = null;
        dragPending = true;
        beginDragUi(handle, card, ev.pointerId);

        const orderKeys = options.getOrderKeys();
        Promise.resolve(options.onDragStart(groupKey, orderKeys))
          .then((started) => {
            if (!dragPending) return;
            if (started === false) {
              dragPending = false;
              endDrag(false);
            }
          })
          .catch(() => {
            if (!dragPending) return;
            dragPending = false;
            endDrag(false);
          });
      }, LONG_PRESS_MS);
    }

    function onPointerMove(ev) {
      if (longPressTimer != null && ev.pointerId === activePointerId) return;
      if (!draggingKey || ev.pointerId !== activePointerId) return;

      ev.preventDefault();

      const orderKeys = options.getOrderKeys();
      insertIndex = computeInsertIndex(
        root,
        ev.clientY,
        draggingKey,
        orderKeys,
        options.getPinnedKeys(),
      );
      if (insertIndex == null) {
        hideIndicator();
      } else {
        showIndicatorAtIndex(insertIndex);
      }
    }

    function finishPointer(ev) {
      clearLongPress();
      if (longPressTimer != null && ev.pointerId === activePointerId) {
        activePointerId = null;
        return;
      }
      if (!draggingKey || ev.pointerId !== activePointerId) return;
      const shouldCommit = insertIndex != null;
      endDrag(shouldCommit);
    }

    root.addEventListener('pointerdown', onPointerDown, { passive: false });
    root.addEventListener('pointermove', onPointerMove, { passive: false });
    root.addEventListener('pointerup', finishPointer);
    root.addEventListener('pointercancel', finishPointer);
  }

  global.DjWishReorder = {
    parseOrderKeys: parseOrderKeys,
    applyDisplayOrder: applyDisplayOrder,
    buildServerDisplayOrder: buildServerDisplayOrder,
    storageKeysForGroupOrder: storageKeysForGroupOrder,
    resolveStoredPinKeys: resolveStoredPinKeys,
    applyLocalInsertAt: applyLocalInsertAt,
    orderWithPinsFirst: orderWithPinsFirst,
    commitWishOrder: commitWishOrder,
    setupWishListReorder: setupWishListReorder,
  };
})(window);
