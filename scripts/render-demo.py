"""Render a simulated terminal demo on macOS (Python + Pillow + Swift)."""
from pathlib import Path
import subprocess
import tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'demo.mp4'
FONT = '/System/Library/Fonts/Menlo.ttc'

def font(size):
    return ImageFont.truetype(FONT, size)


def frame(t):
    im = Image.new('RGB', (1280, 720), '#101321')
    d = ImageDraw.Draw(im)
    def text(x, y, value, size=22, color='#e9edf8'):
        d.text((x, y), value, font=font(size), fill=color)
    text(72, 45, 'codex-aliases', 30)
    text(72, 91, 'Your model. One command.', 18, '#939dbb')
    text(1000, 55, 'SIMULATED DEMO', 14, '#939dbb')
    second = t >= 8
    elapsed = t - 8 if second else t
    x, y = (150, 193) if second else (90, 166)
    if second:
        d.rounded_rectangle((90, 166, 1130, 590), 16, fill='#191e2b', outline='#353d50', width=2)
        text(125, 179, 'Terminal 1 — Astra', 15, '#737e98')
    d.rounded_rectangle((x+7, y+12, x+1047, y+412), 16, fill='#090b11')
    d.rounded_rectangle((x, y, x+1040, y+400), 16, fill='#171b26', outline='#394154', width=2)
    d.rounded_rectangle((x+1, y+1, x+1039, y+46), 15, fill='#242a39')
    d.rectangle((x+1, y+25, x+1039, y+46), fill='#242a39')
    for i, color in enumerate(['#ff6259', '#febc2e', '#28c840']):
        d.ellipse((x+20+i*25, y+16, x+32+i*25, y+28), fill=color)
    text(x+370, y+14, 'Terminal 2 — Sol' if second else 'Terminal 1 — Astra', 16, '#acb6cb')
    text(x+30, y+77, '~/projects/my-app', 19, '#939dbb')
    text(x+30, y+119, '❯', 27, '#9f9aff')
    command = 'cxs --high' if second else 'cxa'
    n = max(0, min(len(command), int((elapsed-.7)*8)))
    text(x+64, y+119, command[:n], 27)
    launch = 2.4 if second else 1.8
    if elapsed < launch:
        if int(t*3)%2 == 0:
            cx = x+64+d.textlength(command[:n], font=font(27))
            d.rectangle((cx+3, y+121, cx+17, y+151), fill='#b6afff')
    else:
        d.rounded_rectangle((x+30, y+178, x+1009, y+313), 10, outline='#505b75', width=2)
        text(x+53, y+195, '>_ Codex', 25)
        text(x+53, y+243, 'model', 19, '#929db5')
        text(x+260, y+243, 'gpt-6-sol' if second else 'gpt-6-astra', 22, '#c2b5ff')
        text(x+53, y+279, 'reasoning', 19, '#929db5')
        text(x+260, y+279, 'high' if second else 'configured default', 19, '#78dbaf')
        text(x+33, y+341, '> What would you like to build?', 21, '#cdd5e6')
    caption = '01  Choose Astra with cxa' if not second else '02  Choose Sol + high reasoning with cxs --high'
    text(90, 650, caption, 20, '#b6afff')
    d.rectangle((0, 714, int(1280*t/18), 719), fill='#a499ff')
    return im

if __name__ == '__main__':
    OUT.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        encoder = Path(tmp) / 'encoder'
        subprocess.run(['swiftc', str(ROOT/'scripts/encode-demo.swift'), '-o', str(encoder)], check=True)
        target = Path(tmp) / 'demo.mp4'
        proc = subprocess.Popen([str(encoder), str(target)], stdin=subprocess.PIPE)
        try:
            for i in range(18*24):
                im = frame(i/24)
                proc.stdin.write(im.convert('RGBA').tobytes('raw', 'BGRA'))
            proc.stdin.close()
            if proc.wait() != 0:
                raise RuntimeError('Encoder failed')
        finally:
            if proc.poll() is None:
                proc.kill()
        OUT.write_bytes(target.read_bytes())
    frame(5).save(ROOT/'assets/demo-astra-preview.png')
    frame(14).save(ROOT/'assets/demo-preview.png')
    print(OUT)
