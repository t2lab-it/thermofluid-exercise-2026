"""Protect copied commands from prompts/output and preserve continuation lines."""
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CodeBlocks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.blocks = []
        self.commands = []
        self.div_classes = []
        self.current = None

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            self.div_classes.append(dict(attrs).get('class', '').split())
        if tag == 'code':
            self.current = ''

    def handle_data(self, data):
        if self.current is not None:
            self.current += data

    def handle_endtag(self, tag):
        if tag == 'code' and self.current is not None:
            self.blocks.append(self.current)
            if any('console-input' in classes for classes in self.div_classes):
                self.commands.append(self.current)
            self.current = None
        if tag == 'div':
            self.div_classes.pop()


def render(source, commands_only=False):
    command = ['quarto', 'pandoc', '--from=markdown', '--to=html', '--no-highlight']
    filter_path = ROOT / 'filters' / 'console-examples.lua'
    command += ['--lua-filter', str(filter_path)]
    result = subprocess.run(command, input=source, text=True, capture_output=True, check=True)
    parser = CodeBlocks()
    parser.feed(result.stdout)
    return parser.commands if commands_only else parser.blocks


class ConsoleExamplesTest(unittest.TestCase):
    def test_shell_copy_excludes_output_and_keeps_literal_dollar_and_continuation(self):
        blocks = render('''```console
$ printf '%s\\n' "$HOME" \\
>   'julia> literal'
/home/student
julia> literal

$ git status --short
```
''')
        self.assertEqual(blocks, ['printf \'%s\\n\' "$HOME" \\\n  \'julia> literal\'',
                                  '/home/student\njulia> literal', 'git status --short'])

    def test_julia_copy_preserves_multiline_indentation_and_blank_lines(self):
        blocks = render('''```julia-repl
julia> function twice(x)
           y = 2 * x

           return y
       end
twice (generic function with 1 method)

julia> twice(3)
6
```
''')
        self.assertEqual(blocks, ['function twice(x)\n    y = 2 * x\n\n    return y\nend',
                                  'twice (generic function with 1 method)', 'twice(3)', '6'])

    def test_saved_source_is_not_reinterpreted_as_a_transcript(self):
        self.assertEqual(render('```julia\nprintln("julia> literal")\n```'),
                         ['println("julia> literal")'])

    def test_n0506_stages_copy_as_independent_commands(self):
        source = (ROOT / 'guides' / 'workflow.qmd').read_text()
        blocks = render(source)
        base = 'julia --project=. exercises/N05-N06_common_package_2d_advection/'
        for tail in ('N05.jl baseline', 'N05.jl verify', 'simulate.jl', 'analyze.jl', 'plot.jl', 'run.jl', 'tests.jl'):
            self.assertIn(base + tail, blocks)

    def test_n08_commands_select_only_n08(self):
        blocks = render((ROOT / 'guides' / 'workflow.qmd').read_text())
        base = 'julia --project=. exercises/N08-N09_laplace_poisson/'
        for stage in ('simulate', 'analyze', 'plot', 'run'):
            self.assertIn(base + stage + '.jl N08', blocks)
            self.assertIn(base + stage + '.jl all', blocks)
        self.assertIn(base + 'tests.jl N08-check', blocks)

    def test_worktree_steps_copy_as_commands_without_prompts_or_output(self):
        source = (ROOT / 'advanced' / 'git-worktree.qmd').read_text()
        commands = render(source, commands_only=True)
        for command in (
            'git worktree add -b experiment/N01-comparison ../YOUR_COURSE_REPOSITORY-compare SOURCE_BRANCH',
            'cd ../YOUR_COURSE_REPOSITORY-compare',
            'pwd',
            'git rev-parse --show-toplevel',
            'git branch --show-current',
            'git status --short',
            'git worktree list',
            'git diff SOURCE_BRANCH...experiment/N01-comparison',
            'cd ../YOUR_COURSE_REPOSITORY',
            'git merge --ff-only experiment/N01-comparison',
            'git status --short --ignored',
            'git worktree remove ../YOUR_COURSE_REPOSITORY-compare',
        ):
            self.assertIn(command, commands)
        self.assertTrue(commands)
        for command in commands:
            self.assertEqual(len(command.splitlines()), 1)
            self.assertFalse(command.startswith(('$ ', '> ')))
            self.assertNotIn('（', command)
            self.assertNotIn('Preparing worktree', command)


if __name__ == '__main__':
    unittest.main()
