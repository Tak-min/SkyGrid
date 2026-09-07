"""Read-only deployment checks using curl. Optional argument: local base URL."""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

base = sys.argv[1].rstrip('/') if len(sys.argv) > 1 else 'https://skygrid.my'
site = Path(__file__).resolve().parents[1] / 'site'

def fetch(url, follow=False):
    args = ['curl', '--silent', '--show-error', '--max-time', '30']
    if follow:
        args += ['--location']
    result = subprocess.check_output(args + ['--write-out', '\n%{http_code}\n%{url_effective}\n%{redirect_url}', url])
    body, status, effective, redirect = result.rsplit(b'\n', 3)
    return body, int(status), effective.decode(), redirect.decode()

for path, title in [('/', 'Sky Grid — Available now on the App Store'),
                    ('/support', 'Sky Grid — Support'),
                    ('/terms', 'Sky Grid — Terms of Use'),
                    ('/privacy', 'Sky Grid — Privacy Policy')]:
    body, status, _, _ = fetch(base + path)
    assert status == 200, (path, status)
    html = body.decode()
    assert f'<title>{title}</title>' in html, path
    filename = 'index.html' if path == '/' else path[1:] + '.html'
    assert html == (site / filename).read_text(), f'Stale page: {path}'
    print(f'200 {path}: {title} (matches local file)', flush=True)
    if path == '/':
        assert '-v1.webp' not in html
        assert 'trial' not in html.lower()
        assert 'Moku' in html and 'newest 30 days' in html
        assets = set(re.findall(r'(?:src|srcset|href)="(/images/[^\"]+|(?:style.css|app.js))"', html))
        assets.update(['/images/00-skygrid-overview-v2.webp', 'legal.css'])
        for asset in sorted(assets):
            actual, status, _, _ = fetch(base + '/' + asset.lstrip('/'))
            assert status == 200, (asset, status)
            expected = (site / asset.lstrip('/')).read_bytes()
            assert hashlib.sha256(actual).digest() == hashlib.sha256(expected).digest(), asset
            print(f'200 {asset}: byte-for-byte match', flush=True)

if base == 'https://skygrid.my':
    old = 'https://skygrid-legal.taku810616.workers.dev/privacy'
    _, status, _, redirect = fetch(old)
    assert status == 301 and redirect == base + '/privacy'
    print(f'301 legacy /privacy → {redirect}')
    body, status, effective, _ = fetch(old, follow=True)
    assert status == 200 and effective == base + '/privacy'
    assert '<title>Sky Grid — Privacy Policy</title>' in body.decode()
    print('Redirect followed: 200, correct privacy title')
