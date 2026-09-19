/* eslint-disable require-jsdoc */
import {createHash} from "node:crypto";

import {initializeApp} from "firebase-admin/app";
import {
  FieldPath,
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import * as cheerio from "cheerio";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const REGION = "asia-south1";
const NOTIFICATION_CHANNEL = "examready_alerts_v2";

type OfficialSourceData = {
  name?: string;
  url?: string;
  enabled?: boolean;
  type?: string;
  cycleIds?: string[];
};

type NoticeEntry = {
  id: string;
  title: string;
  url: string;
};

function normalizeText(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function noticeId(url: string): string {
  return createHash("sha256")
    .update(url)
    .digest("hex")
    .slice(0, 32);
}

async function fetchHtml(url: string): Promise<string> {
  const controller = new AbortController();

  const timeout = setTimeout(() => {
    controller.abort();
  }, 20000);

  try {
    const response = await fetch(url, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "user-agent": "ExamReady-OfficialSourceMonitor/1.0",
      },
    });

    if (!response.ok) {
      throw new Error(
        `HTTP ${response.status} while checking ${url}`,
      );
    }

    return await response.text();
  } finally {
    clearTimeout(timeout);
  }
}

function extractPublicNotices(
  html: string,
  pageUrl: string,
): NoticeEntry[] {
  const $ = cheerio.load(html);

  const results = new Map<string, NoticeEntry>();

  $("a").each((_, element) => {
    const rawTitle = $(element).text();
    const href = $(element).attr("href");

    if (!href) {
      return;
    }

    const title = normalizeText(rawTitle);

    if (!title) {
      return;
    }

    let absoluteUrl: URL;

    try {
      absoluteUrl = new URL(href, pageUrl);
    } catch {
      return;
    }

    const host = absoluteUrl.hostname.toLowerCase();

    const isOfficialDocument =
      host.endsWith("nta.nic.in") ||
      host.endsWith("s3waas.gov.in") ||
      host.endsWith("nic.in");

    if (!isOfficialDocument) {
      return;
    }

    const lowerTitle = title.toLowerCase();

    const looksLikeNotice =
      lowerTitle.includes("jee") ||
      lowerTitle.includes("joint entrance") ||
      lowerTitle.includes("admit card") ||
      lowerTitle.includes("answer key") ||
      lowerTitle.includes("result") ||
      lowerTitle.includes("application") ||
      lowerTitle.includes("examination city") ||
      lowerTitle.includes("correction");

    if (!looksLikeNotice) {
      return;
    }

    const url = absoluteUrl.toString();
    const id = noticeId(url);

    results.set(id, {
      id,
      title,
      url,
    });
  });

  return [...results.values()];
}

function noticeMatchesCycle(
  notice: NoticeEntry,
  cycleId: string,
): boolean {
  const match = cycleId.match(/(\d{4})$/);

  if (!match) {
    return true;
  }

  const cycleYear = match[1];

  return notice.title.includes(cycleYear);
}

async function monitorNoticeSource(
  sourceDocument: FirebaseFirestore.QueryDocumentSnapshot,
  source: OfficialSourceData,
): Promise<void> {
  const url = source.url;

  if (!url) {
    return;
  }

  const html = await fetchHtml(url);

  const notices = extractPublicNotices(html, url);

  const seenCollection =
    sourceDocument.ref.collection("seenNotices");

  const seenSnapshot = await seenCollection.get();

  const seenIds = new Set(
    seenSnapshot.docs.map((document) => document.id),
  );

  const isFirstRun = seenSnapshot.empty;

  for (const notice of notices) {
    if (seenIds.has(notice.id)) {
      continue;
    }

    if (isFirstRun) {
      await seenCollection.doc(notice.id).set({
        title: notice.title,
        url: notice.url,
        firstSeenAt: FieldValue.serverTimestamp(),
        baseline: true,
      });

      continue;
    }

    const cycleIds = source.cycleIds ?? [];

    const matchedCycleIds = cycleIds.filter(
      (cycleId) => noticeMatchesCycle(notice, cycleId),
    );

    await seenCollection.doc(notice.id).set({
      title: notice.title,
      url: notice.url,
      firstSeenAt: FieldValue.serverTimestamp(),
      baseline: false,
    });

    if (matchedCycleIds.length === 0) {
      logger.info(
        `New notice ignored for current cycles: ${notice.title}`,
      );

      continue;
    }

    await db.collection("sourceDetections").add({
      sourceId: sourceDocument.id,
      sourceName: source.name ?? sourceDocument.id,
      sourceUrl: url,
      noticeTitle: notice.title,
      noticeUrl: notice.url,
      cycleIds: matchedCycleIds,
      detectedAt: FieldValue.serverTimestamp(),
      verificationStatus: "pendingVerification",
      processingStatus: "needsReview",
    });

    logger.warn(
      `New relevant official notice detected: ${notice.title}`,
    );
  }

  await sourceDocument.ref.set(
    {
      lastCheckedAt: FieldValue.serverTimestamp(),
      status: "verified",
      processingStatus: "processed",
      noticeCount: notices.length,
    },
    {merge: true},
  );
}

export const monitorOfficialSources = onSchedule(
  {
    schedule: "every 30 minutes",
    region: REGION,
    timeZone: "Asia/Kolkata",
    memory: "256MiB",
    timeoutSeconds: 120,
  },
  async () => {
    const sources = await db
      .collection("officialSources")
      .where("enabled", "==", true)
      .get();

    logger.info(
      `Checking ${sources.size} enabled official sources.`,
    );

    for (const sourceDocument of sources.docs) {
      const source =
        sourceDocument.data() as OfficialSourceData;

      try {
        if (source.type === "notification") {
          await monitorNoticeSource(
            sourceDocument,
            source,
          );

          continue;
        }

        await sourceDocument.ref.set(
          {
            lastCheckedAt: FieldValue.serverTimestamp(),
            status: "verified",
            processingStatus: "processed",
          },
          {merge: true},
        );
      } catch (error) {
        logger.error(
          `Official source check failed: ${sourceDocument.id}`,
          error,
        );

        await sourceDocument.ref.set(
          {
            lastCheckedAt: FieldValue.serverTimestamp(),
            status: "sourceUnavailable",
            processingStatus: "failed",
          },
          {merge: true},
        );
      }
    }
  },
);

export const notifyVerifiedExaminationUpdate =
    onDocumentWritten(
      {
        document: "examinationUpdates/{updateId}",
        region: REGION,
      },
      async (event) => {
        const afterSnapshot = event.data?.after;

        if (!afterSnapshot?.exists) {
          return;
        }

        const after = afterSnapshot.data();

        if (!after) {
          return;
        }

        const verificationStatus =
          after.verificationStatus as string | undefined;

        const cycleId =
          after.cycleId as string | undefined;

        const title =
          after.title as string | undefined;

        if (
          verificationStatus !== "verified" ||
          !after.publishedAt ||
          !cycleId ||
          !title
        ) {
          return;
        }

        if (after.notificationSentAt) {
          return;
        }

        const before = event.data?.before.data();

        const wasAlreadyPublished =
          before?.verificationStatus === "verified" &&
          before?.publishedAt != null;

        if (wasAlreadyPublished) {
          return;
        }

        const selectedExamDocuments = await db
          .collectionGroup("examinations")
          .where(FieldPath.documentId(), "==", cycleId)
          .get();

        const tokens = new Set<string>();

        for (const selectedExam of
          selectedExamDocuments.docs) {
          const userDocument =
            selectedExam.ref.parent.parent;

          if (!userDocument) {
            continue;
          }

          const preferences = await userDocument
            .collection("settings")
            .doc("notifications")
            .get();

          const preferencesData = preferences.data();

          const officialUpdatesEnabled =
            preferencesData?.officialUpdatesEnabled !== false;

          if (!officialUpdatesEnabled) {
            continue;
          }

          const tokenDocuments = await userDocument
            .collection("fcmTokens")
            .get();

          for (const tokenDocument of
            tokenDocuments.docs) {
            const token =
              tokenDocument.data().token as string | undefined;

            if (token) {
              tokens.add(token);
            }
          }
        }

        const allTokens = [...tokens];

        const body =
          typeof after.body === "string" &&
          after.body.trim().length > 0 ?
            after.body :
            "A verified update is available in ExamReady.";

        for (
          let index = 0;
          index < allTokens.length;
          index += 500
        ) {
          const batch = allTokens.slice(
            index,
            index + 500,
          );

          await messaging.sendEachForMulticast({
            tokens: batch,
            notification: {
              title,
              body,
            },
            data: {
              type: "examinationUpdate",
              updateId: afterSnapshot.id,
              cycleId,
            },
            android: {
              priority: "high",
              notification: {
                channelId: NOTIFICATION_CHANNEL,
              },
            },
          });
        }

        await afterSnapshot.ref.set(
          {
            notificationSentAt:
              FieldValue.serverTimestamp(),
            notificationRecipientCount:
              allTokens.length,
          },
          {merge: true},
        );

        logger.info(
          `Notification sent for ${afterSnapshot.id} ` +
            `to ${allTokens.length} device token(s).`,
        );
      },
    );
