from pathlib import Path
import hashlib
import json
import difflib

folder = Path(__file__).resolve().parent
root = folder.parents[3]
old = json.loads((root/'reports/v0.5/history/g-candidate-manifest.json').read_text(encoding='utf-8-sig'))
new = json.loads((root/'reports/v0.5/version-manifest.json').read_text(encoding='utf-8-sig'))
old_rows = {row['path']:row['sha256'] for row in old['files']}
new_rows = {row['path']:row['sha256'] for row in new['files']}
changed = [p for p in new_rows if old_rows.get(p) != new_rows[p]]
mismatches = [p for p in new_rows if hashlib.sha256((root/p).read_bytes()).hexdigest() != new_rows[p]]
historical_mismatches = []
diffs = []
for p in changed:
    archived = root/'reports/v0.5/history'/Path(p).name
    if hashlib.sha256(archived.read_bytes()).hexdigest() != old_rows[p]:
        historical_mismatches.append(p)
    diffs.extend(difflib.unified_diff(archived.read_text(encoding='utf-8-sig').splitlines(),
                                    (root/p).read_text(encoding='utf-8-sig').splitlines(),
                                    fromfile=old['version']+'/'+p,tofile=new['version']+'/'+p,lineterm=''))
expected = {'scripts/level/vertical_library.gd','scripts/visual/endless_module_visual.gd'}
result = {'old_version':old['version'],'new_version':new['version'],
          'old_count':len(old_rows),'new_count':len(new_rows),
          'changed_files':changed,'current_mismatches':mismatches,
          'archived_old_mismatches':historical_mismatches,
          'passed':set(old_rows)==set(new_rows) and set(changed)==expected and not mismatches and not historical_mismatches}
(folder/'source-difference.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
(folder/'source-difference.diff').write_text('\n'.join(diffs)+'\n',encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
