

import ast
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
TRANSLATIONS_DIR = PROJECT_ROOT / "src" / "gui" / "translations"

QML_DIRS = [
    PROJECT_ROOT / "src" / "gui" / "qml",
    PROJECT_ROOT / "src" / "gui" / "components",
]

PYTHON_FILES = [
    PROJECT_ROOT / "src" / "gui" / "main_qml.py",
    *sorted((PROJECT_ROOT / "src" / "gui" / "connectors").glob("*.py")),
    *sorted((PROJECT_ROOT / "src" / "gui" / "backend").glob("*.py")),
]

RUNTIME_CONTEXT = "Application"

def save_python_translations(ts_path: Path, python_sources: dict[str, set[str]]) -> dict[str, dict[str, str]]:
    
    saved: dict[str, dict[str, str]] = {}

    source_to_class: dict[str, str] = {}
    for class_name, sources in python_sources.items():
        for src in sources:
            source_to_class[src] = class_name

    try:
        tree = ET.parse(ts_path)
    except ET.ParseError:
        return saved

    root = tree.getroot()
    for ctx in root.findall("context"):
        for msg in ctx.findall("message"):
            source = msg.findtext("source", "")
            if source not in source_to_class:
                continue
            trans_elem = msg.find("translation")
            if trans_elem is not None and trans_elem.text:
                class_name = source_to_class[source]
                saved.setdefault(class_name, {})[source] = trans_elem.text

    return saved

def run_lupdate(ts_files: list[Path]):
    
    cmd = ["lupdate"]
    for d in QML_DIRS:
        cmd.append(str(d))
    cmd.append("-ts")
    for f in ts_files:
        cmd.append(str(f))

    print("Running lupdate for QML...")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  lupdate failed:\n{result.stderr}")
        sys.exit(1)

    for line in result.stderr.splitlines():
        if line.strip():
            print(f"  {line.strip()}")
    print()

def extract_tr_calls(py_path: Path) -> dict[str, list[tuple[str, int]]]:
    source = py_path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(py_path))

    results: dict[str, list[tuple[str, int]]] = {}

    for node in ast.walk(tree):
        if not isinstance(node, ast.ClassDef):
            continue
        class_name = node.name
        strings: list[tuple[str, int]] = []

        for child in ast.walk(node):
            if (
                isinstance(child, ast.Call)
                and isinstance(child.func, ast.Attribute)
                and child.func.attr == "tr"
                and isinstance(child.func.value, ast.Name)
                and child.func.value.id == "self"
                and child.args
                and isinstance(child.args[0], ast.Constant)
            ):
                value = child.args[0].value
                if isinstance(value, str):
                    strings.append((value, child.lineno))

        if strings:
            results[class_name] = strings

    return results

def get_relative_path(py_path: Path) -> str:
    return str(py_path.relative_to(TRANSLATIONS_DIR.parent)).replace("\\", "/")

def inject_python_entries(ts_path: Path, saved_translations: dict[str, dict[str, str]]) -> int:

    all_strings: list[tuple[str, str, int]] = []
    for py_file in PYTHON_FILES:
        if not py_file.exists():
            continue
        rel_path = get_relative_path(py_file)
        for class_name, strings in extract_tr_calls(py_file).items():
            for source_str, lineno in strings:
                all_strings.append((source_str, rel_path, lineno))

    if not all_strings:
        return 0

    tree = ET.parse(ts_path)
    root = tree.getroot()

    existing_sources: set[str] = set()
    ctx_elem = None
    for ctx in root.findall("context"):
        if ctx.findtext("name", "") == RUNTIME_CONTEXT:
            ctx_elem = ctx
            existing_sources = {msg.findtext("source", "") for msg in ctx.findall("message")}
            break

    if ctx_elem is None:
        ctx_elem = ET.SubElement(root, "context")
        name_elem = ET.SubElement(ctx_elem, "name")
        name_elem.text = RUNTIME_CONTEXT

    all_saved: dict[str, str] = {}
    for class_translations in saved_translations.values():
        all_saved.update(class_translations)

    added = 0
    restored = 0
    seen: set[str] = set()
    for source_str, rel_path, lineno in all_strings:
        if source_str in existing_sources or source_str in seen:
            continue
        seen.add(source_str)

        msg = ET.SubElement(ctx_elem, "message")
        loc = ET.SubElement(msg, "location")
        loc.set("filename", "../" + rel_path)
        loc.set("line", str(lineno))
        src = ET.SubElement(msg, "source")
        src.text = source_str
        trans = ET.SubElement(msg, "translation")

        if source_str in all_saved:
            trans.text = all_saved[source_str]
            restored += 1
        else:
            trans.set("type", "unfinished")
            trans.text = ""

        added += 1

    if added > 0:
        ET.indent(tree, space="    ")
        tree.write(ts_path, encoding="utf-8", xml_declaration=True)

        text = ts_path.read_text(encoding="utf-8")
        text = text.replace(
            '<?xml version=\'1.0\' encoding=\'utf-8\'?>',
            '<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>',
        )
        ts_path.write_text(text, encoding="utf-8")

    return added, restored

def remove_obsolete_python(ts_path: Path, python_source_strings: set[str], python_class_names: set[str]) -> int:
    
    tree = ET.parse(ts_path)
    root = tree.getroot()

    removed = 0

    for ctx in root.findall("context"):
        to_remove = []
        for msg in ctx.findall("message"):
            trans_elem = msg.find("translation")
            if trans_elem is not None and trans_elem.get("type") in ("obsolete", "vanished"):
                source = msg.findtext("source", "")
                if source in python_source_strings:
                    to_remove.append(msg)
        for msg in to_remove:
            ctx.remove(msg)
            removed += 1

    contexts_to_remove = []
    for ctx in root.findall("context"):
        name = ctx.findtext("name", "")
        if name in python_class_names and name != RUNTIME_CONTEXT:
            contexts_to_remove.append(ctx)
    for ctx in contexts_to_remove:
        root.remove(ctx)
        removed += 1

    if removed > 0:
        ET.indent(tree, space="    ")
        tree.write(ts_path, encoding="utf-8", xml_declaration=True)
        text = ts_path.read_text(encoding="utf-8")
        text = text.replace(
            '<?xml version=\'1.0\' encoding=\'utf-8\'?>',
            '<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>',
        )
        ts_path.write_text(text, encoding="utf-8")

    return removed

def count_translations(ts_path: Path) -> tuple[int, int, int]:
    tree = ET.parse(ts_path)
    root = tree.getroot()

    total = 0
    done = 0
    for ctx in root.findall("context"):
        for msg in ctx.findall("message"):
            trans = msg.find("translation")
            if trans is None:
                continue
            total += 1
            if trans.get("type") not in ("unfinished", "obsolete", "vanished") and trans.text:
                done += 1

    return total, done, total - done

def fix_xml_formatting(ts_path: Path) -> int:
    
    text = ts_path.read_text(encoding="utf-8")

    text = re.sub(
        r'<translation type="unfinished"\s*/>',
        '<translation type="unfinished"></translation>',
        text,
    )

    text, count = re.subn(
        r'<translation type="unfinished">([^<]+)</translation>',
        r"<translation>\1</translation>",
        text,
    )

    ts_path.write_text(text, encoding="utf-8")
    return count

def main():
    ts_files = sorted(TRANSLATIONS_DIR.glob("*.ts"))
    if not ts_files:
        print("No .ts files found in", TRANSLATIONS_DIR)
        sys.exit(1)

    python_sources: dict[str, set[str]] = {}
    for py_file in PYTHON_FILES:
        if not py_file.exists():
            continue
        for class_name, strings in extract_tr_calls(py_file).items():
            python_sources.setdefault(class_name, set()).update(s for s, _ in strings)

    saved_per_file: dict[str, dict[str, dict[str, str]]] = {}
    for ts_file in ts_files:
        saved_per_file[ts_file.name] = save_python_translations(ts_file, python_sources)

    all_python_strings = set()
    for sources in python_sources.values():
        all_python_strings.update(sources)
    python_class_names = set(python_sources.keys())

    run_lupdate(ts_files)

    print("Processing translation files...\n")
    for ts_file in ts_files:
        saved = saved_per_file.get(ts_file.name, {})
        print(f"  {ts_file.name}:")

        removed = remove_obsolete_python(ts_file, all_python_strings, python_class_names)
        if removed:
            print(f"    - {removed} obsolete Python entries cleaned up")

        added, restored = inject_python_entries(ts_file, saved)
        if added:
            msg = f"    + {added} Python entries added"
            if restored:
                msg += f" ({restored} translations restored)"
            print(msg)
        else:
            print(f"    Python entries: up to date")

        fixed = fix_xml_formatting(ts_file)
        if fixed:
            print(f"    ~ {fixed} entries marked as finished")
        else:
            print(f"    Unfinished: nothing to fix")
        print()

    print("=" * 50)
    print("Translation Summary")
    print("=" * 50)
    for ts_file in ts_files:
        total, done, remaining = count_translations(ts_file)
        pct = (done / total * 100) if total > 0 else 0
        print(f"  {ts_file.stem}:")
        print(f"    Total: {total}  Done: {done}  Remaining: {remaining}  ({pct:.1f}%)")
    print()
    print("Done!")

if __name__ == "__main__":
    main()
