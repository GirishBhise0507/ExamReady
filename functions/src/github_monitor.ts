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

const NOTIFICATION_CHANNEL =
  "examready_alerts_v2";

const MONITOR_SCHEMA_VERSION = 2;

type SourceKind =
  | "jeeMain"
  | "neetUg"
  | "cuetUg"
  | "gate2027"
  | "unsupported";

type OfficialSourceData = {
  name?: string;
  url?: string;
  enabled?: boolean;
  type?: string;
  cycleIds?: string[];
  monitorSchemaVersion?: number;
};

type NoticeEntry = {
  id: string;
  title: string;
  url: string;
};

type ClassifiedNotice = {
  category: string;
  severity: "informational" | "critical";
  confidence: number;
  autoPublish: boolean;
};

function normalizeText(
  value: string,
): string {
  return value
    .replace(/\s+/g, " ")
    .trim();
}

function searchableText(
  value: string,
): string {
  return normalizeText(
    value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, " "),
  );
}

function noticeId(
  value: string,
): string {
  return createHash("sha256")
    .update(value)
    .digest("hex")
    .slice(0, 32);
}

function hostFromUrl(
  value?: string,
): string | null {
  if (!value) {
    return null;
  }

  try {
    return new URL(value)
      .hostname
      .toLowerCase()
      .replace(/^www\./, "");
  } catch {
    return null;
  }
}

function sourceKind(
  source: OfficialSourceData,
): SourceKind {
  const host =
    hostFromUrl(source.url);

  switch (host) {
  case "jeemain.nta.nic.in":
    return "jeeMain";

  case "neet.nta.nic.in":
    return "neetUg";

  case "cuet.nta.nic.in":
    return "cuetUg";

  case "gate2027.iitm.ac.in":
    return "gate2027";

  default:
    return "unsupported";
  }
}

function isNtaKind(
  kind: SourceKind,
): boolean {
  return (
    kind === "jeeMain" ||
    kind === "neetUg" ||
    kind === "cuetUg"
  );
}

function sleep(
  milliseconds: number,
): Promise<void> {
  return new Promise(
    (resolve) => {
      setTimeout(
        resolve,
        milliseconds,
      );
    },
  );
}

async function fetchHtml(
  url: string,
): Promise<string> {
  const maximumAttempts = 3;

  let lastError: unknown;

  for (
    let attempt = 1;
    attempt <= maximumAttempts;
    attempt++
  ) {
    const controller =
      new AbortController();

    const timeout =
      setTimeout(
        () => {
          controller.abort();
        },
        25000,
      );

    try {
      const response =
        await fetch(
          url,
          {
            method: "GET",
            redirect: "follow",
            signal: controller.signal,
            headers: {
              "user-agent":
                "ExamReady-OfficialSourceMonitor/2.0",
            },
          },
        );

      if (!response.ok) {
        throw new Error(
          `HTTP ${response.status} while checking ${url}`,
        );
      }

      return await response.text();
    } catch (error) {
      lastError = error;

      if (
        attempt >= maximumAttempts
      ) {
        break;
      }

      console.warn(
        `Fetch attempt ${attempt}/${maximumAttempts} ` +
        `failed for ${url}. Retrying...`,
      );

      await sleep(
        attempt * 3000,
      );
    } finally {
      clearTimeout(
        timeout,
      );
    }
  }

  if (lastError instanceof Error) {
    throw lastError;
  }

  throw new Error(
    `Unable to fetch ${url}`,
  );
}
function isAllowedNtaDocumentUrl(
  target: URL,
  sourcePageUrl: string,
): boolean {
  const targetHost =
    target.hostname
      .toLowerCase()
      .replace(/^www\./, "");

  const sourceHost =
    hostFromUrl(sourcePageUrl);

  if (!sourceHost) {
    return false;
  }

  if (targetHost === sourceHost) {
    return true;
  }

  if (
    targetHost === "s3waas.gov.in" ||
    targetHost.endsWith(".s3waas.gov.in")
  ) {
    return true;
  }

  if (
    targetHost === "nta.ac.in" ||
    targetHost.endsWith(".nta.ac.in")
  ) {
    return true;
  }

  return false;
}

function extractNtaPublicNotices(
  html: string,
  pageUrl: string,
): NoticeEntry[] {
  const $ = cheerio.load(html);

  const results =
    new Map<string, NoticeEntry>();

  const addNotice = (
    rawTitle: string,
    rawUrl?: string,
  ): void => {
    const title =
      normalizeText(rawTitle);

    if (title.length < 8) {
      return;
    }

    let noticeUrl =
      pageUrl;

    if (rawUrl) {
      try {
        const target =
          new URL(
            rawUrl,
            pageUrl,
          );

        if (
          !isAllowedNtaDocumentUrl(
            target,
            pageUrl,
          )
        ) {
          return;
        }

        noticeUrl =
          target.toString();
      } catch {
        return;
      }
    }

    const identity =
      noticeUrl === pageUrl ?
        `${pageUrl}|${title}` :
        noticeUrl;

    const id =
      noticeId(identity);

    results.set(
      id,
      {
        id,
        title,
        url: noticeUrl,
      },
    );
  };

  $("table tr").each(
    (_, row) => {
      const cells =
        $(row).find("td");

      if (cells.length === 0) {
        return;
      }

      const title =
        normalizeText(
          $(cells[0]).text(),
        );

      let selectedUrl:
        string | undefined;

      $(row)
        .find("a[href]")
        .each(
          (_, link) => {
            if (selectedUrl) {
              return;
            }

            const href =
              $(link).attr("href");

            if (!href) {
              return;
            }

            try {
              const target =
                new URL(
                  href,
                  pageUrl,
                );

              if (
                isAllowedNtaDocumentUrl(
                  target,
                  pageUrl,
                )
              ) {
                selectedUrl =
                  target.toString();
              }
            } catch {
              // Ignore malformed links.
            }
          },
        );

      addNotice(
        title,
        selectedUrl,
      );
    },
  );

  if (results.size > 0) {
    return [...results.values()];
  }

  /*
   * Fallback for NTA pages whose current HTML
   * does not expose notices as table rows.
   */
  $("a[href]").each(
    (_, element) => {
      const href =
        $(element).attr("href");

      if (!href) {
        return;
      }

      let target: URL;

      try {
        target =
          new URL(
            href,
            pageUrl,
          );
      } catch {
        return;
      }

      if (
        !isAllowedNtaDocumentUrl(
          target,
          pageUrl,
        )
      ) {
        return;
      }

      const anchorText =
        normalizeText(
          $(element).text(),
        );

      const containerText =
        normalizeText(
          $(element)
            .closest(
              "li, article, tr, .document",
            )
            .text(),
        );

      const title =
        anchorText.length >= 12 ?
          anchorText :
          containerText;

      addNotice(
        title,
        target.toString(),
      );
    },
  );

  return [...results.values()];
}

function extractGateNotifications(
  html: string,
  pageUrl: string,
): NoticeEntry[] {
  const $ = cheerio.load(html);

  const results =
    new Map<string, NoticeEntry>();

  $("table tr").each(
    (_, row) => {
      const cells =
        $(row).find("td");

      if (cells.length < 2) {
        return;
      }

      const dateText =
        normalizeText(
          $(cells[0]).text(),
        );

      const activityParts:
        string[] = [];

      cells
        .slice(1)
        .each(
          (_, cell) => {
            const value =
              normalizeText(
                $(cell).text(),
              );

            if (value) {
              activityParts.push(
                value,
              );
            }
          },
        );

      const title =
        normalizeText(
          activityParts.join(" "),
        );

      if (!title) {
        return;
      }

      const identity =
        `${pageUrl}|${dateText}|${title}`;

      const id =
        noticeId(identity);

      results.set(
        id,
        {
          id,
          title,
          url: pageUrl,
        },
      );
    },
  );

  return [...results.values()];
}

function extractNotices(
  kind: SourceKind,
  html: string,
  pageUrl: string,
): NoticeEntry[] {
  if (isNtaKind(kind)) {
    return extractNtaPublicNotices(
      html,
      pageUrl,
    );
  }

  if (kind === "gate2027") {
    return extractGateNotifications(
      html,
      pageUrl,
    );
  }

  return [];
}

function cycleYear(
  cycleId: string,
): string | null {
  const match =
    cycleId.match(/(\d{4})$/);

  return match?.[1] ?? null;
}

function yearsInTitle(
  title: string,
): Set<string> {
  const matches =
    title.match(/\b20\d{2}\b/g) ??
    [];

  return new Set(matches);
}

function titleMatchesExactYear(
  title: string,
  expectedYear: string,
): boolean {
  const years =
    yearsInTitle(title);

  return (
    years.size === 1 &&
    years.has(expectedYear)
  );
}

function matchesExamIdentity(
  kind: SourceKind,
  title: string,
): boolean {
  const text =
    searchableText(title);

  switch (kind) {
  case "jeeMain":
    return (
      (
        text.includes("jee") &&
          text.includes("main")
      ) ||
        (
          text.includes(
            "joint entrance examination",
          ) &&
          text.includes("main")
        )
    );

  case "neetUg":
    return (
      text.includes("neet") ||
        text.includes(
          "national eligibility cum entrance test",
        )
    );

  case "cuetUg":
    return (
      text.includes("cuet") ||
        text.includes(
          "common university entrance test",
        )
    );

  case "gate2027":
    /*
       * GATE's notification page belongs only to
       * the GATE 2027 official IIT Madras site.
       * Individual activity rows often do not
       * repeat the words "GATE 2027".
       */
    return true;

  case "unsupported":
    return false;
  }
}

function gateSourceMatchesYear(
  source: OfficialSourceData,
  expectedYear: string,
): boolean {
  const host =
    hostFromUrl(source.url);

  if (!host) {
    return false;
  }

  const match =
    host.match(/^gate(\d{4})\.iitm\.ac\.in$/);

  if (!match) {
    return false;
  }

  return match[1] === expectedYear;
}

function noticeMatchesCycle(
  notice: NoticeEntry,
  cycleId: string,
  kind: SourceKind,
  source: OfficialSourceData,
): boolean {
  const year =
    cycleYear(cycleId);

  if (!year) {
    return false;
  }

  if (
    !matchesExamIdentity(
      kind,
      notice.title,
    )
  ) {
    return false;
  }

  if (kind === "gate2027") {
    if (
      !gateSourceMatchesYear(
        source,
        year,
      )
    ) {
      return false;
    }

    const titleYears =
      yearsInTitle(
        notice.title,
      );

    /*
     * A GATE activity may omit the year because
     * the entire official site is cycle-specific.
     * If a year IS written, however, it must
     * match the selected cycle exactly.
     */
    return (
      titleYears.size === 0 ||
      (
        titleYears.size === 1 &&
        titleYears.has(year)
      )
    );
  }

  /*
   * NTA sources are not cycle-specific URLs.
   * Their notice title must identify exactly
   * one year, and it must be our cycle year.
   */
  return titleMatchesExactYear(
    notice.title,
    year,
  );
}

function classifyNotice(
  notice: NoticeEntry,
): ClassifiedNotice {
  const title =
    searchableText(
      notice.title,
    );

  const hasAny = (
    values: string[],
  ): boolean => {
    return values.some(
      (value) =>
        title.includes(value),
    );
  };

  if (
    hasAny([
      "rescheduled",
      "rescheduling",
      "postponed",
      "postponement",
      "date changed",
      "dates changed",
      "revised schedule",
    ])
  ) {
    return {
      category: "scheduleChange",
      severity: "critical",
      confidence: 0.99,
      autoPublish: true,
    };
  }

  if (
    title.includes(
      "admit card",
    )
  ) {
    return {
      category: "admitCard",
      severity: "critical",
      confidence: 0.99,
      autoPublish: true,
    };
  }

  if (
    title.includes("result") &&
    hasAny([
      "declared",
      "declaration",
      "score",
      "scores",
      "announcement",
      "announced",
    ])
  ) {
    return {
      category: "result",
      severity: "critical",
      confidence: 0.99,
      autoPublish: true,
    };
  }

  if (
    title.includes(
      "answer key",
    )
  ) {
    return {
      category: "answerKey",
      severity: "informational",
      confidence: 0.98,
      autoPublish: true,
    };
  }

  if (
    hasAny([
      "examination city",
      "city intimation",
      "city allotment",
    ])
  ) {
    return {
      category:
        "examinationCityIntimation",
      severity: "critical",
      confidence: 0.98,
      autoPublish: true,
    };
  }

  if (
    title.includes("correction") &&
    hasAny([
      "window",
      "facility",
      "particulars",
      "application",
    ])
  ) {
    return {
      category: "correctionWindow",
      severity: "critical",
      confidence: 0.97,
      autoPublish: true,
    };
  }

  if (
    hasAny([
      "application",
      "registration",
    ]) &&
    hasAny([
      "extended",
      "extension",
      "deadline",
      "last date",
      "closing date",
      "closes",
    ])
  ) {
    return {
      category: "applicationDeadline",
      severity: "critical",
      confidence: 0.99,
      autoPublish: true,
    };
  }

  if (
    (
      title.includes("application") &&
      hasAny([
        "portal is live",
        "application portal",
        "inviting online application",
        "application form open",
      ])
    ) ||
    (
      title.includes("registration") &&
      hasAny([
        "open",
        "started",
        "commenced",
        "live",
      ])
    )
  ) {
    return {
      category: "applicationOpened",
      severity: "critical",
      confidence: 0.98,
      autoPublish: true,
    };
  }

  if (
    hasAny([
      "information bulletin",
      "information brochure",
    ]) &&
    hasAny([
      "released",
      "release",
      "revised",
      "updated",
    ])
  ) {
    return {
      category: "informationBulletin",
      severity: "informational",
      confidence: 0.98,
      autoPublish: true,
    };
  }

  if (
    title.includes("syllabus") &&
    hasAny([
      "released",
      "revised",
      "updated",
    ])
  ) {
    return {
      category: "syllabusUpdate",
      severity: "informational",
      confidence: 0.98,
      autoPublish: true,
    };
  }

  return {
    category: "other",
    severity: "informational",
    confidence: 0.50,
    autoPublish: false,
  };
}

const GATE_2027_CYCLE_ID =
  "gate-2027";

const GATE_2027_IMPORTANT_DATES_SOURCE =
  "gate-2027-important-dates";

const GATE_2027_ELIGIBILITY_SOURCE =
  "gate-2027-eligibility";

const GATE_2027_DOCUMENTS_SOURCE =
  "gate-2027-required-documents";

const GATE_2027_IMPORTANT_DATES_URL =
  "https://gate2027.iitm.ac.in/important_dates";

const GATE_2027_ELIGIBILITY_URL =
  "https://gate2027.iitm.ac.in/eligibility_criteria";

const GATE_2027_DOCUMENTS_URL =
  "https://gate2027.iitm.ac.in/required_documents";

const GATE_2027_FEES_SOURCE =
  "gate-2027-application-fees";

const GATE_2027_FEES_URL =
  "https://gate2027.iitm.ac.in/application_fees";

type ImportedImportantDate = {
  type: string;
  value: Date;
  sourceIds: string[];
  label: string;
};

type ImportedEligibility = {
  id: string;
  description: string;
  sourceIds: string[];
  conditionKey: null;
};

const gateMonthNumbers:
  Record<string, number> = {
    january: 0,
    february: 1,
    march: 2,
    april: 3,
    may: 4,
    june: 5,
    july: 6,
    august: 7,
    september: 8,
    october: 9,
    november: 10,
    december: 11,
  };

function datesFromOfficialText(
  value: string,
): Date[] {
  const cleaned =
    value.replace(
      /(\d+)(st|nd|rd|th)/gi,
      "$1",
    );

  const pattern =
    new RegExp(
      "\\b(\\d{1,2})\\s+" +
      "(January|February|March|April|May|June|" +
      "July|August|September|October|November|" +
      "December)\\s+" +
      "(20\\d{2})\\b",
      "gi",
    );

  const results: Date[] = [];

  let match:
    RegExpExecArray | null;

  while (
    (
      match =
        pattern.exec(cleaned)
    ) !== null
  ) {
    const day =
      Number(match[1]);

    const month =
      gateMonthNumbers[
        match[2].toLowerCase()
      ];

    const year =
      Number(match[3]);

    if (
      month === undefined ||
      day < 1 ||
      day > 31
    ) {
      continue;
    }

    results.push(
      new Date(
        Date.UTC(
          year,
          month,
          day,
        ),
      ),
    );
  }

  return results;
}

function gateDateType(
  activity: string,
): string {
  const text =
    searchableText(activity);

  if (
    text.includes("opening date") &&
    (
      text.includes("application") ||
      text.includes("goaps")
    )
  ) {
    return "applicationStart";
  }

  if (
    text.includes("closing date") &&
    text.includes("registration")
  ) {
    return "applicationDeadline";
  }

  if (
    text.includes("opening date") &&
    (
      text.includes("rectification") ||
      text.includes("correction")
    )
  ) {
    return "correctionWindowStart";
  }

  if (
    text.includes("closing date") &&
    (
      text.includes("rectification") ||
      text.includes("correction")
    )
  ) {
    return "correctionWindowEnd";
  }

  if (
    text.includes("admit card")
  ) {
    return "admitCardRelease";
  }

  if (
    text.includes("examination")
  ) {
    return "examination";
  }

  if (
    text.includes("result")
  ) {
    return "resultRelease";
  }

  return "other";
}

function parseGateImportantDates(
  html: string,
): ImportedImportantDate[] {
  const $ =
    cheerio.load(html);

  const results:
    ImportedImportantDate[] = [];

  const seen =
    new Set<string>();

  let currentActivity = "";

  const addDates = (
    activity: string,
    dateText: string,
  ): void => {
    if (!activity) {
      return;
    }

    const dates =
      datesFromOfficialText(
        dateText,
      );

    const type =
      gateDateType(
        activity,
      );

    for (
      const date
      of dates
    ) {
      const identity =
        `${type}|` +
        `${date.toISOString()}|` +
        activity;

      if (
        seen.has(identity)
      ) {
        continue;
      }

      seen.add(identity);

      results.push({
        type,
        value: date,
        sourceIds: [
          GATE_2027_IMPORTANT_DATES_SOURCE,
        ],
        label: activity,
      });
    }
  };

  $("table tr").each(
    (_, row) => {
      const cells =
        $(row).find("td");

      if (
        cells.length === 0
      ) {
        return;
      }

      const cleanedCells =
        cells
          .map(
            (_, cell) => {
              const clone =
                $(cell).clone();

              clone
                .find(
                  "s, del, strike, " +
                  "[style*=\"line-through\"]",
                )
                .remove();

              return normalizeText(
                clone.text(),
              );
            },
          )
          .get();

      if (
        cleanedCells.length >= 3
      ) {
        const activity =
          cleanedCells[0];

        const dateText =
          cleanedCells[1];

        if (activity) {
          currentActivity =
            activity;
        }

        addDates(
          currentActivity,
          dateText,
        );

        return;
      }

      if (
        cleanedCells.length === 2
      ) {
        const first =
          cleanedCells[0];

        const second =
          cleanedCells[1];

        const firstDates =
          datesFromOfficialText(
            first,
          );

        /*
         * GATE's examination schedule uses
         * continuation rows:
         *
         * GATE 2027 Examinations | 6, 7 Feb | ...
         *                         | 13,14 Feb | ...
         *                         | 20,21 Feb | ...
         *
         * In those continuation rows the first
         * cell is another date block, not a new
         * activity name.
         */
        if (
          currentActivity &&
          firstDates.length > 0
        ) {
          addDates(
            currentActivity,
            first,
          );

          return;
        }

        if (first) {
          currentActivity =
            first;
        }

        addDates(
          currentActivity,
          second,
        );
      }
    },
  );

  return results;
}
function parseGateFees(
  html: string,
): Array<Record<string, unknown>> {
  const $ =
    cheerio.load(html);

  const results:
    Array<Record<string, unknown>> = [];

  $("table tbody tr").each(
    (_, row) => {
      const cells =
        $(row).find("td");

      if (
        cells.length < 5
      ) {
        return;
      }

      const category =
        normalizeText(
          $(cells[0]).text(),
        );

      const regularOnePaper =
        Number(
          normalizeText(
            $(cells[1]).text(),
          ).replace(
            /[^0-9]/g,
            "",
          ),
        );

      const regularTwoPaper =
        Number(
          normalizeText(
            $(cells[2]).text(),
          ).replace(
            /[^0-9]/g,
            "",
          ),
        );

      const extendedOnePaper =
        Number(
          normalizeText(
            $(cells[3]).text(),
          ).replace(
            /[^0-9]/g,
            "",
          ),
        );

      const extendedTwoPaper =
        Number(
          normalizeText(
            $(cells[4]).text(),
          ).replace(
            /[^0-9]/g,
            "",
          ),
        );

      const amounts = [
        regularOnePaper,
        regularTwoPaper,
        extendedOnePaper,
        extendedTwoPaper,
      ];

      if (
        !category ||
        amounts.some(
          (amount) =>
            !Number.isFinite(amount) ||
            amount <= 0,
        )
      ) {
        return;
      }

      results.push(
        {
          label:
            "Regular registration fee - One paper",

          amountInr:
            regularOnePaper,

          sourceIds: [
            GATE_2027_FEES_SOURCE,
          ],

          categoryLabel:
            category,
        },
        {
          label:
            "Regular registration fee - Two papers",

          amountInr:
            regularTwoPaper,

          sourceIds: [
            GATE_2027_FEES_SOURCE,
          ],

          categoryLabel:
            category,
        },
        {
          label:
            "Extended registration fee - One paper",

          amountInr:
            extendedOnePaper,

          sourceIds: [
            GATE_2027_FEES_SOURCE,
          ],

          categoryLabel:
            category,
        },
        {
          label:
            "Extended registration fee - Two papers",

          amountInr:
            extendedTwoPaper,

          sourceIds: [
            GATE_2027_FEES_SOURCE,
          ],

          categoryLabel:
            category,
        },
      );
    },
  );

  return results;
}
function parseGateEligibility(
  html: string,
): ImportedEligibility[] {
  const $ =
    cheerio.load(html);

  const results:
    ImportedEligibility[] = [];

  const descriptions =
    new Set<string>();

  $("p").each(
    (_, paragraph) => {
      const text =
        normalizeText(
          $(paragraph).text(),
        );

      const lower =
        text.toLowerCase();

      if (
        lower.includes(
          "candidates who are currently studying",
        ) &&
        lower.includes(
          "eligible to appear",
        )
      ) {
        descriptions.add(text);
      }
    },
  );

  $("table tr").each(
    (_, row) => {
      const cells =
        $(row).find("td");

      if (
        cells.length < 2
      ) {
        return;
      }

      const values =
        cells
          .map(
            (_, cell) =>
              normalizeText(
                $(cell).text(),
              ),
          )
          .get()
          .filter(
            (value) =>
              value.length > 0,
          );

      if (
        values.length < 2
      ) {
        return;
      }

      const first =
        values[0]
          .toLowerCase();

      if (
        first.includes(
          "qualifying degree",
        )
      ) {
        return;
      }

      const description =
        normalizeText(
          values.join(
            " ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ",
          ),
        );

      if (
        description.length >= 15
      ) {
        descriptions.add(
          description,
        );
      }
    },
  );

  for (
    const description
    of descriptions
  ) {
    results.push({
      id:
        "gate-2027-eligibility-" +
        noticeId(
          description,
        ).slice(
          0,
          16,
        ),

      description,

      sourceIds: [
        GATE_2027_ELIGIBILITY_SOURCE,
      ],

      conditionKey: null,
    });
  }

  return results;
}

function parseGateDocumentLabels(
  html: string,
): string[] {
  const $ =
    cheerio.load(html);

  const headings =
    $(
      "h1, h2, h3, h4, h5, h6",
    );

  const heading =
    headings
      .filter(
        (_, element) => {
          const text =
            normalizeText(
              $(element).text(),
            ).toLowerCase();

          return (
            text ===
            "documents required"
          );
        },
      )
      .first();

  if (
    heading.length === 0
  ) {
    return [];
  }

  const results =
    new Set<string>();

  let current =
    heading.next();

  while (
    current.length > 0
  ) {
    if (
      current.is(
        "h1, h2, h3, h4, h5, h6",
      )
    ) {
      break;
    }

    const lists =
      current.is(
        "ul, ol",
      ) ?
        current :
        current.find(
          "ul, ol",
        ).first();

    lists
      .children("li")
      .each(
        (_, item) => {
          const clone =
            $(item).clone();

          clone
            .find(
              "ul, ol",
            )
            .remove();

          const label =
            normalizeText(
              clone.text(),
            );

          if (
            label.length >= 8
          ) {
            results.add(
              label,
            );
          }
        },
      );

    current =
      current.next();
  }

  return [
    ...results,
  ];
}

async function ensureGate2027Sources():
  Promise<void> {
  const sources = [
    {
      id:
        GATE_2027_IMPORTANT_DATES_SOURCE,

      name:
        "GATE 2027 Official Important Dates",

      url:
        GATE_2027_IMPORTANT_DATES_URL,
    },
    {
      id:
        GATE_2027_ELIGIBILITY_SOURCE,

      name:
        "GATE 2027 Official Eligibility",

      url:
        GATE_2027_ELIGIBILITY_URL,
    },
    {
      id:
        GATE_2027_DOCUMENTS_SOURCE,

      name:
        "GATE 2027 Official Required Documents",

      url:
        GATE_2027_DOCUMENTS_URL,
    },
    {
      id:
        GATE_2027_FEES_SOURCE,

      name:
        "GATE 2027 Official Application Fees",

      url:
        GATE_2027_FEES_URL,
    },
  ];

  for (
    const source
    of sources
  ) {
    await db
      .collection(
        "officialSources",
      )
      .doc(
        source.id,
      )
      .set(
        {
          name:
            source.name,

          url:
            source.url,

          type:
            "website",

          enabled:
            true,

          cycleIds: [
            GATE_2027_CYCLE_ID,
          ],

          status:
            "verified",

          processingStatus:
            "processed",

          confidence:
            1.0,

          lastCheckedAt:
            FieldValue
              .serverTimestamp(),

          lastVerifiedAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );
  }
}

async function syncGateChecklist(
  labels: string[],
): Promise<string[]> {
  const managedBy =
    "gate2027OfficialSync";

  const ids =
    labels.map(
      (label) =>
        "gate-2027-document-" +
        noticeId(
          label,
        ).slice(
          0,
          16,
        ),
    );

  const activeIds =
    new Set(ids);

  for (
    let index = 0;
    index < labels.length;
    index++
  ) {
    await db
      .collection(
        "checklistRequirements",
      )
      .doc(
        ids[index],
      )
      .set(
        {
          cycleId:
            GATE_2027_CYCLE_ID,

          label:
            labels[index],

          conditionKey:
            null,

          sourceIds: [
            GATE_2027_DOCUMENTS_SOURCE,
          ],

          managedBy,

          updatedAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );
  }

  const existing =
    await db
      .collection(
        "checklistRequirements",
      )
      .where(
        "cycleId",
        "==",
        GATE_2027_CYCLE_ID,
      )
      .get();

  for (
    const document
    of existing.docs
  ) {
    const data =
      document.data();

    if (
      data.managedBy === managedBy &&
      !activeIds.has(
        document.id,
      )
    ) {
      await document.ref.delete();
    }
  }

  return ids;
}

async function syncGate2027Information():
  Promise<void> {
  console.log(
    "Syncing structured GATE 2027 information.",
  );

  const [
    importantDatesHtml,
    eligibilityHtml,
    documentsHtml,
    feesHtml,
  ] =
    await Promise.all([
      fetchHtml(
        GATE_2027_IMPORTANT_DATES_URL,
      ),

      fetchHtml(
        GATE_2027_ELIGIBILITY_URL,
      ),

      fetchHtml(
        GATE_2027_DOCUMENTS_URL,
      ),

      fetchHtml(
        GATE_2027_FEES_URL,
      ),
    ]);

  const importantDates =
    parseGateImportantDates(
      importantDatesHtml,
    );

  const eligibility =
    parseGateEligibility(
      eligibilityHtml,
    );

  const documentLabels =
    parseGateDocumentLabels(
      documentsHtml,
    );

  const fees =
    parseGateFees(
      feesHtml,
    );

  /*
   * Fail closed.
   * Never erase good Firestore data because an
   * official site's HTML structure temporarily
   * changed.
   */
  if (
    importantDates.length < 13
  ) {
    throw new Error(
      "GATE date parser returned too few dates: " +
      importantDates.length,
    );
  }

  if (
    eligibility.length < 2
  ) {
    throw new Error(
      "GATE eligibility parser returned too few items: " +
      eligibility.length,
    );
  }

  if (
    documentLabels.length < 2
  ) {
    throw new Error(
      "GATE document parser returned too few items: " +
      documentLabels.length,
    );
  }

  if (
    fees.length !== 8
  ) {
    throw new Error(
      "GATE fee parser returned unexpected item count: " +
      fees.length,
    );
  }

  await ensureGate2027Sources();

  const documentRequirementIds =
    await syncGateChecklist(
      documentLabels,
    );

  await db
    .collection(
      "examinationInformation",
    )
    .doc(
      GATE_2027_CYCLE_ID,
    )
    .set(
      {
        importantDates,

        fees,

        eligibility,

        documentRequirementIds,

        informationStatus:
          "verified",

        informationSourceIds: [
          GATE_2027_IMPORTANT_DATES_SOURCE,
          GATE_2027_ELIGIBILITY_SOURCE,
          GATE_2027_DOCUMENTS_SOURCE,
          GATE_2027_FEES_SOURCE,
        ],

        lastInformationSyncAt:
          FieldValue
            .serverTimestamp(),
      },
      {
        merge: true,
      },
    );

  console.log(
    "GATE 2027 information synced: " +
    `${importantDates.length} date(s), ` +
    `${fees.length} fee item(s), ` +
    `${eligibility.length} eligibility item(s), ` +
    `${documentRequirementIds.length} document item(s).`,
  );
}
async function publishVerifiedNotice(
  sourceDocument:
    QueryDocumentSnapshot,
  source: OfficialSourceData,
  notice: NoticeEntry,
  cycleId: string,
  classification: ClassifiedNotice,
  kind: SourceKind,
): Promise<void> {
  const updateId =
    `${sourceDocument.id}_${notice.id}`;

  const updateRef =
    db
      .collection(
        "examinationUpdates",
      )
      .doc(updateId);

  const existing =
    await updateRef.get();

  if (existing.exists) {
    return;
  }

  await updateRef.set({
    cycleId,
    title: notice.title,

    body:
      "A new verified official notice is available. " +
      "Open ExamReady to view the official source.",

    category:
      classification.category,

    severity:
      classification.severity,

    confidence:
      classification.confidence,

    verificationStatus:
      "verified",

    sourceIds: [
      sourceDocument.id,
    ],

    sourceName:
      source.name ??
      sourceDocument.id,

    sourceUrl:
      source.url,

    noticeUrl:
      notice.url,

    sourceKind:
      kind,

    detectedAt:
      FieldValue.serverTimestamp(),

    publishedAt:
      FieldValue.serverTimestamp(),

    publishedAutomatically:
      true,

    verificationMethod:
      "officialSourceExamIdentityCycleAndKnownNoticeType",
  });

  console.log(
    `Auto-published verified update: ${notice.title}`,
  );
}

async function baselineSource(
  sourceDocument:
    QueryDocumentSnapshot,
  notices: NoticeEntry[],
): Promise<void> {
  const seenCollection =
    sourceDocument.ref.collection(
      "seenNotices",
    );

  for (const notice of notices) {
    await seenCollection
      .doc(notice.id)
      .set(
        {
          title:
            notice.title,

          url:
            notice.url,

          firstSeenAt:
            FieldValue
              .serverTimestamp(),

          baseline: true,

          monitorSchemaVersion:
            MONITOR_SCHEMA_VERSION,
        },
        {
          merge: true,
        },
      );
  }

  await sourceDocument.ref.set(
    {
      monitorSchemaVersion:
        MONITOR_SCHEMA_VERSION,

      lastCheckedAt:
        FieldValue.serverTimestamp(),

      status:
        "verified",

      processingStatus:
        "processed",

      noticeCount:
        notices.length,
    },
    {
      merge: true,
    },
  );

  console.log(
    `${sourceDocument.id}: baseline refreshed ` +
    `with ${notices.length} notice(s).`,
  );
}

async function monitorNoticeSource(
  sourceDocument:
    QueryDocumentSnapshot,
  source: OfficialSourceData,
  kind: SourceKind,
): Promise<void> {
  if (!source.url) {
    throw new Error(
      `${sourceDocument.id} has no URL.`,
    );
  }

  const html =
    await fetchHtml(
      source.url,
    );

  const notices =
    extractNotices(
      kind,
      html,
      source.url,
    );

  if (
    source.monitorSchemaVersion !==
    MONITOR_SCHEMA_VERSION
  ) {
    await baselineSource(
      sourceDocument,
      notices,
    );

    return;
  }

  const seenCollection =
    sourceDocument.ref.collection(
      "seenNotices",
    );

  const seenSnapshot =
    await seenCollection.get();

  const seenIds =
    new Set(
      seenSnapshot.docs.map(
        (document) =>
          document.id,
      ),
    );

  let relevantCount = 0;
  let autoPublishedCount = 0;
  let reviewCount = 0;

  for (const notice of notices) {
    if (
      seenIds.has(
        notice.id,
      )
    ) {
      continue;
    }

    await seenCollection
      .doc(notice.id)
      .set({
        title:
          notice.title,

        url:
          notice.url,

        firstSeenAt:
          FieldValue
            .serverTimestamp(),

        baseline: false,

        monitorSchemaVersion:
          MONITOR_SCHEMA_VERSION,
      });

    const matchedCycleIds =
      (source.cycleIds ?? [])
        .filter(
          (cycleId) =>
            noticeMatchesCycle(
              notice,
              cycleId,
              kind,
              source,
            ),
        );

    if (
      matchedCycleIds.length === 0
    ) {
      console.log(
        "Ignoring notice that does not match " +
        `this exam/cycle: ${notice.title}`,
      );

      continue;
    }

    relevantCount++;

    const classification =
      classifyNotice(
        notice,
      );

    const detectionId =
      `${sourceDocument.id}_${notice.id}`;

    const detectionRef =
      db
        .collection(
          "sourceDetections",
        )
        .doc(detectionId);

    if (
      classification.autoPublish &&
      classification.confidence >= 0.97
    ) {
      for (
        const cycleId
        of matchedCycleIds
      ) {
        await publishVerifiedNotice(
          sourceDocument,
          source,
          notice,
          cycleId,
          classification,
          kind,
        );
      }

      await detectionRef.set(
        {
          sourceId:
            sourceDocument.id,

          sourceName:
            source.name ??
            sourceDocument.id,

          sourceUrl:
            source.url,

          sourceKind:
            kind,

          noticeTitle:
            notice.title,

          noticeUrl:
            notice.url,

          cycleIds:
            matchedCycleIds,

          detectedAt:
            FieldValue
              .serverTimestamp(),

          verificationStatus:
            "verified",

          processingStatus:
            "processed",

          confidence:
            classification
              .confidence,

          category:
            classification
              .category,

          autoPublished:
            true,

          verificationMethod:
            "officialSourceExamIdentityCycleAndKnownNoticeType",
        },
        {
          merge: true,
        },
      );

      autoPublishedCount++;

      continue;
    }

    await detectionRef.set(
      {
        sourceId:
          sourceDocument.id,

        sourceName:
          source.name ??
          sourceDocument.id,

        sourceUrl:
          source.url,

        sourceKind:
          kind,

        noticeTitle:
          notice.title,

        noticeUrl:
          notice.url,

        cycleIds:
          matchedCycleIds,

        detectedAt:
          FieldValue
            .serverTimestamp(),

        verificationStatus:
          "pendingVerification",

        processingStatus:
          "needsReview",

        confidence:
          classification.confidence,

        category:
          classification.category,

        autoPublished:
          false,
      },
      {
        merge: true,
      },
    );

    reviewCount++;

    console.log(
      `Held for review: ${notice.title}`,
    );
  }

  await sourceDocument.ref.set(
    {
      lastCheckedAt:
        FieldValue.serverTimestamp(),

      status:
        "verified",

      processingStatus:
        "processed",

      noticeCount:
        notices.length,

      monitorSchemaVersion:
        MONITOR_SCHEMA_VERSION,
    },
    {
      merge: true,
    },
  );

  console.log(
    `${sourceDocument.id}: ` +
    `${notices.length} notices, ` +
    `${relevantCount} new relevant, ` +
    `${autoPublishedCount} auto-published, ` +
    `${reviewCount} held for review.`,
  );
}

async function markUnsupportedSource(
  sourceDocument:
    QueryDocumentSnapshot,
): Promise<void> {
  await sourceDocument.ref.set(
    {
      lastCheckedAt:
        FieldValue.serverTimestamp(),

      status:
        "pendingVerification",

      processingStatus:
        "needsReview",
    },
    {
      merge: true,
    },
  );

  console.log(
    `${sourceDocument.id}: automatic parser not configured.`,
  );
}

async function monitorOfficialSources():
  Promise<void> {
  const sources =
    await db
      .collection(
        "officialSources",
      )
      .where(
        "enabled",
        "==",
        true,
      )
      .get();

  console.log(
    `Checking ${sources.size} official source(s).`,
  );

  for (
    const sourceDocument
    of sources.docs
  ) {
    const source =
      sourceDocument
        .data() as OfficialSourceData;

    try {
      if (
        source.type ===
        "notification"
      ) {
        const kind =
          sourceKind(
            source,
          );

        if (
          kind === "unsupported"
        ) {
          await markUnsupportedSource(
            sourceDocument,
          );

          continue;
        }

        await monitorNoticeSource(
          sourceDocument,
          source,
          kind,
        );
      } else {
        /*
         * Website-type sources are provenance/source
         * records. They are not treated as notice feeds.
         */
        await sourceDocument.ref.set(
          {
            lastCheckedAt:
              FieldValue
                .serverTimestamp(),

            status:
              "verified",

            processingStatus:
              "processed",
          },
          {
            merge: true,
          },
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
            FieldValue
              .serverTimestamp(),

          status:
            "sourceUnavailable",

          processingStatus:
            "failed",
        },
        {
          merge: true,
        },
      );
    }
  }
}

async function notifyVerifiedUpdates():
  Promise<void> {
  const updates =
    await db
      .collection(
        "examinationUpdates",
      )
      .where(
        "verificationStatus",
        "==",
        "verified",
      )
      .limit(100)
      .get();

  for (
    const updateDocument
    of updates.docs
  ) {
    const update =
      updateDocument.data();

    if (
      !update.publishedAt ||
      update.notificationSentAt
    ) {
      continue;
    }

    const cycleId =
      update.cycleId as
        | string
        | undefined;

    const title =
      update.title as
        | string
        | undefined;

    if (
      !cycleId ||
      !title
    ) {
      continue;
    }

    const users =
      await db
        .collection(
          "users",
        )
        .get();

    const tokens =
      new Set<string>();

    for (
      const user
      of users.docs
    ) {
      const selectedExam =
        await user.ref
          .collection(
            "examinations",
          )
          .doc(cycleId)
          .get();

      if (
        !selectedExam.exists
      ) {
        continue;
      }

      const preferences =
        await user.ref
          .collection(
            "settings",
          )
          .doc(
            "notifications",
          )
          .get();

      if (
        preferences
          .data()
          ?.officialUpdatesEnabled ===
        false
      ) {
        continue;
      }

      const tokenDocuments =
        await user.ref
          .collection(
            "fcmTokens",
          )
          .get();

      for (
        const tokenDocument
        of tokenDocuments.docs
      ) {
        const token =
          tokenDocument
            .data()
            .token as
              | string
              | undefined;

        if (token) {
          tokens.add(
            token,
          );
        }
      }
    }

    const allTokens =
      [...tokens];

    const body =
      typeof update.body ===
        "string" &&
      update.body
        .trim()
        .length > 0 ?
        update.body :
        "A verified official exam update is available.";

    for (
      let index = 0;
      index < allTokens.length;
      index += 500
    ) {
      const batch =
        allTokens.slice(
          index,
          index + 500,
        );

      if (
        batch.length === 0
      ) {
        continue;
      }

      await messaging
        .sendEachForMulticast({
          tokens:
            batch,

          notification: {
            title,
            body,
          },

          data: {
            type:
              "examinationUpdate",

            updateId:
              updateDocument.id,

            cycleId,
          },

          android: {
            priority:
              "high",

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
          FieldValue
            .serverTimestamp(),

        notificationRecipientCount:
          allTokens.length,
      },
      {
        merge: true,
      },
    );

    console.log(
      `Processed ${updateDocument.id}: ` +
      `${allTokens.length} recipient(s).`,
    );
  }
}

async function main():
  Promise<void> {
  console.log(
    "ExamReady automation started.",
  );

  await monitorOfficialSources();

  await syncGate2027Information();

  await notifyVerifiedUpdates();

  console.log(
    "ExamReady automation finished.",
  );
}

main().catch(
  (error) => {
    console.error(
      "ExamReady automation failed:",
      error,
    );

    process.exitCode = 1;
  },
);
