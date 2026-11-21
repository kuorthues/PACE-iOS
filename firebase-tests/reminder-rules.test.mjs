import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { after, beforeEach, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  writeBatch,
} from "firebase/firestore";

const projectId = "demo-pace";
const rules = readFileSync(new URL("../firestore.rules", import.meta.url), "utf8");
const testEnvironment = await initializeTestEnvironment({
  projectId,
  firestore: { rules },
});

after(async () => {
  await testEnvironment.cleanup();
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "sharedGoals/goal-1"), {
      status: "active",
      memberIds: ["sender", "recipient"],
    });
    await setDoc(doc(context.firestore(), "users/recipient/notificationState/read-event"), {
      isRead: true,
      updatedAt: new Date(),
    });
  });
});

function writeReminder(context, reminderId, senderId = "sender", recipientId = "recipient") {
  const db = context.firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, `sharedGoals/goal-1/reminders/${reminderId}`), {
    id: reminderId,
    sharedGoalId: "goal-1",
    senderId,
    recipientId,
    createdAt: serverTimestamp(),
  });
  batch.set(doc(db, `sharedGoals/goal-1/reminderCooldowns/${recipientId}`), {
    recipientId,
    lastSenderId: senderId,
    lastReminderId: reminderId,
    lastReminderAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

test("an active member can atomically create a reminder and its cooldown", async () => {
  const sender = testEnvironment.authenticatedContext("sender");
  await assertSucceeds(writeReminder(sender, "reminder-1"));

  const recipient = testEnvironment.authenticatedContext("recipient");
  const received = await assertSucceeds(
    getDoc(doc(recipient.firestore(), "sharedGoals/goal-1/reminders/reminder-1")),
  );
  assert.equal(received.data().recipientId, "recipient");
});

test("a reminder without the paired cooldown write is denied", async () => {
  const senderDb = testEnvironment.authenticatedContext("sender").firestore();
  await assertFails(setDoc(doc(senderDb, "sharedGoals/goal-1/reminders/orphan"), {
    id: "orphan",
    sharedGoalId: "goal-1",
    senderId: "sender",
    recipientId: "recipient",
    createdAt: serverTimestamp(),
  }));
});

test("sender forgery, self-reminders, and unrelated recipients are denied", async () => {
  const sender = testEnvironment.authenticatedContext("sender");
  await assertFails(writeReminder(sender, "forged", "recipient", "sender"));
  await assertFails(writeReminder(sender, "self", "sender", "sender"));
  await assertFails(writeReminder(sender, "outsider", "sender", "unrelated"));
});

test("the server-enforced cooldown rejects a second reminder within 24 hours", async () => {
  const sender = testEnvironment.authenticatedContext("sender");
  await assertSucceeds(writeReminder(sender, "reminder-1"));
  await assertFails(writeReminder(sender, "reminder-2"));
});

test("notification read state is private to its account", async () => {
  const recipientDb = testEnvironment.authenticatedContext("recipient").firestore();
  const senderDb = testEnvironment.authenticatedContext("sender").firestore();
  await assertSucceeds(getDoc(doc(recipientDb, "users/recipient/notificationState/read-event")));
  await assertFails(getDoc(doc(senderDb, "users/recipient/notificationState/read-event")));
  await assertFails(setDoc(doc(senderDb, "users/recipient/notificationState/forged"), {
    isRead: true,
    updatedAt: serverTimestamp(),
  }));
});

test("a public username must match its normalized reservation", async () => {
  const impersonatorDb = testEnvironment.authenticatedContext("impersonator").firestore();
  const forgedBatch = writeBatch(impersonatorDb);
  forgedBatch.set(doc(impersonatorDb, "publicProfiles/impersonator"), {
    userId: "impersonator",
    username: "victim",
    usernameNormalized: "impersonator",
    displayName: "Forged handle",
    bio: "",
    isDiscoverable: true,
    lookingForPartner: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  forgedBatch.set(doc(impersonatorDb, "usernames/impersonator"), {
    userId: "impersonator",
    usernameNormalized: "impersonator",
    createdAt: serverTimestamp(),
  });
  await assertFails(forgedBatch.commit());

  const validDb = testEnvironment.authenticatedContext("valid-profile").firestore();
  const validBatch = writeBatch(validDb);
  validBatch.set(doc(validDb, "publicProfiles/valid-profile"), {
    userId: "valid-profile",
    username: "PACE.User",
    usernameNormalized: "pace.user",
    displayName: "Valid User",
    bio: "",
    isDiscoverable: true,
    lookingForPartner: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  validBatch.set(doc(validDb, "usernames/pace.user"), {
    userId: "valid-profile",
    usernameNormalized: "pace.user",
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(validBatch.commit());
});

test("a former member loses reminder access after membership is revoked", async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "sharedGoals/goal-1/reminders/old"), {
      id: "old",
      sharedGoalId: "goal-1",
      senderId: "sender",
      recipientId: "recipient",
      createdAt: new Date(),
    });
    await setDoc(doc(context.firestore(), "sharedGoals/goal-1"), {
      status: "ended",
      memberIds: ["sender"],
    });
  });

  const formerMemberDb = testEnvironment.authenticatedContext("recipient").firestore();
  await assertFails(getDoc(doc(formerMemberDb, "sharedGoals/goal-1/reminders/old")));
});
