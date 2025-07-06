/**
 * fix_db.js
 * -----------
 * Adds a new string field `profile_picture` to each user document,
 * initializing it to an empty string for all users.
 */

const admin = require('firebase-admin')
const serviceAccount = require('./serviceAccountKey.json')

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
})

const db = admin.firestore()

async function addEmptyProfilePictureField() {
  console.log('Starting to add `profile_picture` field (empty) to users…')
  const usersSnap = await db.collection('users').get()
  let batch = db.batch()
  let count = 0

  for (const doc of usersSnap.docs) {
    const data = doc.data()
    // Skip if field already exists
    if (data.profile_picture !== undefined) continue

    // Always set to empty string
    batch.update(doc.ref, { profile_picture: '' })
    count++

    // Commit each 500 writes to avoid Firestore limits
    if (count % 500 === 0) {
      await batch.commit()
      batch = db.batch()
      console.log(`Committed 500 updates…`)
    }
  }

  // Final commit for remaining writes
  if (count % 500 !== 0) {
    await batch.commit()
  }

  console.log(`Done! Added empty \`profile_picture\` to ${count} user document(s).`)
}

addEmptyProfilePictureField().catch(err => {
  console.error('Migration failed:', err)
  process.exit(1)
})
