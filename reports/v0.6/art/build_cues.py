from pathlib import Path
import wave
import math
import json
import struct
import hashlib

root = Path(__file__).resolve().parents[3]
target = root/'assets/audio/v06'
target.mkdir(parents=True,exist_ok=True)
result = []
for name,duration,pitches in [('complete',.19,(660,880)),('recover',.17,(480,720))]:
    count = round(48000*duration)
    values = []
    for i in range(count):
        t = i/48000
        envelope = min(1,t/.012)*min(1,(duration-t)/.025)*math.exp(-t*9)
        frequency = pitches[0] if t<duration*.48 else pitches[1]
        values.append(math.sin(2*math.pi*frequency*t)*envelope)
    scale = 32767*10**(-14/20)/max(abs(v) for v in values)
    pcm = [round(v*scale) for v in values]
    path = target/(name+'.wav')
    with wave.open(str(path),'wb') as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(48000)
        sound.writeframes(struct.pack('<'+'h'*len(pcm),*pcm))
    result.append({'path':str(path.relative_to(root)),'duration':duration,'sample_rate':48000,'channels':1,'peak_dbfs':20*math.log10(max(abs(v) for v in pcm)/32768),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(Path(__file__).parent/'audio-assets.json').write_text(json.dumps({'resources':result,'scope':'Synthetic PCM metrics only, not subjective listening.'},indent=2),encoding='utf-8')
print(json.dumps(result))
