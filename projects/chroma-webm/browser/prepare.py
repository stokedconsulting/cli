"""Prepare a real twice-exported VP9 alpha fixture for browser validation."""
import base64
import importlib.util
import json
import pathlib
import tempfile

root=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("backend",root/"backend.py")
b=importlib.util.module_from_spec(spec); spec.loader.exec_module(b)
build=root/".validation"; build.mkdir(exist_ok=True)
directory=pathlib.Path(tempfile.mkdtemp(prefix="browser-",dir=build))
source=directory/"fixture.mp4"
b.ff(["-f","lavfi","-i","color=c=orange:s=128x128:r=12:d=1,drawbox=x=36:y=36:w=56:h=56:color=blue:t=fill","-c:v","libx264","-pix_fmt","yuv420p","-y",str(source)])
first=b.export(source,{"color":"FFA500"})
second=b.export(first["source"],{"color":"FFA500","similarity":.15},replace_output=first["output"])
assert first["output"]==second["output"]
assert first["source"]==second["source"]
video=base64.b64encode(pathlib.Path(second["output"]).read_bytes()).decode()
html='''<!doctype html><meta charset="utf-8"><title>Chroma repeat export validation</title>
<h1>Chroma repeat export validation</h1><p id="status">Loading exported WebM…</p>
<video id="video" muted playsinline controls src="data:video/webm;base64,'''+video+'''"></video>
<canvas id="canvas" width="128" height="128"></canvas>
<script>
const video=document.getElementById("video"), status=document.getElementById("status");
video.addEventListener("error",()=>status.textContent="FAIL video decode");
video.addEventListener("loadeddata",async()=>{
 try {
  await video.play();
  await new Promise(resolve=>setTimeout(resolve,150));
  video.pause();
  const context=document.getElementById("canvas").getContext("2d");
  context.clearRect(0,0,128,128); context.drawImage(video,0,0,128,128);
  const background=context.getImageData(0,0,1,1).data[3];
  const foreground=context.getImageData(64,64,1,1).data[3];
  const pass=background<10 && foreground>245 && video.videoWidth===128 && video.currentTime>0;
  status.textContent=(pass?"PASS ":"FAIL ")+JSON.stringify({backgroundAlpha:background,foregroundAlpha:foreground,width:video.videoWidth,height:video.videoHeight,playedSeconds:video.currentTime});
 } catch(error) { status.textContent="FAIL "+error.message; }
});
</script>'''
page=directory/"validation.html";page.write_text(html)
print(json.dumps({"output":second["output"],"source":second["source"],"page":str(page),"url":"data:text/html;base64,"+base64.b64encode(html.encode()).decode()}))
