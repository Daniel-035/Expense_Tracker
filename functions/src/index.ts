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
