/**
 * Gast-Profil: `users/{uid}.guestWishesSubmittedCount` bei Wunsch-Löschung dekrementieren
 * (DJ-Löschung, Gast-Löschung, Batch-Löschung).
 */
const { onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

const FIELD = 'guestWishesSubmittedCount';

function registeredUidFromWish(data) {
  if (!data || data.is_registered_user !== true) return null;
  const uid = data.user_id;
  if (typeof uid !== 'string') return null;
  const trimmed = uid.trim();
  return trimmed || null;
}

async function decrementGuestWishCount(uid) {
  const ref = admin.firestore().collection('users').doc(uid);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const cur = snap.data()[FIELD];
    const current =
      typeof cur === 'number' && Number.isFinite(cur) ? Math.max(0, cur) : 0;
    const next = Math.max(0, current - 1);
    tx.update(ref, { [FIELD]: next });
  });
}

const onGuestWishSubmittedCountDelete = onDocumentDeleted(
  {
    document: 'parties/{partyId}/wishes/{wishId}',
    region: 'us-central1',
  },
  async (event) => {
    const data = event.data?.data();
    const uid = registeredUidFromWish(data);
    if (!uid) return;
    try {
      await decrementGuestWishCount(uid);
    } catch (e) {
      console.error('onGuestWishSubmittedCountDelete:', uid, e);
    }
  },
);

module.exports = {
  onGuestWishSubmittedCountDelete,
};
