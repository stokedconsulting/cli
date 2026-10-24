"""Exercise the same pixel-coordinate sampler used by mouseDown."""
import pathlib
import subprocess

root = pathlib.Path(__file__).parent
build = root / ".validation"
build.mkdir(exist_ok=True)
source = (root / "ChromaWebM.swift").read_text().split("let application=NSApplication.shared")[0]
harness = r'''
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2,pixelsHigh:2,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
bitmap.setColor(NSColor(deviceRed:1,green:0,blue:0,alpha:1),atX:0,y:0)
bitmap.setColor(NSColor(deviceRed:0,green:0,blue:1,alpha:1),atX:0,y:1)
let image=NSImage(size:NSSize(width:2,height:2))
image.addRepresentation(bitmap)
let preview=PreviewView(frame:NSRect(x:0,y:0,width:200,height:100))
preview.image=image
preview.sampleBitmap=bitmap
var sampled=""
preview.sample={ sampled=$0 }
preview.sampleColor(at:NSPoint(x:60,y:90))
precondition(sampled=="FF0000",sampled)
preview.sampleColor(at:NSPoint(x:60,y:10))
precondition(sampled=="0000FF",sampled)
sampled=""
preview.sampleColor(at:NSPoint(x:10,y:10))
precondition(sampled.isEmpty)
print("Sampling geometry: top/bottom pixels and letterbox rejection PASS")
'''
(build / "sample.swift").write_text(source + harness)
subprocess.run(["swiftc", str(build / "sample.swift"), "-o", str(build / "sample"), "-framework", "Cocoa"], check=True)
subprocess.run([str(build / "sample")], check=True)
