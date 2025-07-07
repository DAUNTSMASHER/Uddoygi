const { google } = require('googleapis');
const { GoogleAuth } = require('google-auth-library');

const projectId = 'uddyogi'; // Replace with your actual Firebase project ID
const collection = 'invoices';

async function createFirestoreIndex() {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/datastore']
  });

  const firestore = google.firestore({
    version: 'v1',
    auth: await auth.getClient()
  });

  const res = await firestore.projects.databases.collectionGroups.indexes.create({
    parent: `projects/${projectId}/databases/(default)/collectionGroups/${collection}`,
    requestBody: {
      fields: [
        { fieldPath: 'agentEmail', order: 'ASCENDING' },
        { fieldPath: 'timestamp', order: 'DESCENDING' }
      ],
      queryScope: 'COLLECTION'
    }
  });

  console.log('Index creation request submitted:', res.data);
}

createFirestoreIndex().catch(console.error);
