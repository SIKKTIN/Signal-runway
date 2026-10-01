from pathlib import Path
import json, hashlib, re
import numpy as np
from PIL import Image

folder=Path(__file__).resolve().parent
root=folder.parents[2]
read=lambda name:json.loads((folder/name).read_text(encoding='utf-8-sig'))
natural=read('natural-results.json')
original=folder/'natural-results-original-metadata.json'
if not original.exists():
    original.write_bytes((folder/'natural-results.json').read_bytes())
normal=read('normal-partial.json')
assert [(r['seed'],r['strategy']) for r in normal]==[(404,'primary'),(404,'upper')]
log=(folder/'normal-partial.log').read_text(encoding='utf-8-sig')
checks=[{'check':m.group(1),'passed':m.group(2)=='true'} for m in re.finditer(r'^([^\r\n]+): (true|false)\s*$',log,re.M)]
assert len([r for r in checks if r['check'].startswith('natural_404_')])==8
assert all(r['passed'] for r in checks)
method=('Actual default v4 Main; same-seed API only. BOTH seed404 primary and upper completed with normal wall clock before the own process was stopped for the producer-authorized acceleration. Four remaining cases, seed77/9001 x primary/upper, used fixed60 GPU accelerated game time. Normal original partial JSON and log are preserved, including 8 route checks and actual Esc pause. Final 22-check resumed JSON is not an additional rerun of those 8 checks. Real Player physics with synthetic SPACE/Esc; no position/speed/health/front or elapsed-state injection. Controller uses final geometry; v4 calm connectors may retain relay template IDs. Each strategy reaches beyond first station. Tool/debug fixtures separate. Not human experience.')
natural['method']=method
natural['method_correction']={'normal_completed':2,'accelerated_completed':4,'normal_source':'normal-partial.json + normal-partial.log','normal_checks':checks,'original_metadata_preserved':'natural-results-original-metadata.json','reason':'Both 404 cases completed before stopping PID23468; prior wording was written before inspecting the persisted partial. Only method metadata corrected; route rows and check results unchanged.'}
(folder/'natural-results.json').write_text(json.dumps(natural,ensure_ascii=False,indent=2),encoding='utf-8')
source=folder/'check_routes.gd'
text=source.read_text(encoding='utf-8-sig')
old=re.search(r'"method":"([^"]+)"',text)
assert old
source.write_text(text[:old.start(1)]+method+text[old.end(1):],encoding='utf-8')
a=np.asarray(Image.open(folder/'natural-pause-a.png'))
b=np.asarray(Image.open(folder/'natural-pause-b.png'))
assert a.shape==b.shape
pause_diff=int(np.any(a!=b,axis=2).sum())
gray=[]
for name in ['natural-404-completed-960','natural-404-upper-station-selected','tool-selected-start-visibility']:
    Image.open(folder/(name+'.png')).convert('L').save(folder/(name+'-gray.png'))
    gray.append(name+'-gray.png')
manifest=json.loads((root/'reports/v0.6/version-manifest.json').read_text(encoding='utf-8-sig'))
mismatch=[]
for row in manifest['files']:
    if hashlib.sha256((root/row['path']).read_bytes()).hexdigest()!=row['sha256']:
        mismatch.append(row['path'])
result={'version':manifest['version'],'production_files':len(manifest['files']),'mismatches':mismatch,'pause_changed_pixels':pause_diff,'gray_previews':gray,'passed':pause_diff==0 and not mismatch,'normal_log_route_checks':8,'normal_log_pause':any(r['check']=='actual_Escape_preserves_active_challenge' and r['passed'] for r in checks),'method_corrected_without_new_routes':True}
(folder/'pixels-and-sources.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
