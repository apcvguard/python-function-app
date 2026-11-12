from app.greeting import build_greeting, health_payload


def test_greeting_with_name():
    status, body = build_greeting("Asha")
    assert status == 200
    assert body == {"message": "Hello, Asha!"}


def test_greeting_strips_whitespace():
    assert build_greeting("  Ravi  ")[1]["message"] == "Hello, Ravi!"


def test_greeting_missing_name():
    status, body = build_greeting(None)
    assert status == 400
    assert "error" in body


def test_greeting_blank_name():
    assert build_greeting("   ")[0] == 400


def test_health_reads_env(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "abc123")
    monkeypatch.setenv("APP_ENV", "dev")
    assert health_payload() == {"status": "ok", "version": "abc123", "environment": "dev"}
