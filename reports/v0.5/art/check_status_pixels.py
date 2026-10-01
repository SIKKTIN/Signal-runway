from pathlib import Path
import hashlib
import json
import wave
import math
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
root = folder.parents[2]
a = np.asarray(Image.open(folder / 'status-paused-a.png').convert('RGB'))
b = np.asarray(Image.open(folder / 'status-paused-b.png').convert('RGB'))
pause = int(np.count_nonzero(np.any(a != b,axis=2)))
for name in ['status-full-1280','status-hurt-1280','status-low-1280','status-hurt-960']:
    Image.open(folder/(name+'.png')).convert('L').save(folder/(name+'-gray.png'))
resources = []
for name, size in [('platform_cap',(128,16)),('ground_side',(64,64)),('route_upper',(80,28))]:
    node = ET.parse(root/f'assets/visual/v05/{name}.svg').getroot()
    resources.append({'path':f'assets/visual/v05/{name}.svg','size':[int(node.attrib['width']),int(node.attrib['height'])],'passed':tuple(map(int,(node.attrib['width'],node.attrib['height'])))==size})
with wave.open(str(root/'assets/audio/v05/hurt_tick.wav'),'rb') as stream:
    samples = np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').astype(float)
    audio = {'duration':len(samples)/stream.getframerate(),'channels':stream.getnchannels(),'sample_rate':stream.getframerate(),'peak_dbfs':20*math.log10(max(abs(samples))/32768)}
sources = ['scenes/ui/v05_status.gd','scenes/ui/v05_status.tscn'] + [r['path'] for r in resources] + ['assets/audio/v05/hurt_tick.wav']
result = {'pause_changed_pixels':pause,'svg_resources':resources,'audio_technical':audio,'passed':pause==0 and all(r['passed'] for r in resources),'sources':[{'path':p,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in sources],'scope':'Standalone preparation; audio numeric analysis only, not listening/production trigger proof.'}
(folder/'status-pixels.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
