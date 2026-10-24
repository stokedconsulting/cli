#!/usr/bin/env python3
import hashlib, importlib.util, json, os, pathlib, shutil, subprocess, sys, tempfile, time, unittest
from unittest import mock
spec=importlib.util.spec_from_file_location("backend",pathlib.Path(__file__).with_name("backend.py"))
b=importlib.util.module_from_spec(spec); spec.loader.exec_module(b)

class Integration(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix="chroma-test-")
        self.root=pathlib.Path(self.tmp.name)
        self.source=self.root/"video ' sample.mp4"
        b.ff(["-f","lavfi","-i","color=c=0xFF9B00:s=128x128:r=12:d=1,drawbox=x=28:y=28:w=72:h=72:color=0xC99958:t=fill,drawbox=x=36:y=36:w=56:h=56:color=blue:t=fill","-c:v","libx264","-pix_fmt","yuv420p","-y",str(self.source)])
        self.original=self.source.read_bytes()
    def tearDown(self): self.tmp.cleanup()
    def alpha(self,path):
        return b.ff(["-c:v","libvpx-vp9","-i",str(path),"-frames:v","1","-vf","alphaextract","-pix_fmt","gray","-f","rawvideo","-"])
    def test_detection_and_adjustments(self):
        info=b.detect(self.source)
        rgb=tuple(int(info["color"][i:i+2],16) for i in (0,2,4))
        self.assertTrue(all(abs(a-c)<20 for a,c in zip(rgb,(255,155,0))),rgb)
        self.assertGreater(info["confidence"],.8)
        settings={"color":info["color"],"similarity":.08,"blend":.12,"trim":0,"spill":0}
        base=b.preview(self.source,settings,0,self.root/"base")
        base_png=pathlib.Path(base["keyed"]).read_bytes()
        for key,value in (("similarity",.22),("blend",.02),("trim",.35),("spill",1)):
            changed=b.preview(self.source,{**settings,key:value},0,self.root/key)
            self.assertNotEqual(base_png,pathlib.Path(changed["keyed"]).read_bytes(),key)
    def test_export_alpha_archive_collision(self):
        existing=self.source.with_suffix(".webm"); existing.write_bytes(b"existing output")
        archive=self.root/"chroma-originals"; archive.mkdir()
        (archive/self.source.name).write_bytes(b"existing original")
        result=b.export(self.source,{"color":b.detect(self.source)["color"]})
        self.assertFalse(self.source.exists())
        self.assertEqual(pathlib.Path(result["archive"]).parent,archive.resolve())
        self.assertEqual(pathlib.Path(result["archive"]).read_bytes(),self.original)
        self.assertEqual(existing.read_bytes(),b"existing output")
        self.assertEqual((archive/self.source.name).read_bytes(),b"existing original")
        info=b.probe(result["output"]); self.assertEqual(info["codec"],"vp9")
        alpha=self.alpha(result["output"])
        self.assertLess(alpha[0],10)
        self.assertGreater(alpha[64*128+64],245)
        self.assertFalse(list(self.root.glob(".chroma-*")))
    def test_failure_preserves_original(self):
        with mock.patch.object(b,"filters",return_value="not_a_real_filter"):
            with self.assertRaises(RuntimeError): b.export(self.source,{})
        self.assertEqual(self.source.read_bytes(),self.original)
        self.assertFalse(list(self.root.glob("*.webm")))
        self.assertFalse(list(self.root.glob(".chroma-*")))
    def test_cancel_preserves_original(self):
        long=self.root/"long.mp4"
        b.ff(["-f","lavfi","-i","color=c=orange:s=1024x1024:r=30:d=8,drawbox=x=200:y=200:w=600:h=600:color=blue:t=fill","-c:v","libx264","-preset","ultrafast","-y",str(long)])
        digest=hashlib.sha256(long.read_bytes()).digest()
        p=subprocess.Popen([sys.executable,str(pathlib.Path(b.__file__)),"export",str(long)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            deadline=time.monotonic()+20
            while time.monotonic()<deadline and not list(self.root.glob(".chroma-*")) and p.poll() is None:
                time.sleep(.05)
            self.assertIsNone(p.poll(),"export finished before cancellation could be tested")
            time.sleep(.15)
            p.terminate(); p.communicate(timeout=20)
            self.assertNotEqual(p.returncode,0)
            self.assertEqual(hashlib.sha256(long.read_bytes()).digest(),digest)
            self.assertFalse((self.root/"long.webm").exists())
            self.assertFalse(list(self.root.glob(".chroma-*")))
        finally:
            if p.poll() is None: p.kill(); p.communicate()
    def test_optional_audio(self):
        audio_source=self.root/"with audio.mp4"
        b.ff(["-i",str(self.source),"-f","lavfi","-i","sine=frequency=440:duration=1","-map","0:v:0","-map","1:a:0","-c:v","copy","-c:a","aac","-shortest","-y",str(audio_source)])
        result=b.export(audio_source,{"audio":True})
        data=json.loads(b.run([b.FFPROBE,"-v","error","-show_streams","-of","json",result["output"]]))
        self.assertIn("opus",[s["codec_name"] for s in data["streams"] if s["codec_type"]=="audio"])
    def test_invalid_color_preserves_source(self):
        with self.assertRaises(ValueError): b.export(self.source,{"color":"';touch foo"})
        self.assertEqual(self.source.read_bytes(),self.original)

if __name__=="__main__": unittest.main(verbosity=2)

