const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

/**
 * Triggered on Firestore users/{userId} update.
 * Detects if user moved to a new city where any accepted friends currently reside.
 * Sends push notification via FCM / APNs when a match is found (throttled 24h).
 */
exports.onLocationUpdate = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const before = change.before.data();
    const after = change.after.data();

    // 1. Only proceed if currentCity changed
    if (before.currentCity === after.currentCity) return null;
    // 2. Ignore if user is in Ghost Mode
    if (after.isGhost) return null;

    const newCity = after.currentCity;
    if (!newCity) return null;

    console.log(`[onLocationUpdate] User ${userId} (${after.displayName}) moved to ${newCity}`);

    // 3. Find all accepted friendships for this user
    const friendshipsSnap = await db
      .collection("friendships")
      .where("users", "array-contains", userId)
      .where("status", "==", "accepted")
      .get();

    if (friendshipsSnap.empty) return null;

    const friendIds = [];
    friendshipsSnap.forEach((doc) => {
      const users = doc.data().users;
      const friendId = users.find((id) => id !== userId);
      if (friendId) friendIds.push(friendId);
    });

    if (friendIds.length === 0) return null;

    // 4. Batch query friends in the same city
    const friendsInSameCity = [];
    for (const batch of chunkArray(friendIds, 30)) {
      const usersSnap = await db
        .collection("users")
        .where(admin.firestore.FieldPath.documentId(), "in", batch)
        .where("currentCity", "==", newCity)
        .where("isGhost", "==", false)
        .get();

      usersSnap.forEach((doc) => {
        friendsInSameCity.push({
          friendId: doc.id,
          friendName: doc.data().displayName,
          friendToken: doc.data().fcmToken,
        });
      });
    }

    console.log(`[onLocationUpdate] Found ${friendsInSameCity.length} friends in ${newCity}`);

    // 5. Send notifications with 24h anti-spam deduplication
    for (const friend of friendsInSameCity) {
      const pairKey = [userId, friend.friendId].sort().join("_");
      const oneDayAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 24 * 60 * 60 * 1000)
      );

      const recentNotif = await db
        .collection("notifications_log")
        .where("pairKey", "==", pairKey)
        .where("city", "==", newCity)
        .where("sentAt", ">", oneDayAgo)
        .limit(1)
        .get();

      if (!recentNotif.empty) {
        console.log(`[onLocationUpdate] Skipping notification for pair ${pairKey} in ${newCity} (sent <24h ago)`);
        continue;
      }

      // Notify Friend
      if (friend.friendToken) {
        await admin.messaging().send({
          token: friend.friendToken,
          notification: {
            title: "🎉 Friend in Same City!",
            body: `${after.displayName} just arrived in ${newCity}! Time to meet up ☕️`,
          },
          apns: {
            payload: { aps: { sound: "default" } },
          },
        });
      }

      // Notify User
      if (after.fcmToken) {
        await admin.messaging().send({
          token: after.fcmToken,
          notification: {
            title: "🎉 Friend in Same City!",
            body: `${friend.friendName} is also in ${newCity}! Time to meet up ☕️`,
          },
          apns: {
            payload: { aps: { sound: "default" } },
          },
        });
      }

      // Log notification
      await db.collection("notifications_log").add({
        pairKey: pairKey,
        users: [userId, friend.friendId],
        city: newCity,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        type: "same_city",
      });
    }

    return null;
  });

function chunkArray(array, size) {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}
