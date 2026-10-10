#!/usr/bin/env node
/**
 * CampusFix dev/demo seeder (MVP, Spark/free).
 *
 * Runs LOCALLY with the Firebase Admin SDK - it is NOT a deployed Cloud Function.
 * It provisions Auth users + custom claims and loads Firestore from `seed.json`
 * (produced by `packages/campusfix_core/tool/export_seed.dart`). Idempotent:
 * re-running upserts the same users / documents.
 *
 *   cd backend/seed && npm install
 *
 *   # Against the local emulators (no credentials needed):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
 *   FIREBASE_PROJECT_ID=demo-campusfix ALIAS_DOMAIN=id.campusfix.test node seed.mjs
 *
 *   # Against the personal dev project (service-account key; see backend/README.md):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/dev-sa-key.json \
 *   ALIAS_DOMAIN=id.campusfix.test node seed.mjs --yes
 *
 *   # Validate seed.json and print the plan without touching Firebase (no install needed):
 *   node seed.mjs --dry-run
 *
 * Environment
 *   GOOGLE_APPLICATION_CREDENTIALS  service-account key (real project only; never committed)
 *   FIREBASE_PROJECT_ID             project id (optional for a real project: read from the key;
 *                                   defaults to demo-campusfix on the emulators)
 *   FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST   target the emulators (set BOTH)
 *   ALIAS_DOMAIN                    domain of the synthetic alias e-mails (default id.campusfix.test);
 *                                   must equal the apps' --dart-define=CF_ALIAS_DOMAIN
 *   SEED_PASSWORD                   password given to every seeded user (default campusfix-demo)
 *   SEED_FILE                       path to the seed (default ./seed.json)
 *   CF_ENV                          refuses to run when "prod" (demo data never goes to production)
 *
 * Flags
 *   --dry-run   validate + print the plan; no network, no Firebase SDK needed
 *   --yes       required to write to a real (non-emulator) project
 *
 * Firestore layout written (docs/phase-2-firebase-plan.md section 5, MVP):
 *   users/{uid}                                  profile (role/department also set as custom CLAIMS)
 *   complaints/{id}                              PUBLIC doc  = seed `public` + { version: 1, claimed }
 *   complaints/{id}/private/admin                seed `admin`
 *   complaints/{id}/private/identity             seed `identity`
 *   userComplaints/{reporterUid}/items/{id}      ownership index
 *   staffClaims/{assigneeUid}/items/{id}         claim index (only when an assignee is named)
 *   notifications/{id}                           seed notifications (ids already ntf-<eventId>-<recipientId>)
 *   counters/complaintIds-{year}                 { last } from lastSequenceByYear
 *
 * Dates: seed.json carries ISO-8601 strings; every value under a key in DATE_KEYS
 * is stored as a Firestore Timestamp (the Dart side converts back, see
 * packages/campusfix_firebase/lib/src/firestore_codec.dart - keep both lists equal).
 */
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));

const argv = new Set(process.argv.slice(2));
const DRY_RUN = argv.has('--dry-run');
const ASSUME_YES = argv.has('--yes');

const SEED_FILE = process.env.SEED_FILE ?? path.join(HERE, 'seed.json');
const ALIAS_DOMAIN = process.env.ALIAS_DOMAIN ?? 'id.campusfix.test';
const SEED_PASSWORD = process.env.SEED_PASSWORD ?? 'campusfix-demo';
const CF_ENV = process.env.CF_ENV ?? 'dev';

/** Keys whose ISO-string values become Firestore Timestamps (keep == firestore_codec.dart). */
const DATE_KEYS = new Set(['createdAt', 'updatedAt', 'at', 'assignedAt']);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Same normalization as MockAuthRepository / FirebaseAuthRepository: trim + lowercase. */
function normalizeIdNumber(idNumber) {
  return String(idNumber).trim().toLowerCase();
}

/** `${idNumber trimmed + lowercased}@${ALIAS_DOMAIN}` (plan section 4). */
function aliasEmail(idNumber) {
  return `${normalizeIdNumber(idNumber)}@${ALIAS_DOMAIN}`;
}

/** Deep-copies [value], turning ISO strings under DATE_KEYS into `toTimestamp(iso)`. */
function reviveDates(value, toTimestamp, key = '') {
  if (Array.isArray(value)) return value.map((v) => reviveDates(v, toTimestamp, key));
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, reviveDates(v, toTimestamp, k)]),
    );
  }
  if (typeof value === 'string' && DATE_KEYS.has(key)) {
    if (Number.isNaN(new Date(value).getTime())) {
      throw new Error(`seed: "${key}" is not a valid ISO-8601 date: ${value}`);
    }
    return toTimestamp(value);
  }
  return value;
}

function fail(message) {
  throw new Error(`seed.json: ${message}`);
}

/**
 * Validates the shape written by export_seed.dart.
 * TODO(export_seed): keep in sync with packages/campusfix_core/tool/export_seed.dart.
 *
 * {
 *   schemaVersion: 1,
 *   users:         [ { id, idNumber, displayName, role, email, department|null } ],
 *   complaints:    [ { id, public: {...17 keys}, admin: {priority, priorityOverride, severity,
 *                      peopleAffected, assignment|null, timeline[]}, identity: {userId, fullName,
 *                      idNumber, email, phone|null} } ],
 *   notifications: [ { id, recipientId, complaintId, type, title, body, createdAt, read } ],
 *   lastSequenceByYear: { "2026": 29 }
 * }
 */
function validateSeed(seed) {
  if (seed === null || typeof seed !== 'object') fail('expected a JSON object');
  for (const k of ['users', 'complaints', 'notifications']) {
    if (!Array.isArray(seed[k])) fail(`"${k}" must be an array`);
  }
  if (seed.lastSequenceByYear === null || typeof seed.lastSequenceByYear !== 'object') {
    fail('"lastSequenceByYear" must be an object');
  }
  const uids = new Set();
  for (const u of seed.users) {
    for (const k of ['id', 'idNumber', 'displayName', 'role', 'email']) {
      if (typeof u[k] !== 'string' || u[k] === '') fail(`user ${JSON.stringify(u.id)} is missing "${k}"`);
    }
    if (uids.has(u.id)) fail(`duplicate user id ${u.id}`);
    uids.add(u.id);
  }
  for (const c of seed.complaints) {
    for (const k of ['id', 'public', 'admin', 'identity']) {
      if (c[k] === undefined || c[k] === null) fail(`complaint ${JSON.stringify(c.id)} is missing "${k}"`);
    }
    if (c.public.id !== c.id) fail(`complaint ${c.id}: public.id does not match`);
    if (!uids.has(c.identity.userId)) fail(`complaint ${c.id}: reporter ${c.identity.userId} is not in users`);
  }
  for (const n of seed.notifications) {
    if (typeof n.id !== 'string' || typeof n.recipientId !== 'string') fail('a notification is missing id/recipientId');
  }
}

/**
 * Turns the seed into the exact writes to perform. Pure: no network.
 * [toTimestamp] converts an ISO string to a Firestore Timestamp (stubbed in --dry-run).
 */
function buildPlan(seed, toTimestamp) {
  const revive = (v) => reviveDates(v, toTimestamp);

  const authUsers = [];
  const aliases = new Set();
  for (const u of seed.users) {
    const email = aliasEmail(u.idNumber);
    if (aliases.has(email)) fail(`two users share the alias ${email}`);
    aliases.add(email);
    authUsers.push({
      uid: u.id, // uid = AppUser.id so every foreign key in the data stays valid
      email,
      password: SEED_PASSWORD,
      displayName: u.displayName,
      // Roles live in the token claims (plan section 4): the client derives
      // AppUser.role from these, never from users/{uid}.
      claims: { role: u.role, ...(u.department ? { department: u.department } : {}) },
    });
  }

  /** @type {{path: string, data: object}[]} */
  const docs = [];

  for (const u of seed.users) {
    docs.push({
      path: `users/${u.id}`,
      data: {
        displayName: u.displayName,
        idNumber: u.idNumber,
        email: u.email, // the real address; the alias is an identifier only
        role: u.role,
        department: u.department ?? null,
        schemaVersion: 1,
      },
    });
  }

  for (const c of seed.complaints) {
    const assigneeId = c.admin.assignment?.assigneeId ?? null;
    docs.push({
      path: `complaints/${c.id}`,
      // `version` starts at 1; `claimed` mirrors "an assignee is named" (rule P7 helper).
      data: revive({ ...c.public, version: 1, claimed: assigneeId !== null }),
    });
    docs.push({ path: `complaints/${c.id}/private/admin`, data: revive(c.admin) });
    docs.push({ path: `complaints/${c.id}/private/identity`, data: c.identity });
    docs.push({
      path: `userComplaints/${c.identity.userId}/items/${c.id}`,
      data: revive({ complaintId: c.id, createdAt: c.public.createdAt }),
    });
    if (assigneeId !== null) {
      docs.push({
        path: `staffClaims/${assigneeId}/items/${c.id}`,
        data: { complaintId: c.id },
      });
    }
  }

  for (const n of seed.notifications) {
    // The doc keeps its own `id` (the rules require it on create).
    docs.push({ path: `notifications/${n.id}`, data: revive(n) });
  }

  for (const [year, last] of Object.entries(seed.lastSequenceByYear)) {
    docs.push({ path: `counters/complaintIds-${year}`, data: { last: Number(last) } });
  }

  return { authUsers, docs };
}

/** Works out which Firebase target this run writes to, and refuses unsafe ones. */
async function resolveTarget() {
  if (CF_ENV === 'prod') {
    throw new Error('Refusing to seed: CF_ENV=prod. Demo data must never go to production.');
  }
  const authEmu = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const fsEmu = process.env.FIRESTORE_EMULATOR_HOST;
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  let projectId = process.env.FIREBASE_PROJECT_ID ?? process.env.GCLOUD_PROJECT;

  if (authEmu || fsEmu) {
    if (!(authEmu && fsEmu)) {
      throw new Error('Set BOTH FIREBASE_AUTH_EMULATOR_HOST and FIRESTORE_EMULATOR_HOST (or neither).');
    }
    return { emulator: true, projectId: projectId ?? 'demo-campusfix' };
  }

  if (!keyPath) {
    throw new Error(
      'GOOGLE_APPLICATION_CREDENTIALS is not set. Point it at the dev project service-account key ' +
        '(or set the emulator hosts to seed the emulators). See backend/README.md.',
    );
  }
  if (!projectId) {
    try {
      projectId = JSON.parse(await readFile(keyPath, 'utf8')).project_id;
    } catch {
      // fall through: the Admin SDK will report a clear error if it cannot resolve a project
    }
  }
  if (!ASSUME_YES) {
    throw new Error(
      `About to write to the REAL Firebase project "${projectId ?? '(from key)'}". Re-run with --yes to confirm.`,
    );
  }
  return { emulator: false, projectId };
}

/** Creates or updates one Auth user, then (re)sets its custom claims. Idempotent. */
async function upsertAuthUser(auth, u) {
  const props = {
    email: u.email,
    password: u.password,
    displayName: u.displayName,
    emailVerified: true,
    disabled: false,
  };
  try {
    await auth.getUser(u.uid);
    await auth.updateUser(u.uid, props);
  } catch (e) {
    if (e?.code !== 'auth/user-not-found') throw e;
    await auth.createUser({ uid: u.uid, ...props });
  }
  await auth.setCustomUserClaims(u.uid, u.claims);
}

async function apply(plan, target) {
  const { initializeApp, applicationDefault } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');
  const { getFirestore } = await import('firebase-admin/firestore');

  initializeApp(
    target.emulator
      ? { projectId: target.projectId }
      : { credential: applicationDefault(), ...(target.projectId ? { projectId: target.projectId } : {}) },
  );
  const auth = getAuth();
  const db = getFirestore();

  for (const u of plan.authUsers) {
    await upsertAuthUser(auth, u);
    console.log(`  auth  ${u.uid}  <${u.email}>  claims=${JSON.stringify(u.claims)}`);
  }

  const writer = db.bulkWriter();
  writer.onWriteError((err) => {
    if (err.failedAttempts < 5) return true; // retry transient failures
    console.error(`  FAILED ${err.documentRef.path}: ${err.message}`);
    return false;
  });
  for (const { path: docPath, data } of plan.docs) {
    writer.set(db.doc(docPath), data);
  }
  await writer.close();
  console.log(`  firestore: wrote ${plan.docs.length} documents`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  let seed;
  try {
    seed = JSON.parse(await readFile(SEED_FILE, 'utf8'));
  } catch (e) {
    throw new Error(
      `Could not read ${SEED_FILE}: ${e.message}\n` +
        'Generate it first: cd packages/campusfix_core && dart run tool/export_seed.dart > ../../backend/seed/seed.json',
    );
  }
  validateSeed(seed);

  let toTimestamp = (iso) => ({ __timestamp: iso }); // --dry-run stub (no SDK needed)
  if (!DRY_RUN) {
    const { Timestamp } = await import('firebase-admin/firestore');
    toTimestamp = (iso) => Timestamp.fromDate(new Date(iso));
  }

  const plan = buildPlan(seed, toTimestamp);
  console.log(
    `Seed ${path.basename(SEED_FILE)}: ${plan.authUsers.length} users, ` +
      `${seed.complaints.length} complaints, ${seed.notifications.length} notifications -> ` +
      `${plan.docs.length} Firestore documents. Alias domain: ${ALIAS_DOMAIN}`,
  );

  if (DRY_RUN) {
    const sample = plan.authUsers[0];
    console.log(`(dry run) first user: uid=${sample?.uid} email=${sample?.email} claims=${JSON.stringify(sample?.claims)}`);
    console.log('(dry run) nothing written.');
    return;
  }

  const target = await resolveTarget();
  console.log(`Target: ${target.emulator ? 'EMULATORS' : 'REAL PROJECT'} (${target.projectId ?? 'project from credentials'})`);
  await apply(plan, target);
  console.log('Done. Demo password for every seeded user is SEED_PASSWORD (default "campusfix-demo").');
}

main().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});
