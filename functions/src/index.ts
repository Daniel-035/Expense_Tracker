import {onDocumentDeleted, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";

initializeApp();

const region = "asia-south1";
const bucketName = "expense-tracker-70365.firebasestorage.app";
const recentLoginSeconds = 10 * 60;

export const deleteUserAccount = onCall(
  {
    region,
    enforceAppCheck: true,
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }

    const uid = request.auth.uid;
    const authenticatedAt = Number(request.auth.token.auth_time ?? 0);
    const ageSeconds = Math.floor(Date.now() / 1000) - authenticatedAt;
    if (authenticatedAt === 0 || ageSeconds > recentLoginSeconds) {
      throw new HttpsError(
        "failed-precondition",
        "Sign in again before deleting your account.",
      );
    }

    try {
      const firestore = getFirestore();
      await firestore.recursiveDelete(firestore.doc(`users/${uid}`));

      await getStorage()
        .bucket(bucketName)
        .deleteFiles({prefix: `users/${uid}/`, force: true});

      try {
        await getAuth().deleteUser(uid);
      } catch (error) {
        const code = (error as {code?: string}).code;
        if (code !== "auth/user-not-found") throw error;
      }

      logger.info("Deleted LedgerOne account data", {uid});
      return {success: true};
    } catch (error) {
      logger.error("Account deletion failed", {uid, error});
      throw new HttpsError(
        "internal",
        "Could not completely delete the account. Please try again.",
      );
    }
  },
);


// Deleting a parent document does not delete its subcollections.
export const cleanupDeletedGoal = onDocumentDeleted(
  {document: "users/{uid}/goals/{goalId}", region, retry: true},
  async (event) => {
    if (!event.data) return;
    const ref = event.data.ref;
    // A restored goal must keep its new history.
    if ((await ref.get()).exists) return;
    await getFirestore().recursiveDelete(ref.collection("deposits"));
  },
);

export const cleanupDeletedTransactionReceipt = onDocumentDeleted(
  {document: "users/{uid}/transactions/{transactionId}", region, retry: true},
  async (event) => {
    if (!event.data) return;
    if ((await event.data.ref.get()).exists) return;
    const path = receiptPath(event.data.data().receiptUrl, event.params.uid);
    if (path) await getStorage().bucket(bucketName).file(path).delete({ignoreNotFound: true});
  },
);


function receiptPath(raw: unknown, uid: string): string | null {
  if (typeof raw !== "string") return null;
  try {
    const url = new URL(raw);
    if (url.hostname !== "firebasestorage.googleapis.com") return null;
    const prefix = `/v0/b/${bucketName}/o/`;
    if (!url.pathname.startsWith(prefix)) return null;
    const path = decodeURIComponent(url.pathname.slice(prefix.length));
    return path.startsWith(`users/${uid}/receipts/`) ? path : null;
  } catch { return null; }
}

export const cleanupReplacedReceipt = onDocumentUpdated(
  {document: "users/{uid}/transactions/{transactionId}", region, retry: true},
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data().receiptUrl;
    const after = event.data.after.data().receiptUrl;
    if (before === after) return;
    const latest = await event.data.after.ref.get();
    if (latest.data()?.receiptUrl === before) return;
    const path = receiptPath(before, event.params.uid);
    if (path) await getStorage().bucket(bucketName).file(path).delete({ignoreNotFound: true});
  },
);
