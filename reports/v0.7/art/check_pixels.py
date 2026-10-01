from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

folder=Path(__file__).resolve().parent
read_image=lambda name:np.asarray(Image.open(folder/(name+'.png')).convert('RGB'))
a,b=read_image('paused-a'),read_image('paused-b')
pause=int(np.any(a!=b,axis=2).sum())
on,off=read_image('slope-details-on'),read_image('slope-details-off')
delta=np.any(on!=off,axis=2)
white=(off.min(axis=2)>190)&(off.max(axis=2)-off.min(axis=2)<40)
result={'pause_changed_pixels':pause,'slope_effect_changed_pixels':int(delta.sum()),'bright_white_changed_pixels':int((delta&white).sum()),'method':'Real paused Main pairs. Effect-off disables only SpatialVisual processing/visibility; white mask RGB min>190 and spread<40. Shows detail paint has visible effect and does not alter bright terrain/HUD pixels in this sampled view; not every possible overlap.'}
gray=[]
for name in ['final-basin-960','final-bridge-960','final-upper-entry-960']:
    Image.open(folder/(name+'.png')).convert('L').save(folder/(name+'-gray.png'))
    gray.append(name+'-gray.png')
result['gray_previews']=gray
root=folder.parents[2]
result['final_art_hashes']={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['scripts/visual/spatial_visual.gd','scripts/visual/endless_module_visual.gd','scripts/visual/route_visual.gd']}
result['passed']=pause==0 and result['slope_effect_changed_pixels']>0 and result['bright_white_changed_pixels']==0
(folder/'pixels-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
raise SystemExit(0 if result['passed'] else 1)
