const admin = require("firebase-admin");
// Using v2 functions for better performance and cost management
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");

admin.initializeApp();
const db = admin.firestore();
// Define the messaging instance globally
const messaging = admin.messaging();

// --- 🎯 CORE FIX APPLIED HERE ---
////////////////////////////////////////
// ✅ Helper: Send FCM Notification (Corrected Payload)
// This function sends a message with both 'notification' (for system tray)
// and 'data' (for app logic/foreground local notifications).
async function sendFCM(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return;

  console.log(`Attempting to send FCM: Title="${title}", Devices=${tokens.length}`);

  const chunkSize = 500; // max 500 per send
  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    
    // The message object is now a MulticastMessage (tokens are included inside the object)
    const message = {
      // --- 1. NOTIFICATION BLOCK (REQUIRED FOR OS/FIREBASE AUTO-DISPLAY) ---
      notification: {
        title: title,
        body: body,
        // 🛑 REMOVED: sound: "default", (This caused the "Invalid JSON payload received" error)
      },
      // --- 2. DATA BLOCK (FOR DART CODE/LOCAL NOTIFICATION FALLBACK/DEEP LINKING) ---
      data: {
        title: title, 
        body: body,   
        ...data,      
      },
      android: {
        priority: 'high', 
        notification: {
          channelId: 'high_importance_channel', 
          clickAction: 'FLUTTER_NOTIFICATION_CLICK', 
          sound: "default", // ✅ CORRECT LOCATION for Android sound
        }
      },
      apns: {
        headers: {
          "apns-priority": "10", 
        },
        payload: {
          aps: {
            sound: "default", // ✅ CORRECT LOCATION for APNS/iOS sound
            contentAvailable: true,
          },
        },
      },
      // Add the list of tokens to the message object for multicast
      tokens: chunk, 
    };

    try {
      // Use the official replacement method for batch sending
      const response = await messaging.sendEachForMulticast(message);
      
      // Log success and failure counts for debugging
      console.log(`✅ Sent: "${title}" → ${chunk.length} devices. Success: ${response.successCount}, Failure: ${response.failureCount}`);
      
      // --- Diagnostic Logging (Kept for robust testing) ---
      if (response.failureCount > 0) {
        console.warn(`⚠️ Detailed Failure Analysis for ${response.failureCount} tokens:`);

        response.responses.forEach((resp, index) => {
          if (resp.success === false) {
            const failedToken = chunk[index];
            const errorCode = resp.error?.code || 'UNKNOWN_ERROR';
            const errorMessage = resp.error?.message || 'No specific error message provided.';

            // Log the beginning and end of the token for identification, and the full error
            console.error(
              `❌ Token Failure [Token: ${failedToken.substring(0, 10)}...${failedToken.substring(failedToken.length - 10)}]: ` + 
              `Code: ${errorCode}, Message: ${errorMessage}`
            );

            // IMPORTANT: Check for codes that signify an invalid/stale token
            if (errorCode === 'messaging/registration-token-not-registered' || errorMessage.includes('Unregistered')) {
              console.error(`🚨 DIAGNOSIS: This token is likely stale/invalid and should be removed from Firestore.`);
            }
          }
        });
      }
      // --- End of New Logic ---
      
    } catch (err) {
      console.error("❌ FCM batch send error (System error, not device error):", err);
    }
  }
}
// ---------------------------------

////////////////////////////////////////
// 1️⃣ Notify all users when a new item is reported
exports.notifyNewItem = onDocumentCreated("items/{itemId}", async (event) => {
  const newItem = event.data.data();
  if (!newItem) return;

  // Retrieve all tokens (This assumes you want to notify every user)
  const usersSnap = await db.collection("users").get();
  const tokens = usersSnap.docs
    .map(d => d.data().fcmToken)
    .filter(t => t && typeof t === 'string');

  const title = `📢 New ${newItem.type || "item"} reported`;
  const body = `${newItem.title || "Untitled"} at ${newItem.location || "Unknown"}`;

  await sendFCM(tokens, title, body, { itemId: event.params.itemId });
});

////////////////////////////////////////
// 2️⃣ Notify office admins when a collection request is created
exports.notifyCollectionRequest = onDocumentCreated("collectionRequests/{reqId}", async (event) => {
  const req = event.data.data();
  if (!req || !req.itemId || !req.verifiedOfficeId) return;

  // Query for admins/staff in the item's office
  const adminSnap = await db
    .collection("users")
    .where("officeId", "==", req.verifiedOfficeId)
    .where("role", "in", ["office_admin", "staff"])
    .get();

  const tokens = adminSnap.docs
    .map(d => d.data().fcmToken)
    .filter(t => t && typeof t === 'string');

  if (!tokens.length) {
    console.log(`⚠️ No active tokens found for office ${req.verifiedOfficeId} admin/staff.`);
    return;
  }
  
  const itemSnap = await db.collection("items").doc(req.itemId).get();
  const item = itemSnap.data() ?? {};
  const itemTitle = item.title || req.itemId;

  await sendFCM(tokens, "📬 New Collection Request", `Request received for item: ${itemTitle}.`, {
    itemId: req.itemId,
    reqId: event.params.reqId,
  });
});

////////////////////////////////////////
// 3️⃣ Notify requester when office schedules pickup
exports.notifyPickupScheduled = onDocumentUpdated("collectionRequests/{reqId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  // Check if status changed TO scheduled
  if (before.status !== "scheduled" && after.status === "scheduled") {
    const userSnap = await db.collection("users").doc(after.requesterId).get();
    const token = userSnap.exists ? userSnap.data()?.fcmToken : null;

    if (!token || typeof token !== 'string') {
      console.log(`⚠️ Invalid or missing token for requester ${after.requesterId}.`);
      return;
    }

    const itemSnap = await db.collection("items").doc(after.itemId).get();
    const item = itemSnap.data() ?? {};

    let pickupTimeStr = "N/A";
    if (after.pickupTime && after.pickupTime.toDate) {
      // Format pickup time nicely for the user
      pickupTimeStr = after.pickupTime.toDate().toLocaleString("en-IN", {
        dateStyle: "medium",
        timeStyle: "short",
      });
    }

    // Since we are sending to a single token here, sendEachForMulticast is still
    // the safest option, handling the single token case efficiently.
    await sendFCM([token], "📅 Pickup Scheduled", `Your item "${item?.title || after.itemId}" is scheduled for pickup at ${pickupTimeStr}`, {
      itemId: after.itemId,
      reqId: event.params.reqId,
    });
  }
});