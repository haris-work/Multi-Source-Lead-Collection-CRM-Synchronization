"""Non-destructive local FastAPI smoke test using a synthetic, unique contact."""
import json
import time
import urllib.error
import urllib.request
import uuid

BASE = "http://127.0.0.1:8000"

def request(method, path, payload=None):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(BASE + path, data=body, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as r:
        return r.status, json.loads(r.read().decode("utf-8"))

def main():
    status, health = request("GET", "/health")
    assert status == 200 and health["status"] == "healthy", health
    suffix = uuid.uuid4().hex[:12]
    email = f"p02-smoke-{suffix}@example.com"
    status, contact = request("POST", "/contacts", {
        "firstName": "Automation", "lastName": "Test", "email": email,
        "company": "Synthetic QA", "service": "CRM Automation", "budget": 100
    })
    assert status == 201 and contact["email"] == email, contact
    contact_id = contact["id"]
    status, updated = request("PATCH", f"/contacts/{contact_id}", {"budget": 150})
    assert status == 200 and updated["version"] == contact["version"] + 1, updated
    assert updated["budget"] == 150, updated
    print(f"PASS: health, create, update. contact_id={contact_id}, email={email}")
    print("NOTE: This test adds a real synthetic record and two events to your local CRM database.")

if __name__ == "__main__":
    main()
