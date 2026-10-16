"""Exercise report validation and portable packaging against temporary trees."""
import importlib.util
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('showcase', ROOT / 'scripts/project_showcase.py')
showcase = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(showcase)
SHA = 'a' * 40
REPORT = '''---
title: "熱拡散の格子比較"
author: ["表示名 A", "表示名 B"]
description: "解析解と格子幅の影響を比較する。"
source-repository: "https://github.com/example/heat"
source-sha: "SOURCE_SHA"
reproduction-url: "https://github.com/example/heat/blob/SOURCE_SHA/README.md"
license: "CC BY 4.0"
---

## 問いと方法

周期熱拡散の誤差を比較する。
$u_t=\\alpha u_{xx}$ とし，$\\alpha=1$，周期境界，$u(x,0)=\\sin x$を用いる。

![時刻1での格子幅と誤差。横軸は格子幅，縦軸は最大誤差。](assets/result.png)

解析解と照合し，格子を細かくすると誤差が減った。
時間刻みの影響は未確認である。
[再現手順](https://github.com/example/heat/blob/SOURCE_SHA/README.md)と
[成果紹介の一覧](../index.qmd)を参照。
'''.replace('SOURCE_SHA', SHA)


def fixture(root, report=True):
    base = root / 'projects/showcase'
    base.mkdir(parents=True)
    (base / 'index.qmd').write_text('---\ntitle: 成果紹介\n---\n\n[投稿案内](../../assignments/project-showcase.qmd)\n')
    (root / 'assignments').mkdir()
    (root / 'assignments/project-showcase.qmd').write_text('---\ntitle: 投稿\n---\n\n案内\n')
    if report:
        page = base / 'heat-check/index.qmd'
        page.parent.mkdir()
        page.write_text(REPORT)
        (page.parent / 'assets').mkdir()
        # Actual PNG: rendering fixture is shared with visual verification.
        import base64
        (page.parent / 'assets/result.png').write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1sAAAAASUVORK5CYII='))
        with (base / 'index.qmd').open('a') as f:
            f.write('\n- [熱拡散の格子比較](heat-check/index.qmd) — 表示名 A・表示名 B：格子比較。\n')
    return base


class ReportContracts(unittest.TestCase):
    def check_damage(self, damage, reason):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            base = fixture(root)
            damage(root, base, base / 'heat-check/index.qmd')
            errors = showcase.validate(root)
            self.assertTrue(any(reason in error for error in errors), errors)
            self.assertTrue(all('projects/showcase' in error for error in errors), errors)

    def test_empty_and_single_report(self):
        for report in (False, True):
            with self.subTest(report=report), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                fixture(root, report)
                self.assertEqual(showcase.validate(root), [])

    def test_broken_references(self):
        cases = [
            (lambda r,b,p: (p.parent/'assets/result.png').unlink(), 'missing image'),
            (lambda r,b,p: p.write_text(p.read_text()+'\n[欠落](missing.qmd)\n'), 'missing link'),
            (lambda r,b,p: (b/'index.qmd').write_text('---\ntitle: list\n---\n'), 'listing mismatch'),
            (lambda r,b,p: (b/'index.qmd').write_text((b/'index.qmd').read_text()+'\n[ghost](ghost/index.qmd)'), 'listing mismatch'),
            (lambda r,b,p: p.write_text(p.read_text().replace(SHA, 'abc123')), '40 lowercase hex'),
            (lambda r,b,p: p.write_text(p.read_text().replace('/blob/'+SHA, '/blob/main')), 'pinned reproduction'),
            (lambda r,b,p: p.write_text(p.read_text().replace('[成果紹介の一覧](../index.qmd)', '一覧')), 'back link'),
        ]
        for damage, reason in cases:
            with self.subTest(reason=reason): self.check_damage(damage, reason)

    def test_static_only_and_file_boundary(self):
        additions = ['\n```{julia}\nerror("executed")\n```\n', '\n~~~{python}\nprint(1)\n~~~\n', '\n> ```{julia}\n> error(1)\n> ```', '\n<script>alert(1)</script>', '\n<iframe src="x"></iframe>', '\n{{< include other.qmd >}}', '\n```{=html}\n<img src=x onerror=x>\n```']
        for addition in additions:
            with self.subTest(addition=addition):
                self.check_damage(lambda r,b,p: p.write_text(p.read_text()+addition), 'static')
        for inline in ('`{julia} error("executed")`', '`{python} print(1)`'):
            with self.subTest(inline=inline):
                self.check_damage(lambda r,b,p: p.write_text(p.read_text()+'\n'+inline), 'static')
        self.check_damage(lambda r,b,p: p.write_text(p.read_text().replace('license:', 'filters: [evil.lua]\nlicense:')), 'metadata')
        self.check_damage(lambda r,b,p: p.write_text(p.read_text().replace('熱拡散の格子比較', '<script>alert(1)</script>')), 'static')
        self.check_damage(lambda r,b,p: p.write_text(p.read_text()+'\n[click](https://example.com){onclick=alert(1)}'), 'static')
        self.check_damage(lambda r,b,p: (p.parent/'_metadata.yml').write_text('filters: evil.lua'), 'unexpected file')
        self.check_damage(lambda r,b,p: (p.parent/'assets/data.csv').write_text('large data'), 'image format')
        self.check_damage(lambda r,b,p: (p.parent/'assets/escape.png').symlink_to('/etc/passwd'), 'symlink')
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); base=fixture(root); p=base/'heat-check/index.qmd'
            p.write_text(p.read_text()+'\n```julia\nx = 1\n```\n')
            self.assertEqual(showcase.validate(root), [])

    def test_size_boundaries(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); base=fixture(root); assets=base/'heat-check/assets'
            for name in ('result.png','second.png'):
                with (assets/name).open('wb') as f: f.truncate(5*1024*1024)
            self.assertEqual(showcase.validate(root), [])
            (assets/'third.png').write_bytes(b'x')
            self.assertTrue(any('10 MiB' in e for e in showcase.validate(root)))
            with (assets/'result.png').open('ab') as f: f.write(b'x')
            self.assertTrue(any('5 MiB' in e for e in showcase.validate(root)))

    def test_invalid_slug(self):
        self.check_damage(lambda r,b,p: p.parent.rename(b/'Bad_slug'), 'slug')


class ArtifactContracts(unittest.TestCase):
    def test_package_and_sha_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); site=root/'site'; site.mkdir()
            (site/'index.html').write_text('<a href="projects/showcase/index.html">list</a>')
            (site/'projects/showcase').mkdir(parents=True)
            (site/'projects/showcase/index.html').write_text('<p>empty</p>')
            (site/'site_libs').mkdir(); (site/'site_libs/style.css').write_text('body{}')
            output=root/'artifact'
            showcase.package(site, output, '42', SHA, 'b'*40)
            info=json.loads((output/'build-info.json').read_text())
            self.assertEqual(info, {'pr_number':42,'pr_head_sha':SHA,'render_commit_sha':'b'*40,'entry_html':'projects/showcase/index.html'})
            self.assertTrue((output/'site_libs/style.css').is_file())
            self.assertIn(SHA, (output/'README.txt').read_text())
            self.assertFalse((output/'.git').exists())
            with self.assertRaises(ValueError): showcase.package(site, root/'bad', '42', 'short', 'b'*40)
            (site/'projects/showcase/index.html').write_text('<img src="heat/assets/missing.png">')
            with self.assertRaisesRegex(ValueError, 'missing rendered resource'):
                showcase.package(site, root/'bad-resource', '42', SHA, 'b'*40)
            (site/'projects/showcase/index.html').unlink()
            with self.assertRaises(ValueError): showcase.package(site, root/'missing', '42', SHA, 'b'*40)


if __name__ == '__main__': unittest.main()
