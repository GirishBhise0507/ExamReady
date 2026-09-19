/* eslint-disable require-jsdoc */

import {
  applicationDefault,
  getApps,
  initializeApp,
} from "firebase-admin/app";

import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

if (getApps().length === 0) {
  initializeApp({
    credential: applicationDefault(),
  });
}

const db = getFirestore();

interface SourceSeed {
  id: string;
  name: string;
  url: string;
  type: "website" | "notification";
  cycleIds: string[];
}

async function upsert(
  path: string,
  data: Record<string, unknown>,
): Promise<void> {
  await db.doc(path).set(
    data,
    {
      merge: true,
    },
  );

  console.log(`Upserted: ${path}`);
}

async function createInformationIfMissing(
  cycleId: string,
): Promise<void> {
  const reference =
    db.collection("examinationInformation").doc(cycleId);

  const snapshot = await reference.get();

  if (snapshot.exists) {
    console.log(
      `Kept existing information: ${cycleId}`,
    );
    return;
  }

  await reference.set({
    importantDates: [],
    fees: [],
    eligibility: [],
    documentRequirementIds: [],
    examDayInstructionIds: [],
  });

  console.log(
    `Created empty information: ${cycleId}`,
  );
}

async function upsertSource(
  source: SourceSeed,
): Promise<void> {
  const reference =
    db.collection("officialSources").doc(source.id);

  const snapshot = await reference.get();

  const staticData = {
    name: source.name,
    url: source.url,
    type: source.type,
    enabled: true,
    cycleIds: source.cycleIds,
  };

  if (snapshot.exists) {
    await reference.set(
      staticData,
      {
        merge: true,
      },
    );

    console.log(
      `Updated source metadata: ${source.id}`,
    );

    return;
  }

  await reference.set({
    ...staticData,
    status: "verified",
    processingStatus: "notProcessed",
    confidence: 1.0,
    lastVerifiedAt:
      FieldValue.serverTimestamp(),
  });

  console.log(
    `Created official source: ${source.id}`,
  );
}

async function seedCatalog(): Promise<void> {
  console.log(
    "ExamReady catalog seed started.",
  );

  // --------------------------------------------------------
  // CATEGORIES
  // --------------------------------------------------------

  await upsert(
    "examinationCategories/engineering",
    {
      name: "Engineering Entrance Exams",
    },
  );

  await upsert(
    "examinationCategories/medical",
    {
      name: "Medical Entrance Exams",
    },
  );

  await upsert(
    "examinationCategories/university",
    {
      name: "University Entrance Exams",
    },
  );

  await upsert(
    "examinationCategories/civil-services",
    {
      name: "Civil Services Examinations",
    },
  );

  // --------------------------------------------------------
  // EXAMINATIONS
  // --------------------------------------------------------

  await upsert(
    "examinations/neet-ug",
    {
      categoryId: "medical",
      name: "NEET UG",
      aliases: [
        "NEET",
        "NEET UG",
        "National Eligibility cum Entrance Test",
      ],
    },
  );

  await upsert(
    "examinations/cuet-ug",
    {
      categoryId: "university",
      name: "CUET UG",
      aliases: [
        "CUET",
        "CUET UG",
        "Common University Entrance Test",
      ],
    },
  );

  await upsert(
    "examinations/gate",
    {
      categoryId: "engineering",
      name: "GATE",
      aliases: [
        "GATE",
        "Graduate Aptitude Test in Engineering",
      ],
    },
  );

  await upsert(
    "examinations/upsc-cse",
    {
      categoryId: "civil-services",
      name: "UPSC Civil Services Examination",
      aliases: [
        "UPSC CSE",
        "Civil Services Examination",
        "CSE",
        "IAS Exam",
      ],
    },
  );

  // --------------------------------------------------------
  // 2027 CYCLES
  // --------------------------------------------------------

  await upsert(
    "examinationCycles/neet-ug-2027",
    {
      examinationId: "neet-ug",
      label: "NEET UG 2027",
      year: 2027,
    },
  );

  await upsert(
    "examinationCycles/cuet-ug-2027",
    {
      examinationId: "cuet-ug",
      label: "CUET UG 2027",
      year: 2027,
    },
  );

  await upsert(
    "examinationCycles/gate-2027",
    {
      examinationId: "gate",
      label: "GATE 2027",
      year: 2027,
    },
  );

  await upsert(
    "examinationCycles/upsc-cse-2027",
    {
      examinationId: "upsc-cse",
      label: "UPSC Civil Services 2027",
      year: 2027,
    },
  );

  // --------------------------------------------------------
  // EMPTY INFORMATION DOCUMENTS
  //
  // We deliberately do NOT invent dates, fees, eligibility,
  // documents, or instructions.
  // Existing information is never overwritten.
  // --------------------------------------------------------

  await createInformationIfMissing(
    "neet-ug-2027",
  );

  await createInformationIfMissing(
    "cuet-ug-2027",
  );

  await createInformationIfMissing(
    "gate-2027",
  );

  await createInformationIfMissing(
    "upsc-cse-2027",
  );

  // --------------------------------------------------------
  // VERIFIED OFFICIAL SOURCES
  // --------------------------------------------------------

  const sources: SourceSeed[] = [
    {
      id: "neet-ug-official",
      name: "NEET UG Official Website",
      url: "https://neet.nta.nic.in/",
      type: "website",
      cycleIds: [
        "neet-ug-2027",
      ],
    },
    {
      id: "neet-ug-public-notices",
      name: "NEET UG Official Public Notices",
      url:
        "https://neet.nta.nic.in/" +
        "document-category/public-notices/",
      type: "notification",
      cycleIds: [
        "neet-ug-2027",
      ],
    },
    {
      id: "cuet-ug-official",
      name: "CUET UG Official Website",
      url: "https://cuet.nta.nic.in/",
      type: "website",
      cycleIds: [
        "cuet-ug-2027",
      ],
    },
    {
      id: "cuet-ug-public-notices",
      name: "CUET UG Official Public Notices",
      url:
        "https://cuet.nta.nic.in/" +
        "document-category/public-notice/",
      type: "notification",
      cycleIds: [
        "cuet-ug-2027",
      ],
    },
    {
      id: "gate-2027-official",
      name: "GATE 2027 Official Website",
      url: "https://gate2027.iitm.ac.in/",
      type: "website",
      cycleIds: [
        "gate-2027",
      ],
    },
    {
      id: "gate-2027-notifications",
      name: "GATE 2027 Official Notifications",
      url:
        "https://gate2027.iitm.ac.in/notifications",
      type: "notification",
      cycleIds: [
        "gate-2027",
      ],
    },
    {
      id: "upsc-official",
      name: "UPSC Official Website",
      url: "https://www.upsc.gov.in/",
      type: "website",
      cycleIds: [
        "upsc-cse-2027",
      ],
    },
    {
      id: "upsc-active-exams",
      name: "UPSC Active Examinations",
      url:
        "https://www.upsc.gov.in/" +
        "examinations/active-exams",
      type: "website",
      cycleIds: [
        "upsc-cse-2027",
      ],
    },
  ];

  for (const source of sources) {
    await upsertSource(source);
  }

  console.log(
    "ExamReady catalog seed finished.",
  );
}

seedCatalog().catch((error: unknown) => {
  console.error(
    "Catalog seed failed:",
    error,
  );

  process.exitCode = 1;
});
