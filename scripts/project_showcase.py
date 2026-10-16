#!/usr/bin/env python3
"""Validate static showcase reports and package a rendered site (stdlib only).

Pandoc parses Markdown references and YAML; it does not execute report code.
Rights, consent and scientific correctness remain human review decisions.
"""
import argparse
import json
from html.parser import HTMLParser
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlsplit

SHA = re.compile(r'[0-9a-f]{40}')
IMAGES = {'.png', '.jpg', '.jpeg', '.webp', '.gif'}
FIELDS = {'title', 'author', 'description', 'source-repository', 'reproduction-url', 'license'}


def document(path):
    result = subprocess.run(['quarto', 'pandoc', '--from=markdown', '--to=json', str(path)], capture_output=True, text=True)
    if result.returncode:
        raise ValueError('Markdown/YAML parse failed: ' + result.stderr.strip())
    return json.loads(result.stdout)


def nodes(value):
    if isinstance(value, dict):
        if 't' in value: yield value
        for item in value.values(): yield from nodes(item)
    elif isinstance(value, list):
        for item in value: yield from nodes(item)


def plain(value):
    if not isinstance(value, dict): return ''
    kind, content = value.get('t'), value.get('c')
    if kind in ('MetaString', 'Str', 'Code'): return content if isinstance(content, str) else content[-1]
    if kind in ('Space', 'SoftBreak', 'LineBreak'): return ' '
    if kind == 'MetaList': return '・'.join(plain(item) for item in content)
    if kind == 'MetaInlines': return ''.join(plain(item) for item in content)
    return ''


def local_target(page, target, root):
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or target.startswith('#'): return None
    decoded = unquote(parsed.path)
    return (root / decoded.lstrip('/') if decoded.startswith('/') else page.parent / decoded).resolve()


def static_document(page, fail, allow_comments=False):
    # Check both the source (Quarto cells/shortcodes) and Pandoc's parsed content,
    # including metadata. This must run for the listing as well as each report.
    source = page.read_text()
    if re.search(r'(?:`{3,}|~{3,})\s*\{', source) or '{{<' in source:
        fail(page, 'static pages cannot use executable/raw cells or shortcodes')
    try: doc = document(page)
    except ValueError as exc:
        fail(page, str(exc)); return None
    for node in nodes(doc):
        kind = node['t']
        if kind == 'Code' and re.match(r'\{[^}]+\}', node['c'][1]):
            fail(page, 'static pages cannot use executable inline code')
        attr = None
        if kind in ('CodeBlock', 'Code', 'Link', 'Image', 'Span', 'Div', 'Table'):
            attr = node['c'][0]
        elif kind == 'Header': attr = node['c'][1]
        if attr and any(key not in ('width', 'height', 'fig-align') for key, _ in attr[2]):
            fail(page, 'static pages cannot use custom HTML attributes')
        if kind in ('RawInline', 'RawBlock') and node['c'][0] in ('html', 'html5'):
            # The listing's editing instructions are an HTML comment. Only
            # complete comments may pass; any surrounding HTML is still rejected.
            if not allow_comments or re.sub(r'<!--.*?-->', '', node['c'][1], flags=re.S).strip():
                fail(page, 'static pages cannot contain raw HTML, scripts or iframe')
        if kind == 'Link' and urlsplit(node['c'][-1][0]).scheme.lower() not in ('', 'http', 'https', 'mailto'):
            fail(page, 'static link scheme is not allowed: ' + node['c'][-1][0])
    return doc


def validate(root):
    root = Path(root).resolve()
    base = root / 'projects/showcase'
    errors = []
    def fail(path, reason): errors.append(f'{path.relative_to(root)}: {reason}')
    if not (base / 'index.qmd').is_file():
        return ['projects/showcase/index.qmd: missing listing']
    if base.is_symlink(): return ['projects/showcase: symlink is not allowed']
    reports = []
    for item in sorted(base.iterdir()):
        if item.is_symlink(): fail(item, 'symlink is not allowed'); continue
        if item.name == 'index.qmd': continue
        if not item.is_dir() or not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', item.name):
            fail(item, 'invalid slug or unexpected file'); continue
        page = item / 'index.qmd'
        reports.append(page.resolve())
        if not page.is_file(): fail(page, 'missing report'); continue
        total = 0
        for file in item.rglob('*'):
            if file.is_symlink(): fail(file, 'symlink is not allowed'); continue
            if file.is_dir(): continue
            if file == page: continue
            if not file.is_relative_to(item / 'assets'):
                fail(file, 'unexpected file; only index.qmd and assets/ images allowed'); continue
            if file.suffix.lower() not in IMAGES: fail(file, 'unsupported image format')
            size = file.stat().st_size
            total += size
            if size > 5 * 1024**2: fail(file, 'image exceeds 5 MiB')
        if total > 10 * 1024**2: fail(page, 'images exceed 10 MiB per report')
        doc = static_document(page, fail)
        if doc is None: continue
        meta = doc['meta']
        if set(meta) != FIELDS or any(not plain(meta.get(key)) for key in FIELDS):
            fail(page, 'metadata must contain only nonempty ' + ', '.join(sorted(FIELDS)))
        repo = plain(meta.get('source-repository'))
        parsed_repo = urlsplit(repo)
        if parsed_repo.scheme != 'https' or not parsed_repo.netloc or parsed_repo.username or parsed_repo.query or parsed_repo.fragment:
            fail(page, 'source-repository must be an HTTPS repository URL')
        reproduction = plain(meta.get('reproduction-url'))
        if not reproduction.startswith(repo.rstrip('/') + '/'):
            fail(page, 'reproduction URL must refer to source-repository')
        if plain(meta.get('license')) != 'CC BY 4.0': fail(page, 'license must be CC BY 4.0')
        images = 0
        back = False
        for node in nodes(doc):
            kind = node['t']
            if kind not in ('Link', 'Image'): continue
            target = node['c'][-1][0]
            destination = local_target(page, target, root)
            if kind == 'Link':
                if destination == (base/'index.qmd').resolve(): back = True
                if destination is not None and not destination.is_file(): fail(page, 'missing link: ' + target)
            else:
                images += 1
                if destination is None or not destination.is_relative_to((item/'assets').resolve()) or Path(urlsplit(target).path).suffix.lower() not in IMAGES:
                    fail(page, 'image must be a local assets/ image: ' + target)
                elif not destination.is_file(): fail(page, 'missing image: ' + target)
                if not node['c'][-2]: fail(page, 'image caption is required: ' + target)
        if not images: fail(page, 'at least one image is required')
        if not back: fail(page, 'back link to ../index.qmd is required')
    listing = static_document(base/'index.qmd', fail, allow_comments=True)
    if listing is not None:
        if set(listing['meta']) != {'title'} or not plain(listing['meta'].get('title')):
            fail(base/'index.qmd', 'listing metadata must contain only a nonempty title')
        links = [local_target(base/'index.qmd', n['c'][-1][0], root) for n in nodes(listing['blocks']) if n['t'] == 'Link']
        listed = [p for p in links if p is not None and p.is_relative_to(base.resolve()) and p != (base/'index.qmd').resolve()]
        if sorted(listed) != sorted(reports): fail(base/'index.qmd', 'listing mismatch: link each report exactly once, with no nonexistent reports')
    return errors


class ResourceLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ('src', 'href', 'poster') and value:
                self.targets.append(value)


def package(site, output, pr, head, rendered):
    site, output = Path(site), Path(output)
    if not SHA.fullmatch(head) or not SHA.fullmatch(rendered): raise ValueError('both SHAs must be 40 lowercase hex characters')
    if not str(pr).isdigit() or int(pr) < 1: raise ValueError('PR number must be positive')
    entry = 'projects/showcase/index.html'
    if not (site/'index.html').is_file() or not (site/entry).is_file(): raise ValueError('rendered HTML is missing; no artifact packaged')
    # Accept only render output, never copy checkout/history or arbitrary files.
    for file in site.rglob('*'):
        if file.is_symlink() or file.name == '.git': raise ValueError('unexpected symlink or Git data in rendered site')
    for html in site.rglob('*.html'):
        links = ResourceLinks()
        links.feed(html.read_text())
        for target in links.targets:
            destination = local_target(html, target, site.resolve())
            if destination is None: continue
            if destination.is_dir(): destination = destination/'index.html'
            if not destination.is_relative_to(site.resolve()) or not destination.is_file():
                raise ValueError(f'{html.relative_to(site)}: missing rendered resource: {target}')
    shutil.copytree(site, output)
    info = dict(pr_number=int(pr), pr_head_sha=head, render_commit_sha=rendered, entry_html=entry)
    (output/'build-info.json').write_text(json.dumps(info, indent=2)+'\n')
    (output/'README.txt').write_text(f'PR #{pr}\nPR HEAD SHA: {head}\nRendered commit SHA: {rendered}\n\nExtract the entire archive before opening {entry}.\nReports: projects/showcase/<slug>/index.html\nKeep site_libs and assets beside the HTML tree. No Quarto needed.\nCheck these SHAs against the latest PR and run before reviewing.\n')
    summary = f'PR #{pr}\n\nPR HEAD SHA: `{head}`\n\nRendered commit SHA: `{rendered}`\n\nHEAD identifies the manuscript; rendered commit may be the synthetic PR merge commit.\n\nDownload the artifact, extract all files, and open `{entry}`.\nReport: `projects/showcase/<slug>/index.html`.\nCompare build-info.json with the latest PR HEAD. Render or packaging failure means no completed display check.\n'
    return summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command', required=True)
    check=sub.add_parser('check'); check.add_argument('root', type=Path)
    pack=sub.add_parser('package')
    for name in ('site','output','pr','head','rendered'): pack.add_argument('--'+name, required=True)
    args=parser.parse_args()
    try:
        if args.command=='check':
            errors=validate(args.root)
            if errors: print('\n'.join(errors), file=sys.stderr); return 1
            print('Showcase structure OK (scientific content, consent and rights require human review).')
        else: print(package(args.site,args.output,args.pr,args.head,args.rendered))
    except (ValueError, OSError) as exc: print(str(exc), file=sys.stderr); return 1
    return 0

if __name__=='__main__': sys.exit(main())
