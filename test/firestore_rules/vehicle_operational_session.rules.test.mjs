import assert from 'node:assert/strict';
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

async function seedData({ users = [], sessions = [] } = {}) {
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
        routeId: 'route-1',
        ...data,
      });
    }
    for (const [sessionId, data] of sessions) {
      await setDoc(doc(db, 'vehicleOperationalSessions', sessionId), {
        busNumber: sessionId,
        activeDriverId: 'driver-1',
        status: 'active',
        isTripActive: false,
        tripId: '',
        lastLatitude: 31.9539,
        lastLongitude: 35.9106,
        lastHeartbeatAt: new Date(),
        updatedAt: new Date(),
        ...data,
      });
    }
  });
}

test('an unverified driver must not create a vehicle operational session', async () => {
  await seedData({
    users: [['driver-unverified', { isVerified: false }]],
  });

  const db = testEnv.authenticatedContext('driver-unverified').firestore();
  await assertFails(
    setDoc(doc(db, 'vehicleOperationalSessions', 'BUS-1'), {
      busNumber: 'BUS-1',
      activeDriverId: 'driver-unverified',
      status: 'active',
      isTripActive: false,
      tripId: '',
      lastLatitude: 31.9539,
      lastLongitude: 35.9106,
      lastHeartbeatAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('a different driver must not take over a fresh active session using handover fields', async () => {
  await seedData({
    users: [
      ['driver-1', { isVerified: true, busNumber: 'BUS-1' }],
      ['driver-2', { isVerified: true, busNumber: 'BUS-1' }],
    ],
    sessions: [
      [
        'BUS-1',
        {
          activeDriverId: 'driver-1',
          status: 'active',
          isTripActive: false,
          tripId: '',
          lastHeartbeatAt: new Date(),
        },
      ],
    ],
  });

  const db = testEnv.authenticatedContext('driver-2').firestore();
  await assertFails(
    updateDoc(doc(db, 'vehicleOperationalSessions', 'BUS-1'), {
      activeDriverId: 'driver-2',
      status: 'active',
      isTripActive: false,
      tripId: '',
      handoverReason: 'stale-session-and-location-check',
      handedOverAt: serverTimestamp(),
      lastHeartbeatAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('the active owner may update only the supported heartbeat fields', async () => {
  await seedData({
    users: [['driver-1', { isVerified: true, busNumber: 'BUS-1' }]],
    sessions: [['BUS-1', { activeDriverId: 'driver-1' }]],
  });

  const db = testEnv.authenticatedContext('driver-1').firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'vehicleOperationalSessions', 'BUS-1'), {
      lastLatitude: 31.954,
      lastLongitude: 35.911,
      lastHeartbeatAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('a driver assigned to a different bus must not update this session', async () => {
  await seedData({
    users: [
      ['driver-1', { isVerified: true, busNumber: 'BUS-1' }],
      ['driver-2', { isVerified: true, busNumber: 'BUS-2' }],
    ],
    sessions: [['BUS-1', { activeDriverId: 'driver-1' }]],
  });

  const db = testEnv.authenticatedContext('driver-2').firestore();
  await assertFails(
    updateDoc(doc(db, 'vehicleOperationalSessions', 'BUS-1'), {
      lastLatitude: 32.0,
      lastLongitude: 36.0,
      lastHeartbeatAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});
