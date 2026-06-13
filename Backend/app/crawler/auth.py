from __future__ import annotations

from dataclasses import dataclass, field
from http.cookies import SimpleCookie

from app.courses.schemas import AuthSession


DEFAULT_USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148"


@dataclass(frozen=True)
class AuthContext:
    cookie_header: str | None = None
    headers: dict[str, str] = field(default_factory=dict)

    @classmethod
    def from_request(cls, auth: AuthSession | None, fallback_cookie: str | None = None) -> "AuthContext":
        headers = dict(auth.headers) if auth else {}
        cookie_header = auth.cookieHeader if auth and auth.cookieHeader else fallback_cookie
        return cls(cookie_header=cookie_header, headers=headers)

    def request_headers(self) -> dict[str, str]:
        headers = {
            "User-Agent": DEFAULT_USER_AGENT,
            **self.headers,
        }
        if self.cookie_header:
            headers["Cookie"] = self.cookie_header
        return headers

    def playwright_cookies(self, domain: str) -> list[dict]:
        if not self.cookie_header:
            return []
        parsed = SimpleCookie()
        parsed.load(self.cookie_header)
        return [
            {
                "name": morsel.key,
                "value": morsel.value,
                "domain": domain,
                "path": "/",
                "httpOnly": False,
                "secure": True,
                "sameSite": "Lax",
            }
            for morsel in parsed.values()
        ]
