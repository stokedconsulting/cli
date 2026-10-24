#!/usr/bin/env python3
"""FFmpeg chroma key engine. Uses argument arrays, never shell interpolation."""
import argparse, collections, json, math, os, pathlib, shutil, signal, statistics, subprocess, sys, tempfile, uuid

FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
FFPROBE = shutil.which("ffprobe") or str(pathlib.Path(FFMPEG).with_name("ffprobe"))
active = None

def stop(signum, frame):
    global active
    if active and active.poll() is None:
        active.terminate()
    raise InterruptedError("Cancelled; original preserved.")

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

def run(args):
    global active
    active = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        out, err = active.communicate()
        if active.returncode:
            raise RuntimeError(err.decode(errors="replace")[-4000:] or "FFmpeg failed.")
        return out
    finally:
        if active.poll() is None:
            active.terminate()
            active.wait()
        active = None

def ff(args):
    return run([FFMPEG, "-hide_banner", "-loglevel", "error", "-nostdin", *args])

def probe(path):
    data = json.loads(run([FFPROBE, "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)]))
    streams = [s for s in data["streams"] if s["codec_type"] == "video" and not s.get("disposition", {}).get("attached_pic")]
    if not streams:
        raise ValueError("This file contains no video stream.")
    s = streams[0]
    return {"width":s["width"], "height":s["height"], "duration":float(s.get("duration") or data["format"].get("duration") or 0), "codec":s["codec_name"], "stream":s["index"], "tags":s.get("tags",{})}

def detect(path):
    info = probe(path)
    pixels = []
    for t in (0, info["duration"] * .35, info["duration"] * .7):
        raw = ff(["-ss",str(t),"-i",str(path),"-map",f'0:{info["stream"]}',"-vf","scale=96:96","-frames:v","1","-pix_fmt","rgb24","-f","rawvideo","-"])
        if len(raw) != 96*96*3:
            continue
        pixels += [tuple(raw[(y*96+x)*3:(y*96+x)*3+3]) for y in range(96) for x in range(96) if x<6 or y<6 or x>=90 or y>=90]
    if not pixels:
        raise ValueError("Could not sample the video.")
    quant = lambda p: tuple(c//16 for c in p)
    groups = collections.Counter(map(quant,pixels))
    peak, count = groups.most_common(1)[0]
    members = [p for p in pixels if quant(p)==peak]
    rgb = tuple(int(statistics.median(p[c] for p in members)) for c in range(3))
    info.update(color="%02X%02X%02X"%rgb, confidence=count/len(pixels), similarity=.09, blend=.035, trim=.04, spill=.55)
    return info

def settings(raw):
    s = dict(color="FF9B00",similarity=.09,blend=.035,trim=.04,spill=.55,crf=28,audio=False)
    s.update(raw)
    s["color"] = str(s["color"]).lstrip("#")
    if len(s["color"]) != 6 or any(c not in "0123456789abcdefABCDEF" for c in s["color"]):
        raise ValueError("Background color must contain six hex digits.")
    for key, low, high in (("similarity",.00001,1),("blend",0,1),("trim",0,.8),("spill",0,1),("crf",0,63)):
        v=float(s[key])
        if not math.isfinite(v) or not low <= v <= high:
            raise ValueError(f"{key} must be between {low} and {high}.")
        s[key]=v
    return s

def filters(raw):
    s=settings(raw)
    rgb=[int(s["color"][i:i+2],16) for i in (0,2,4)]
    chain=f'chromakey=0x{s["color"]}:{s["similarity"]:.6f}:{s["blend"]:.6f},format=rgba'
    if s["spill"]:
        # Remove the keyed color's contribution from partially transparent edge pixels.
        expr=[f"{c}='clip({c}(X,Y)+{s['spill']:.4f}*({c}(X,Y)-{k})*(255-alpha(X,Y))/max(alpha(X,Y),32),0,255)'" for c,k in zip("rgb",rgb)]
        chain += ",geq=" + ":".join(expr) + ":a='alpha(X,Y)'"
    if s["trim"]:
        cut=s["trim"]*255
        chain += f",lut=a='clip((val-{cut:.4f})*255/{255-cut:.4f},0,255)'"
    return chain

def preview(path, raw, t, directory):
    info=probe(path)
    t=max(0,min(float(t),max(0,info["duration"]-.05)))
    directory=pathlib.Path(directory)
    directory.mkdir(parents=True,exist_ok=True)
    original=directory/"original.png"
    keyed=directory/"keyed.png"
    base=["-ss",str(t),"-i",str(path),"-map",f'0:{info["stream"]}',"-frames:v","1"]
    ff([*base,"-vf","scale=trunc(min(900\\,iw)/2)*2:-2,format=rgb24","-y",str(original)])
    ff([*base,"-vf",filters(raw)+",scale=trunc(min(900\\,iw)/2)*2:-2","-y",str(keyed)])
    return {"original":str(original),"keyed":str(keyed)}

def publish_unique(temp, desired):
    desired=pathlib.Path(desired)
    for n in range(10000):
        target=desired if not n else desired.with_name(f"{desired.stem}-{n}{desired.suffix}")
        try:
            os.link(temp,target)
            return target
        except FileExistsError:
            continue
    raise RuntimeError("Too many existing files with the same name.")

def export(path, raw):
    path=pathlib.Path(path).resolve(strict=True)
    info=probe(path)
    s=settings(raw)
    before=path.stat()
    temp=path.with_name(f".chroma-{uuid.uuid4().hex}.webm")
    try:
        args=["-i",str(path),"-map",f'0:{info["stream"]}',"-vf",filters(s)+",pad=ceil(iw/2)*2:ceil(ih/2)*2,format=yuva420p","-c:v","libvpx-vp9","-pix_fmt","yuva420p","-auto-alt-ref","0","-crf",str(int(s["crf"])),"-b:v","0","-deadline","good","-cpu-used","3","-row-mt","1"]
        args += ["-map","0:a?","-c:a","libopus"] if s["audio"] else ["-an"]
        ff([*args,"-n",str(temp)])
        result=probe(temp)
        if result["codec"]!="vp9" or temp.stat().st_size<100:
            raise RuntimeError("Export verification failed; original preserved.")
        if info["duration"] and abs(result["duration"]-info["duration"])>max(.5,info["duration"]*.02):
            raise RuntimeError("Export duration does not match source; original preserved.")
        # Decode all frames and the alpha plane; the native VP9 decoder drops alpha.
        ff(["-c:v","libvpx-vp9","-i",str(temp),"-map","0:v:0","-vf","alphaextract","-f","null","-"])
        current=path.stat()
        if (current.st_ino,current.st_size,current.st_mtime_ns)!=(before.st_ino,before.st_size,before.st_mtime_ns):
            raise RuntimeError("Source changed during export; original preserved.")
        output=publish_unique(temp,path.with_suffix(".webm"))
        archive_dir=path.parent/"chroma-originals"
        try:
            archive_dir.mkdir(exist_ok=True)
            archived=publish_unique(path,archive_dir/path.name)
            path.unlink()
        except OSError as e:
            return {"output":str(output),"warning":f"WebM saved, but original was not moved: {e}"}
        return {"output":str(output),"archive":str(archived)}
    finally:
        temp.unlink(missing_ok=True)

def main():
    p=argparse.ArgumentParser()
    p.add_argument("action",choices=["info","preview","export","filter"])
    p.add_argument("path")
    p.add_argument("--settings",default="{}")
    p.add_argument("--time",type=float,default=0)
    p.add_argument("--directory")
    a=p.parse_args()
    raw=json.loads(a.settings)
    if a.action=="info": result=detect(a.path)
    elif a.action=="preview": result=preview(a.path,raw,a.time,a.directory)
    elif a.action=="export": result=export(a.path,raw)
    else: result={"filter":filters(raw)}
    print(json.dumps(result),flush=True)

if __name__=="__main__":
    try: main()
    except Exception as e:
        print(str(e),file=sys.stderr)
        sys.exit(1)

