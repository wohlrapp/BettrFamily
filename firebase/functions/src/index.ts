// BettrFamily Cloud Functions
//
// OPTIONAL: These functions are NOT required for the app to work.
// The iOS app handles heartbeat checking and notifications entirely on-device
// using Firestore listeners + local notifications (works on free Spark plan).
//
// Deploy these only if you upgrade to the Blaze plan and want server-side
// reliability (e.g. notifications even when no family member has the app open).

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

const HEARTBEAT_THRESHOLD_MS = 30 * 60 * 1000; // 30 minutes

/**
 * OPTIONAL: Scheduled heartbeat check (requires Blaze plan).
 * The iOS app already does this client-side via FamilyMonitorService.
 */
export const checkHeartbeats = functions.scheduler
  .onSchedule("every 15 minutes", async () => {
    const now = Date.now();
    const familiesSnapshot = await db.collection("families").get();

    for (const familyDoc of familiesSnapshot.docs) {
      const familyID = familyDoc.id;
      const heartbeatsSnapshot = await db
        .collection("families")
        .doc(familyID)
        .collection("heartbeats")
        .get();

      for (const heartbeatDoc of heartbeatsSnapshot.docs) {
        const data = heartbeatDoc.data();
        const timestamp = data.timestamp?.toMillis?.() ?? 0;
        const memberName = data.memberName ?? "Unbekannt";
        const memberID = heartbeatDoc.id;

        if (now - timestamp > HEARTBEAT_THRESHOLD_MS) {
          await db
            .collection("families")
            .doc(familyID)
            .collection("complianceEvents")
            .add({
              memberID,
              memberName,
              eventType: "heartbeat_missing",
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              details: `Kein Heartbeat von ${memberName} seit ${Math.round(
                (now - timestamp) / 60000
              )} Minuten`,
              acknowledged: false,
            });
        }
      }
    }
  });

/**
 * OPTIONAL: Daily streak check — runs at midnight, updates streaks for all members.
 * Checks if yesterday was a positive day and updates streak accordingly.
 */
export const dailyStreakCheck = functions.scheduler
  .onSchedule("every day 00:05", async () => {
    const familiesSnapshot = await db.collection("families").get();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);
    const yesterdayTs = yesterday.getTime() / 1000;
    const todayTs = yesterdayTs + 86400;

    for (const familyDoc of familiesSnapshot.docs) {
      const familyID = familyDoc.id;

      // Get all daily scores from yesterday
      const scoresSnapshot = await db
        .collection("families")
        .doc(familyID)
        .collection("dailyScores")
        .where("date", ">=", yesterdayTs)
        .where("date", "<", todayTs)
        .get();

      for (const scoreDoc of scoresSnapshot.docs) {
        const score = scoreDoc.data();
        const memberID = score.memberID;
        const rawTotal = score.rawTotal ?? 0;
        const isPositive = rawTotal > 0;

        // Get or create streak record
        const streakRef = db
          .collection("families")
          .doc(familyID)
          .collection("streakRecords")
          .doc(memberID);

        const streakDoc = await streakRef.get();
        const streak = streakDoc.exists
          ? streakDoc.data()!
          : { currentStreak: 0, longestStreak: 0, totalAccumulatedPoints: 0 };

        if (isPositive) {
          streak.currentStreak = (streak.currentStreak || 0) + 1;
          streak.longestStreak = Math.max(
            streak.longestStreak || 0,
            streak.currentStreak
          );
          streak.lastPositiveDate = yesterdayTs;

          // Calculate multiplier
          let multiplier = 1.0;
          if (streak.currentStreak >= 30) multiplier = 3.0;
          else if (streak.currentStreak >= 7) multiplier = 2.0;
          else if (streak.currentStreak >= 2) multiplier = 1.5;

          streak.totalAccumulatedPoints =
            (streak.totalAccumulatedPoints || 0) + rawTotal * multiplier;
        } else {
          streak.currentStreak = 0;
        }

        await streakRef.set(
          { ...streak, memberID },
          { merge: true }
        );
      }
    }
  });

/**
 * OPTIONAL: Triggered when a social media compliance event is created.
 * Sends FCM push notification to all other family members.
 * Requires FCM tokens to be stored in member documents.
 */
export const onSocialMediaAlert = functions.firestore
  .onDocumentCreated(
    "families/{familyID}/complianceEvents/{eventID}",
    async (event) => {
      const data = event.data?.data();
      if (!data || data.eventType !== "social_media_used") return;

      const familyID = event.params.familyID;
      const memberID = data.memberID;
      const memberName = data.memberName ?? "Familienmitglied";
      const details = data.details ?? "Social Media genutzt";

      // Get all family members' FCM tokens (except the one who triggered)
      const membersSnapshot = await db
        .collection("members")
        .where("familyGroupID", "==", familyID)
        .get();

      const tokens: string[] = [];
      for (const memberDoc of membersSnapshot.docs) {
        if (memberDoc.id === memberID) continue;
        const fcmToken = memberDoc.data().fcmToken;
        if (fcmToken) tokens.push(fcmToken);
      }

      if (tokens.length === 0) return;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Social Media genutzt",
          body: `${memberName}: ${details}`,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });
    }
  );
