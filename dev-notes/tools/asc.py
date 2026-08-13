import base64
import json
import time
import urllib.request
import urllib.error

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

KEY_ID = "8NP27G4GSX"
ISSUER_ID = "58c05121-f8df-456e-bff8-00455e0fbc79"
KEY_PATH = "/Users/taku8/.appstoreconnect/private_keys/AuthKey_8NP27G4GSX.p8"
BASE = "https://api.appstoreconnect.apple.com/v1"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_jwt() -> str:
    with open(KEY_PATH, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)

    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"
    der_sig = private_key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der_sig)
    raw_sig = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return f"{signing_input}.{b64url(raw_sig)}"


def call(method: str, path: str, body: dict | None = None) -> dict:
    token = make_jwt()
    url = path if path.startswith("http") else f"{BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {"raw": raw.decode(errors="replace")}
        print(f"HTTP {e.code} on {method} {url}")
        print(json.dumps(parsed, indent=2))
        raise


if __name__ == "__main__":
    import sys

    method = sys.argv[1]
    path = sys.argv[2]
    body = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    result = call(method, path, body)
    print(json.dumps(result, indent=2))
