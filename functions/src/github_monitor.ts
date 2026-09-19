/* eslint-disable require-jsdoc */

import {createHash} from "node:crypto";

import {cert, initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  getFirestore,
  QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as cheerio from "cheerio";

const serviceAccountJson =
  process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

if (!serviceAccountJson) {
  throw new Error(
    "FIREBASE_SERVICE_ACCOUNT_JSON is not configured.",
  );
}

initializeApp({
  credential: cert(JSON.parse(serviceAccountJson)),
});

const db = getFirestore();
const messaging = getMessaging();

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
        "user-agent":
          "ExamReady-OfficialSourceMonitor/1.0",
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
    const href = $(element).attr("href");

    if (!href) {
      return;
    }

    const title = normalizeText($(element).text());

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

  return notice.title.includes(match[1]);
}

async function monitorNoticeSource(
  sourceDocument: QueryDocumentSnapshot,
  source: OfficialSourceData,
): Promise<void> {
  if (!source.url) {
    return;
  }

  const html = await fetchHtml(source.url);

  const notices = extractPublicNotices(
    html,
    source.url,
  );

  const seenCollection =
    sourceDocument.ref.collection("seenNotices");

  const seenSnapshot =
    await seenCollection.get();

  const seenIds = new Set(
    seenSnapshot.docs.map((document) => document.id),
  );

  const isFirstRun = seenSnapshot.empty;

  let newRelevantNotices = 0;

  for (const notice of notices) {
    if (seenIds.has(notice.id)) {
      continue;
    }

    await seenCollection.doc(notice.id).set({
      title: notice.title,
      url: notice.url,
      firstSeenAt: FieldValue.serverTimestamp(),
      baseline: isFirstRun,
    });

    // First run creates a baseline.
    // Existing notices must never generate alerts.
    if (isFirstRun) {
      continue;
    }

    const matchedCycleIds =
      (source.cycleIds ?? []).filter(
        (cycleId) =>
          noticeMatchesCycle(notice, cycleId),
      );

    if (matchedCycleIds.length === 0) {
      console.log(
        `Ignoring unrelated notice: ${notice.title}`,
      );
      continue;
    }

    const detectionId =
      `${sourceDocument.id}_${notice.id}`;

    await db
      .collection("sourceDetections")
      .doc(detectionId)
      .set(
        {
          sourceId: sourceDocument.id,
          sourceName:
            source.name ?? sourceDocument.id,
          sourceUrl: source.url,
          noticeTitle: notice.title,
          noticeUrl: notice.url,
          cycleIds: matchedCycleIds,
          detectedAt:
            FieldValue.serverTimestamp(),
          verificationStatus:
            "pendingVerification",
          processingStatus: "needsReview",
        },
        {merge: true},
      );

    newRelevantNotices++;

    console.log(
      `Relevant notice detected: ${notice.title}`,
    );
  }

  await sourceDocument.ref.set(
    {
      lastCheckedAt:
        FieldValue.serverTimestamp(),
      status: "verified",
      processingStatus: "processed",
      noticeCount: notices.length,
    },
    {merge: true},
  );

  console.log(
    `${sourceDocument.id}: ${notices.length} notices, ` +
      `${newRelevantNotices} new relevant notice(s).`,
  );
}

async function monitorOfficialSources(): Promise<void> {
  const sources = await db
    .collection("officialSources")
    .where("enabled", "==", true)
    .get();

  console.log(
    `Checking ${sources.size} official source(s).`,
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
      } else {
        await sourceDocument.ref.set(
          {
            lastCheckedAt:
              FieldValue.serverTimestamp(),
            status: "verified",
            processingStatus: "processed",
          },
          {merge: true},
        );
      }
    } catch (error) {
      console.error(
        `Failed checking ${sourceDocument.id}:`,
        error,
      );

      await sourceDocument.ref.set(
        {
          lastCheckedAt:
            FieldValue.serverTimestamp(),
          status: "sourceUnavailable",
          processingStatus: "failed",
        },
        {merge: true},
      );
    }
  }
}

async function notifyVerifiedUpdates(): Promise<void> {
  const updates = await db
    .collection("examinationUpdates")
    .where(
      "verificationStatus",
      "==",
      "verified",
    )
    .limit(100)
    .get();

  for (const updateDocument of updates.docs) {
    const update = updateDocument.data();

    if (
      !update.publishedAt ||
      update.notificationSentAt
    ) {
      continue;
    }

    const cycleId =
      update.cycleId as string | undefined;

    const title =
      update.title as string | undefined;

    if (!cycleId || !title) {
      continue;
    }

    const users = await db
      .collection("users")
      .get();

    const tokens = new Set<string>();

    for (const user of users.docs) {
      const selectedExam = await user.ref
        .collection("examinations")
        .doc(cycleId)
        .get();

      if (!selectedExam.exists) {
        continue;
      }

      const preferences = await user.ref
        .collection("settings")
        .doc("notifications")
        .get();

      if (
        preferences.data()
          ?.officialUpdatesEnabled === false
      ) {
        continue;
      }

      const tokenDocuments = await user.ref
        .collection("fcmTokens")
        .get();

      for (const tokenDocument of
        tokenDocuments.docs) {
        const token =
          tokenDocument.data().token as
            | string
            | undefined;

        if (token) {
          tokens.add(token);
        }
      }
    }

    const allTokens = [...tokens];

    const body =
      typeof update.body === "string" &&
      update.body.trim().length > 0 ?
        update.body :
        "A verified official exam update is available.";

    for (
      let index = 0;
      index < allTokens.length;
      index += 500
    ) {
      const batch = allTokens.slice(
        index,
        index + 500,
      );

      if (batch.length === 0) {
        continue;
      }

      await messaging.sendEachForMulticast({
        tokens: batch,
        notification: {
          title,
          body,
        },
        data: {
          type: "examinationUpdate",
          updateId: updateDocument.id,
          cycleId,
        },
        android: {
          priority: "high",
          notification: {
            channelId:
              NOTIFICATION_CHANNEL,
          },
        },
      });
    }

    await updateDocument.ref.set(
      {
        notificationSentAt:
          FieldValue.serverTimestamp(),
        notificationRecipientCount:
          allTokens.length,
      },
      {merge: true},
    );

    console.log(
      `Processed ${updateDocument.id}: ` +
        `${allTokens.length} recipient(s).`,
    );
  }
}

async function main(): Promise<void> {
  console.log("ExamReady automation started.");

  await monitorOfficialSources();
  await notifyVerifiedUpdates();

  console.log("ExamReady automation finished.");
}

main().catch((error) => {
  console.error("ExamReady automation failed:", error);
  process.exitCode = 1;
});
