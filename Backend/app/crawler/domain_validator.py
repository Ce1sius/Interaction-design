from __future__ import annotations

import ipaddress
import socket
from dataclasses import dataclass
from urllib.parse import urlsplit


class UnsafeURL(ValueError):
    pass


@dataclass(frozen=True)
class DomainValidator:
    allowed_domains: tuple[str, ...]
    resolve_dns: bool = True
    allow_private_resolved_hosts: tuple[str, ...] = ()

    def __init__(
        self,
        allowed_domains: list[str] | tuple[str, ...],
        resolve_dns: bool = True,
        allow_private_resolved_hosts: list[str] | tuple[str, ...] = (),
    ):
        normalized = tuple(sorted({domain.strip().lower().lstrip(".") for domain in allowed_domains if domain.strip()}))
        private_dns_hosts = tuple(sorted({host.strip().lower().lstrip(".") for host in allow_private_resolved_hosts if host.strip()}))
        object.__setattr__(self, "allowed_domains", normalized)
        object.__setattr__(self, "resolve_dns", resolve_dns)
        object.__setattr__(self, "allow_private_resolved_hosts", private_dns_hosts)

    def validate_url(self, url: str) -> None:
        parts = urlsplit(url)
        if parts.scheme not in {"http", "https"}:
            raise UnsafeURL("only http and https URLs are allowed")
        if parts.username or parts.password:
            raise UnsafeURL("URLs with embedded credentials are not allowed")
        host = (parts.hostname or "").lower()
        if not host:
            raise UnsafeURL("URL host is empty")
        if not self._is_allowed_domain(host):
            raise UnsafeURL(f"host '{host}' is outside allowedDomains")
        if self._is_ip_host_unsafe(host):
            raise UnsafeURL("direct private or local IP host is not allowed")
        if self.resolve_dns:
            self._validate_dns_targets(host, allow_private=self._allows_private_dns(host))

    def _is_allowed_domain(self, host: str) -> bool:
        return any(host == domain or host.endswith(f".{domain}") for domain in self.allowed_domains)

    def _allows_private_dns(self, host: str) -> bool:
        return any(host == domain or host.endswith(f".{domain}") for domain in self.allow_private_resolved_hosts)

    @staticmethod
    def _is_ip_host_unsafe(host: str) -> bool:
        try:
            ip = ipaddress.ip_address(host.strip("[]"))
        except ValueError:
            return False
        return is_unsafe_ip(ip)

    @staticmethod
    def _validate_dns_targets(host: str, allow_private: bool = False) -> None:
        try:
            infos = socket.getaddrinfo(host, None)
        except socket.gaierror as exc:
            raise UnsafeURL(f"cannot resolve host '{host}'") from exc
        for info in infos:
            raw_ip = info[4][0]
            ip = ipaddress.ip_address(raw_ip)
            if is_unsafe_ip(ip) and not allow_private:
                raise UnsafeURL("resolved private or local IP address is not allowed")


def is_unsafe_ip(ip: ipaddress._BaseAddress) -> bool:
    metadata = ipaddress.ip_address("169.254.169.254")
    return (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
        or ip == metadata
    )
