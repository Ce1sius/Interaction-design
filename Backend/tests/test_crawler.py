from app.crawler.domain_validator import DomainValidator, UnsafeURL
from app.documents.remote_fetcher import extract_openxml_text
from app.crawler.pdf_link_extractor import extract_pdf_links
from app.crawler.url_normalizer import normalize_url
import io
import zipfile


def test_extract_pdf_links_normalizes_relative_and_deduplicates():
    html = """
    <a href="/files/Week%201.pdf#page=3">one</a>
    <a href="https://school.example.edu/files/Week%201.pdf">duplicate</a>
    <a href="https://cdn.school.example.edu/slide.pdf?download=1">two</a>
    <a href="/files/readme.txt">ignore</a>
    """
    links = extract_pdf_links(html, "https://school.example.edu/course/index.html")

    assert links == [
        "https://school.example.edu/files/Week%201.pdf",
        "https://cdn.school.example.edu/slide.pdf?download=1",
    ]


def test_normalize_url_removes_default_port_and_fragment():
    assert normalize_url("HTTPS://School.Example.Edu:443/a b.pdf#x") == "https://school.example.edu/a%20b.pdf"


def test_domain_validator_rejects_outside_allowed_domain():
    validator = DomainValidator(["school.example.edu"], resolve_dns=False)
    validator.validate_url("https://school.example.edu/course.pdf")

    try:
        validator.validate_url("https://evil.example.net/course.pdf")
    except UnsafeURL as exc:
        assert "outside allowedDomains" in str(exc)
    else:
        raise AssertionError("expected UnsafeURL")


def test_domain_validator_rejects_private_ip_host():
    validator = DomainValidator(["127.0.0.1"], resolve_dns=False)
    try:
        validator.validate_url("http://127.0.0.1/secret.pdf")
    except UnsafeURL as exc:
        assert "private or local IP" in str(exc)
    else:
        raise AssertionError("expected UnsafeURL")


def test_domain_validator_can_allow_private_dns_for_trusted_host(monkeypatch):
    def fake_getaddrinfo(*args, **kwargs):
        return [(None, None, None, None, ("10.10.10.10", 0))]

    monkeypatch.setattr("socket.getaddrinfo", fake_getaddrinfo)

    strict = DomainValidator(["courses.zju.edu.cn"])
    try:
        strict.validate_url("https://courses.zju.edu.cn/user/courses")
    except UnsafeURL as exc:
        assert "resolved private or local IP" in str(exc)
    else:
        raise AssertionError("expected UnsafeURL")

    trusted = DomainValidator(["courses.zju.edu.cn"], allow_private_resolved_hosts=("courses.zju.edu.cn",))
    trusted.validate_url("https://courses.zju.edu.cn/user/courses")


def test_extract_openxml_text_reads_pptx_slides():
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("ppt/slides/slide1.xml", "<p><a:t>概率论</a:t><a:t>随机变量</a:t></p>")

    text = extract_openxml_text(buffer.getvalue())

    assert "概率论" in text
    assert "随机变量" in text
