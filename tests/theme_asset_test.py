"""Verify the continuous frame surface and modest bar radius from real pixels."""
import importlib.util
from pathlib import Path
import tempfile
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('theme_art',root/'scripts/generate_theme_art.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)
media=root/'XPIsland/media'
def rgba(data,x,y):
 b,g,r,a=data[18+4*(y*64+x):22+4*(y*64+x)]
 return r,g,b,a
chrome=(media/'forever-chrome.tga').read_bytes()
assert rgba(chrome,0,0)[3]==0
assert rgba(chrome,32,0)[3]==255
for y in range(16,48):
 for x in range(16,48):
  assert rgba(chrome,x,y)==rgba(chrome,32,32),'center must be uniform, with no panel gradient'
assert rgba(chrome,32,32)[3]==214
# Every source scanline has one contiguous painted span, including corners.
for y in range(64):
 filled=[x for x in range(64) if rgba(chrome,x,y)[3]>0]
 assert filled and all(rgba(chrome,x,y)[3]>0 for x in range(min(filled),max(filled)+1))
cap=(media/'soft-cap.tga').read_bytes()
assert rgba(cap,0,0)[3]==0 and rgba(cap,10,0)[3]==255
assert rgba(cap,0,10)[3]==255,'end caps have tight corners rather than a half-circle'
shading=(media/'soft-cap-shading.tga').read_bytes()
body_shading=(media/'theme-shading.tga').read_bytes()
for y in range(64):
 assert rgba(shading,31,y)==rgba(body_shading,31,y),'cap and body gradients must join exactly'
assert rgba(shading,0,0)[3]==0,'shading must stay clipped to the rounded cap'
with tempfile.TemporaryDirectory() as temp:
 art.ROOT=Path(temp)
 art.write('forever-chrome.tga',art.chrome);art.write('soft-cap.tga',art.cap);art.write('soft-cap-shading.tga',art.cap_shading);art.write('theme-shading.tga',art.shading)
 for name in ['forever-chrome.tga','soft-cap.tga','soft-cap-shading.tga','theme-shading.tga']:
  assert (art.ROOT/name).read_bytes()==(media/name).read_bytes(),'generated artwork must be reproducible'
print('PASS: uniform translucent center, continuous corner alpha, modest cap radius and reproducible theme art')
