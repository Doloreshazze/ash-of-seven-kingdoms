"""Rebuild reproducible, original icon and synthesized audio effects.
Artwork forest background is from the project creator's generated art asset.
Run with Python 3 + Pillow + NumPy (only needed when changing assets).
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, wave, math
from pathlib import Path
root = Path(__file__).resolve().parent
art = root / 'art'
audio = root / 'audio'

# Foliage-colored fantasy rune / broken crown icon.
img = Image.open(art / 'emerald_forest.png').convert('RGB')
width,height=img.size
img = img.crop((0, max(0,height//5), min(width,width*3//4), min(height,height*4//5))).resize((512,512),Image.Resampling.LANCZOS)
arr=np.asarray(img).astype(np.float32)
arr[:,:,0]*=0.45; arr[:,:,1]*=0.52; arr[:,:,2]*=0.68
img=Image.fromarray(np.uint8(np.clip(arr,0,255)))
glow=Image.new('RGBA',(512,512),(0,0,0,0))
d=ImageDraw.Draw(glow)
for radius in range(207,135,-6):
    alpha=int(38*(207-radius)/72)
    d.ellipse((256-radius,256-radius,256+radius,256+radius),outline=(242,167,73,alpha),width=8)
glow=glow.filter(ImageFilter.GaussianBlur(17))
base=img.convert('RGBA');base=Image.alpha_composite(base,glow)
d=ImageDraw.Draw(base)
for rad,width,alpha in [(205,12,210),(176,3,230),(160,4,190)]:
    d.arc((256-rad,256-rad,256+rad,256+rad),15,325,fill=(241,171,75,alpha),width=width)
    d.arc((256-rad,256-rad,256+rad,256+rad),345,355,fill=(241,171,75,alpha),width=width)
# Gold stylized dragon curled around a flaming heart.
d.polygon([(150,320),(172,233),(217,207),(245,144),(261,203),(301,156),(292,248),(354,202),(336,293),(301,332),(258,358),(221,336),(189,386),(200,331)],fill=(12,24,35,240))
d.line([(151,319),(174,229),(222,207),(246,155),(258,218),(299,170),(291,257),(350,212),(332,289),(298,333),(258,353),(219,334),(188,380)],fill=(255,192,95,255),width=11,joint='curve')
d.ellipse((248,238,294,284),fill=(238,117,52,220))
d.ellipse((258,248,283,272),fill=(255,235,151,255))
base.convert('RGB').save(art/'icon.png', optimize=True)

sample_rate=22050

def wav(name, samples):
    samples=np.asarray(samples,dtype=np.float64)
    samples=np.clip(samples,-0.98,0.98)
    wave_out=np.int16(samples*32767)
    with wave.open(str(audio/name),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sample_rate)
        w.writeframes(wave_out.tobytes())

def tone(f, t):
    return np.sin(2*np.pi*f*t)

def envelope(t, length, attack=0.01, release=0.1):
    return np.minimum(1,t/max(attack,1e-5))*np.minimum(1,(length-t)/max(release,1e-5))

# Original ambient pad sequence in A minor (24 seconds).
duration=24.0
t=np.arange(int(sample_rate*duration))/sample_rate
chords=[[110,164.81,220,329.63],[87.31,130.81,196,261.63],[65.41,98,164.81,261.63],[82.41,123.47,164.81,246.94]]
pad=np.zeros_like(t)
for section, notes in enumerate(chords):
    s=section*6.0
    z=t-s
    mask=(z>=0)&(z<6)
    local=np.clip(z,0,6)
    fade=np.minimum(1,local/1.8)*np.minimum(1,(6-local)/1.8)
    cluster=np.zeros_like(t)
    for j,note in enumerate(notes):
        cluster += tone(note*(1+0.0014*j),t)*0.15
        cluster += tone(note*2.003,t)*0.018
    pad+=cluster*fade*mask
# Irregular, delicate bell motif. Not from any third-party melody.
sequence=[(0.7,440),(2.3,523.25),(5.0,392),(6.9,349.23),(9.7,329.63),(12.2,440),(13.8,392),(16.4,329.63),(19.0,293.66),(21.9,349.23)]
bells=np.zeros_like(t)
for start,freq in sequence:
    s=t-start
    mask=(s>=0)&(s<2.1)
    env=np.exp(-np.maximum(0,s)*2.0)*(1-np.exp(-np.maximum(0,s)*70.0))
    bells+=(tone(freq,t)+tone(freq*2.005,t)*0.22)*env*mask*0.07
# Very subtle filtered noise resembles rain, waterfalls and flowing air.
noise=np.random.default_rng(7).normal(0,1,t.size)
for _ in range(9): noise=np.convolve(noise,np.ones(5)/5,mode='same')
ambience=0.38*pad+0.5*bells+noise*0.023
ambience*=np.minimum(1,t/0.5)*np.minimum(1,(duration-t)/0.7)
wav('ambience.wav',ambience)

# Short synthesized original one-shot sound effects.
for name,seconds in [('sword.wav',0.42),('magic.wav',0.69),('hurt.wav',0.33),('victory.wav',2.2)]:
    u=np.arange(int(sample_rate*seconds))/sample_rate
    rng=np.random.default_rng({'sword.wav':13,'magic.wav':14,'hurt.wav':15,'victory.wav':16}[name])
    n=rng.normal(0,1,len(u))
    if name=='sword.wav':
        v=0.17*tone(600-380*u/seconds,u)+0.11*n
        v*=np.exp(-u*11)
    elif name=='magic.wav':
        phase=2*np.pi*(370*u+660*u**2)
        v=(0.17*np.sin(phase)+0.12*tone(850,u)+0.06*n)*envelope(u,seconds,.02,.2)*np.exp(-u*1.8)
    elif name=='hurt.wav':
        v=(0.18*tone(170-100*u,u)+0.09*n)*np.exp(-u*12)
    else:
        v=np.zeros_like(u)
        for j,f in enumerate([220,277.18,329.63,440,554.37]):
            k=np.maximum(0,u-j*.21)
            v+=0.10*tone(f,u)*np.exp(-k*2)*(u>=j*.21)
        v*=envelope(u,seconds,.02,.75)
    wav(name,v)
print('Generated:',*[p.name for p in art.glob('*.png')],*[p.name for p in audio.glob('*.wav')])
