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
