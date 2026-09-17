const test = require("node:test");
const assert = require("node:assert/strict");

const {
  grantEntitlement,
  revokeEntitlement,
} = require("../lib/earlyAdopterGrantStore.js");

test("grant uses a fixed expiry and retries 429/5xx without extending it", async () => {
  const expiry = 1_800_000_000_000;
  const requests = [];
  const sleeps = [];
  const statuses = [429, 503, 201];
  const fetchImpl = async (url, init) => {
    requests.push({ url, init });
    return new Response("", { status: statuses.shift() });
  };

  await grantEntitlement("user/with slash", expiry, {
    apiKey: "test-secret",
    fetchImpl,
    sleep: async (milliseconds) => sleeps.push(milliseconds),
  });

  assert.equal(requests.length, 3);
  assert.deepEqual(sleeps, [500, 1500]);
  for (const request of requests) {
    assert.match(request.url, /subscribers\/user%2Fwith%20slash\/entitlements\/premium\/promotional$/);
    assert.equal(request.init.method, "POST");
    assert.deepEqual(JSON.parse(request.init.body), { end_time_ms: expiry });
    assert.equal(request.init.headers.Authorization, "Bearer test-secret");
  }
});

test("grant does not retry a non-retryable RevenueCat response", async () => {
  let calls = 0;
  await assert.rejects(
    grantEntitlement("uid", 1_800_000_000_000, {
      apiKey: "test-secret",
      fetchImpl: async () => {
        calls += 1;
        return new Response("", { status: 400 });
      },
      sleep: async () => assert.fail("400 must not be retried"),
    }),
    /status 400/,
  );
  assert.equal(calls, 1);
});

test("revocation uses RevenueCat's revoke_promotionals endpoint", async () => {
  let request;
  await revokeEntitlement("uid", {
    apiKey: "test-secret",
    fetchImpl: async (url, init) => {
      request = { url, init };
      return new Response("", { status: 200 });
    },
  });

  assert.match(request.url, /subscribers\/uid\/entitlements\/premium\/revoke_promotionals$/);
  assert.equal(request.init.method, "POST");
  assert.equal(request.init.body, undefined);
});

test("RevenueCat secret is required but never included in validation errors", async () => {
  await assert.rejects(
    grantEntitlement("uid", 1_800_000_000_000, { apiKey: "" }),
    /REVENUECAT_SECRET_API_KEY environment variable not set/,
  );
});
