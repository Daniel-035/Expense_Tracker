// Uses only Node's built-in test runner and the local emulator REST API.
const {test, before} = require('node:test');
const assert = require('node:assert/strict');
const project = 'demo-ledgerone';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host) throw new Error('Run with firebase emulators:exec --project demo-ledgerone.');
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const documentName = path => `projects/${project}/databases/(default)/documents/${path}`;
const token = uid => {
  const base64 = data => Buffer.from(JSON.stringify(data)).toString('base64url');
  return `${base64({alg: 'none', typ: 'JWT'})}.${base64({
    aud: project, iss: `https://securetoken.google.com/${project}`, sub: uid, user_id: uid,
    iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
    firebase: {sign_in_provider: 'custom', identities: {}},
  })}.`;
};
const value = v => v === null ? {nullValue: null} : Array.isArray(v)
  ? {arrayValue: {values: v.map(value)}} : typeof v === 'boolean' ? {booleanValue: v}
    : typeof v === 'number' ? Number.isInteger(v) ? {integerValue: `${v}`} : {doubleValue: v}
      : {stringValue: v};
const fields = data => Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)]));
const write = (path, data) => ({update: {name: documentName(path), fields: fields(data)}});
const request = (path, method, body, uid = 'alice') => fetch(`${root}${path}`, {
  method, headers: {'Content-Type': 'application/json', Authorization: `Bearer ${uid === 'owner' ? 'owner' : token(uid)}`},
  body: body === undefined ? undefined : JSON.stringify(body),
});
const commit = (writes, uid) => request(':commit', 'POST', {writes}, uid);
const cash = balance => ({accountName: 'Cash', accountType: 'cash', balance, balanceMinor: balance * 100, archived: false});
const expense = amount => ({accountId: 'cash', categoryId: 'food', amount, amountMinor: amount * 100,
  transactionType: 'expense', merchant: null, notes: null, receiptUrl: null, location: null, tags: [],
  transferAccountId: null, recurrence: 'none', nextOccurrence: null, createdAt: '2026-10-26T12:00:00.000'});
const expectStatus = async (response, expected) => {
  const text = await response.text();
  assert.equal(response.status, expected, text);
};

before(async () => {
  await expectStatus(await commit([
    write('users/alice/accounts/cash', cash(100)),
    write('users/alice/categories/food', {name: 'Food', type: 'expense', color: 1234, icon: 'food', isSystem: false}),
  ], 'owner'), 200);
});

test('owner reads own account; another user cannot read or write it', async () => {
  await expectStatus(await request('/users/alice/accounts/cash', 'GET'), 200);
  await expectStatus(await request('/users/alice/accounts/cash', 'GET', undefined, 'bob'), 403);
  await expectStatus(await commit([write('users/alice/accounts/cash', cash(200))], 'bob'), 403);
});

test('standalone balance change and unposted transaction are rejected', async () => {
  await expectStatus(await commit([write('users/alice/accounts/cash', cash(90))]), 403);
  await expectStatus(await commit([write('users/alice/transactions/unposted', expense(10))]), 403);
});

test('atomic expense, edit, and reversal keep balance consistent', async () => {
  await expectStatus(await commit([
    write('users/alice/accounts/cash', {...cash(90), lastTransactionId: 'posted'}),
    write('users/alice/transactions/posted', expense(10)),
  ]), 200);
  await expectStatus(await commit([
    write('users/alice/accounts/cash', {...cash(85), lastTransactionId: 'posted'}),
    write('users/alice/transactions/posted', expense(15)),
  ]), 200);
  await expectStatus(await commit([{delete: documentName('users/alice/transactions/posted')}]), 403);
  await expectStatus(await commit([
    write('users/alice/accounts/cash', {...cash(100), lastTransactionId: 'posted'}),
    {delete: documentName('users/alice/transactions/posted')},
  ]), 200);
});

test('invalid amounts, mismatched minor units and hard account deletion are rejected', async () => {
  await expectStatus(await commit([write('users/alice/accounts/bad', {...cash(10), balanceMinor: 1})]), 403);
  await expectStatus(await commit([write('users/alice/transactions/negative', expense(-1))]), 403);
  await expectStatus(await commit([{delete: documentName('users/alice/accounts/cash')}]), 403);
});

test('account creation and metadata-only updates are allowed', async () => {
  await expectStatus(await commit([write('users/alice/accounts/new', cash(25))]), 200);
  await expectStatus(await commit([write('users/alice/accounts/new', {...cash(25), accountName: 'Renamed', archived: true})]), 200);
});

test('transfer edit across four accounts and deletion require every balance delta', async () => {
  await expectStatus(await commit([
    write('users/alice/accounts/source', cash(100)), write('users/alice/accounts/dest', cash(50)),
    write('users/alice/accounts/third', cash(80)), write('users/alice/accounts/fourth', cash(20)),
  ], 'owner'), 200);
  const transfer = (from, to, amount) => ({...expense(amount), accountId: from, transferAccountId: to, categoryId: '', transactionType: 'transfer'});
  await expectStatus(await commit([
    write('users/alice/accounts/source', {...cash(70), lastTransactionId: 'move'}),
    write('users/alice/transactions/move', transfer('source', 'dest', 30)),
  ]), 403);
  await expectStatus(await commit([
    write('users/alice/accounts/source', {...cash(70), lastTransactionId: 'move'}),
    write('users/alice/accounts/dest', {...cash(80), lastTransactionId: 'move'}),
    write('users/alice/transactions/move', transfer('source', 'dest', 30)),
  ]), 200);
  await expectStatus(await commit([
    write('users/alice/accounts/source', {...cash(100), lastTransactionId: 'move'}),
    write('users/alice/accounts/dest', {...cash(50), lastTransactionId: 'move'}),
    write('users/alice/accounts/third', {...cash(40), lastTransactionId: 'move'}),
    write('users/alice/accounts/fourth', {...cash(60), lastTransactionId: 'move'}),
    write('users/alice/transactions/move', transfer('third', 'fourth', 40)),
  ]), 200);
  await expectStatus(await commit([
    write('users/alice/accounts/third', {...cash(80), lastTransactionId: 'move'}),
    write('users/alice/accounts/fourth', {...cash(20), lastTransactionId: 'move'}),
    {delete: documentName('users/alice/transactions/move')},
  ]), 200);
});
