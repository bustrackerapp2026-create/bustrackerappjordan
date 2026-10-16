import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { after, before, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  updateDoc,
  serverTimestamp,
} from 'firebase/firestore';

const projectId = 'demo-jordan-bus-tracker-rules';
const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));

let testEnv;

before(async () => {
  const rules = readFileSync(rulesPath, 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

function publicLocationPayload(overrides = {}) {
  return {
    currentLatitude: 31.9539,
    currentLongitude: 35.9106,
    locationUpdatedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    isOnline: true,
    isSharingLocation: true,
    isTripActive: false,
    ...overrides,
  };
}

async function seed({ users = [], publicDocs = [] } = {}) {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    for (const [uid, data] of users) {
      await setDoc(doc(db, 'users', uid), {
        uid,
        userType: 'driver',
        isVerified: true,
        isRejected: false,
        busNumber: 'BUS-1',
        ...data,
      });
    }

    for (const [uid, data] of publicDocs) {
      await setDoc(doc(db, 'driverPublic', uid), {
        fullName: 'Driver One',
        busNumber: 'BUS-1',
        route: 'Route 1',
        currentLatitude: 31.9539,
        currentLongitude: 35.9106,
        locationUpdatedAt: new Date(),
        updatedAt: new Date(),
        isOnline: true,
        isSharingLocation: true,
        isTripActive: false,
        ...data,
      });
    }
  });
}

test('an unverified driver cannot create a public driver location', async () => {
  await seed({
    users: [['driver-1', { isVerified: false }]],
  });

  const db = testEnv.authenticatedContext('driver-1').firestore();
  await assertFails(
    setDoc(
      doc(db, 'driverPublic', 'driver-1'),
      publicLocationPayload(),
    ),
  );
});

test('a passenger cannot publish into driverPublic', async () => {
  await seed({
    users: [['passenger-1', { userType: 'passenger', isVerified: true }]],
  });

  const db = testEnv.authenticatedContext('passenger-1').firestore();
  await assertFails(
    setDoc(
      doc(db, 'driverPublic', 'passenger-1'),
      publicLocationPayload(),
    ),
  );
});

test('a verified driver can create their own public location', async () => {
  await seed({
    users: [['driver-1', { isVerified: true, busNumber: 'BUS-1' }]],
  });

  const db = testEnv.authenticatedContext('driver-1').firestore();
  await assertSucceeds(
    setDoc(
      doc(db, 'driverPublic', 'driver-1'),
      publicLocationPayload({ busNumber: 'BUS-1' }),
    ),
  );
});

test('an unverified driver cannot update an existing public location', async () => {
  await seed({
    users: [['driver-1', { isVerified: false }]],
    publicDocs: [['driver-1', {}]],
  });

  const db = testEnv.authenticatedContext('driver-1').firestore();
  await assertFails(
    updateDoc(doc(db, 'driverPublic', 'driver-1'), {
      currentLatitude: 31.954,
      currentLongitude: 35.911,
      locationUpdatedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('a verified driver can update their own public location', async () => {
  await seed({
    users: [['driver-1', { isVerified: true, busNumber: 'BUS-1' }]],
    publicDocs: [['driver-1', {}]],
  });

  const db = testEnv.authenticatedContext('driver-1').firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'driverPublic', 'driver-1'), {
      currentLatitude: 31.954,
      currentLongitude: 35.911,
      locationUpdatedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('a verified driver cannot publish under another user id', async () => {
  await seed({
    users: [['driver-1', { isVerified: true, busNumber: 'BUS-1' }]],
  });

  const db = testEnv.authenticatedContext('driver-1').firestore();
  await assertFails(
    setDoc(
      doc(db, 'driverPublic', 'driver-2'),
      publicLocationPayload({ busNumber: 'BUS-1' }),
    ),
  );
});
