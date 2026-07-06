const PROJECT_ID = 'uddyogi';
const API_KEY = 'AIzaSyB00JFFDWQfEKRFpz50RLfKTuz9Ve4uuyg';
const REST_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function parseRestDoc(id, json) {
  const fields = json.fields || {};
  const str = (key) => {
    const f = fields[key];
    if (!f) return '';
    return f.stringValue || f.integerValue?.toString() || '';
  };
  const name = str('companyName') || str('legalName') || 'Unknown Company';
  return {
    companyId: id,
    name,
    logoUrl: str('logoUrl'),
    email: str('email'),
    phone: str('phone'),
    industry: str('industry'),
  };
}

export async function lookupCompany(companyId) {
  const id = companyId.trim();
  if (!id || id.length !== 8 || !/^\d+$/.test(id)) {
    throw new Error('Company ID must be exactly 8 digits.');
  }

  const url = `${REST_BASE}/companies/${id}?key=${API_KEY}`;
  const res = await fetch(url, { headers: { Accept: 'application/json' } });

  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Server error ${res.status}. Please try again.`);

  const json = await res.json();
  return parseRestDoc(id, json);
}
