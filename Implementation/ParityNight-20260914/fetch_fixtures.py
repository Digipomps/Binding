"""Read only public, synthetic parity fixtures with default TLS and no redirects."""
import concurrent.futures
import datetime
import hashlib
import json
import pathlib
import urllib.request
import urllib.error

ROOT = pathlib.Path(__file__).resolve().parent
BASE = 'https://staging.haven.digipomps.org'
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None

def fetch(item):
    slug, kind, route = item
    assert route.startswith('/skeleton-parity/') and not route.startswith('//')
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))
    request = urllib.request.Request(BASE + route, headers={'Accept': 'application/json'})
    try:
        response = opener.open(request, timeout=20)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        data = response.read(2_000_001)
        assert len(data) <= 2_000_000
        json.loads(data)
        (ROOT / 'fixtures' / (slug + '-' + kind + '.json')).write_bytes(data)
        return dict(slug=slug, kind=kind, url=BASE+route, status=response.status,
                    bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                    observedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())

if __name__ == '__main__':
    (ROOT / 'fixtures').mkdir(exist_ok=True)
    catalog = json.loads((ROOT / 'staging-public-catalog-response.txt').read_text())
    tasks = [(f['slug'], kind, f[field]) for f in catalog['fixtures']
             for field, kind in [('configurationRoute', 'configuration'), ('stateRoute', 'state')]]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(fetch, tasks))
    (ROOT / 'fixtures/fetch-report.json').write_text(json.dumps(results, indent=2))
    print(json.dumps(results, indent=2))
