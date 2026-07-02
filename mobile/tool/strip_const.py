import re
from pathlib import Path

root = Path(r"C:\Users\XOS\Projects\alpaca-options-app\mobile\lib")

def strip_const(text: str) -> str:
    # Remove const when expression references AppColors or S.
    def needs_strip(expr: str) -> bool:
        return "AppColors." in expr or "S." in expr

    # Iteratively strip const prefix from widget expressions
    pattern = re.compile(
        r"\bconst\s+("
        r"Text\((?:[^()]*|\([^()]*\))*\)|"
        r"Icon\((?:[^()]*|\([^()]*\))*\)|"
        r"Divider\((?:[^()]*|\([^()]*\))*\)|"
        r"VerticalDivider\((?:[^()]*|\([^()]*\))*\)|"
        r"SnackBar\((?:[^()]*|\([^()]*\))*\)|"
        r"InputDecoration\((?:[^()]*|\([^()]*\))*\)|"
        r"OkxSectionHeader\((?:[^()]*|\([^()]*\))*\)|"
        r"BorderSide\((?:[^()]*|\([^()]*\))*\)|"
        r"Center\(child: Text\((?:[^()]*|\([^()]*\))*\)\)|"
        r"Padding\(\s*padding:[^,]+,\s*child: (?:Center\(child: )?Text\((?:[^()]*|\([^()]*\))*\)(?:\))?\)"
        r")",
        re.DOTALL,
    )

    prev = None
    while prev != text:
        prev = text

        def repl(m: re.Match) -> str:
            expr = m.group(1)
            return expr if needs_strip(expr) else m.group(0)

        text = pattern.sub(repl, text)

    text = re.sub(
        r"style:\s*const\s+(TextStyle\([^)]*AppColors[^)]*\))",
        r"style: \1",
        text,
    )
    text = re.sub(
        r"decoration:\s*const\s+(InputDecoration\([^)]*S\.[^)]*\))",
        r"decoration: \1",
        text,
    )
    text = re.sub(
        r"\(_, __\)\s*=>\s*const\s+(Padding\()",
        r"(_, __) => \1",
        text,
    )
    text = text.replace(
        "static const _labelStyle = TextStyle(color: AppColors",
        "static final _labelStyle = TextStyle(color: AppColors",
    )
    text = text.replace(
        "static const _priceLabelStyle = TextStyle(color: AppColors",
        "static final _priceLabelStyle = TextStyle(color: AppColors",
    )
    return text

for f in root.rglob("*.dart"):
    original = f.read_text(encoding="utf-8")
    updated = strip_const(original)
    if updated != original:
        f.write_text(updated, encoding="utf-8")
        print("updated", f.relative_to(root))

print("done")
