# Flags PHP syntax and functions newer than PHP 5.4 (Mercury runs PHP 5.x).
#   python backend/tests/php54_check.py
# A static scan, not a real PHP 5.4 run: comments and strings are blanked
# out first, so only code is checked.
import re
import sys
from pathlib import Path

API = Path(__file__).resolve().parent.parent / 'api'

CHECKS = [
    (r'\?\?', '?? operator (PHP 7.0)'),
    (r'\?->', 'nullsafe ?-> (PHP 8.0)'),
    (r'\bfn\s*\(', 'arrow function (PHP 7.4)'),
    (r'\.\.\.', 'spread / variadics (PHP 5.6)'),
    (r'\bfunction\s*\w*\s*\([^)]*\)\s*:\s*\??\w+', 'return type (PHP 7.0)'),
    (r'\bfunction\s*\w*\s*\([^)]*\b(int|string|bool|float|iterable|mixed|object)\s+\$', 'scalar type hint (PHP 7.0)'),
    (r'\?\s*(array|int|string|bool|float)\s+\$', 'nullable type (PHP 7.1)'),
    (r'(public|private|protected)\s+(array|int|string|bool|float|\?\w+)\s+\$', 'typed property (PHP 7.4)'),
    (r'^\s*const\s+\w+\s*=\s*\[', 'array constant (PHP 5.6)'),
    (r'^\s*const\s+\w+\s*=\s*[^;]*([+*/.]|__DIR__)', 'constant expression (PHP 5.6)'),
    (r'::class\b', '::class (PHP 5.5)'),
    (r'\bfinally\b', 'finally (PHP 5.5)'),
    (r'\*\*', '** operator (PHP 5.6)'),
    (r'<=>', 'spaceship (PHP 7.0)'),
    (r'\bmatch\s*\(', 'match (PHP 8.0)'),
    (r'\byield\b', 'generators (PHP 5.5)'),
    (r'catch\s*\([^)]*\|', 'multi-catch (PHP 7.1)'),
    (r'\b(Throwable|Error)\b(?=\s*\$)', 'Throwable / Error (PHP 7.0)'),
    (r'^\s*\[\s*\$\w+', '[$a, $b] = destructuring (PHP 7.1)'),
    (r'\bas\s*\[', 'foreach (... as [$a, $b]) destructuring (PHP 7.1)'),
    (r'\bas\s+list\s*\(', 'foreach (... as list()) (PHP 5.5)'),
    (r'\blist\s*\(\s*\'', 'list() with keys (PHP 7.1)'),
    (r'\bnew\s+class\b', 'anonymous class (PHP 7.0)'),
    (r'\b(empty|isset)\s*\([^)$]*\w\(', 'isset/empty on an expression (PHP 5.5)'),
    (r',\s*\)', 'trailing comma in a call or signature (PHP 7.3)'),
    (r'\b(random_bytes|random_int|array_column|intdiv|array_key_first|array_key_last|'
     r'str_contains|str_starts_with|str_ends_with|hash_equals|array_is_list|'
     r'password_needs_rehash|boolval)\s*\(', 'function newer than PHP 5.4'),
]
# Defined by our own polyfills, so allowed even though they are newer
POLYFILLED = re.compile(r'function_exists\(\s*\'(random_bytes|password_hash|mb_strlen)\'')


def code_only(src):
    """Blanks comments and string contents, keeping line numbers."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i) or c == '#':
            j = src.find('\n', i)
            j = n if j == -1 else j
            out.append(' ' * (j - i)); i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2); j = n if j == -1 else j + 2
            out.append(re.sub(r'[^\n]', ' ', src[i:j])); i = j
        elif c in '\'"':
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == '\\' else 1
            out.append(c + re.sub(r'[^\n]', ' ', src[i + 1:j]) + c); i = j + 1
        else:
            out.append(c); i += 1
    return ''.join(out)


def nested_functions(code):
    """Line numbers of named functions declared inside another block
    (valid PHP, but they only exist after the outer code runs)."""
    found, depth = [], 0
    # class methods carry public/private/protected, so they are not counted
    for m in re.finditer(r'(?<!public )(?<!private )(?<!protected )\bfunction\s+(\w+)\s*\(|[{}]', code):
        token = m.group(0)
        if token == '{':
            depth += 1
        elif token == '}':
            depth -= 1
        elif depth > 0 and not re.search(r'\bif\s*\(\s*!\s*function_exists', code[max(0, m.start() - 300):m.start()]):
            found.append(code.count('\n', 0, m.start()) + 1)
    return found


problems = 0
for path in sorted(API.rglob('*.php')):
    code = code_only(path.read_text(encoding='utf-8'))
    for line in nested_functions(code):
        problems += 1
        print(f'{path.relative_to(API.parent)}:{line}: function declared inside another block')
    for pattern, why in CHECKS:
        for m in re.finditer(pattern, code, re.M):
            line = code.count('\n', 0, m.start()) + 1
            lines = path.read_text(encoding='utf-8').splitlines()
            text = lines[line - 1].strip()
            # a call guarded by function_exists() on the line above is fine
            if 'function newer' in why and POLYFILLED.search(lines[line - 2] if line > 1 else ''):
                continue
            problems += 1
            print(f'{path.relative_to(API.parent)}:{line}: {why}\n    {text}')

print(f'\n{problems} PHP 5.4 problem(s) found')
sys.exit(1 if problems else 0)
