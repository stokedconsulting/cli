"""Run real export/preview completions against the native editor's retained state."""
import importlib.util
import pathlib
import shutil
import subprocess
import tempfile

root=pathlib.Path(__file__).resolve().parent
build=root/".validation"; build.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location("backend",root/"backend.py")
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
directory=pathlib.Path(tempfile.mkdtemp(prefix="editor-",dir=build))
fixture=directory/"fixture.mp4"
b.ff(["-f","lavfi","-i","color=c=0xFF9B00:s=128x128:r=12:d=1,drawbox=x=28:y=28:w=72:h=72:color=0xC99958:t=fill,drawbox=x=36:y=36:w=56:h=56:color=blue:t=fill","-c:v","libx264","-pix_fmt","yuv420p","-y",str(fixture)])
second=directory/"next.mp4";shutil.copyfile(fixture,second)
shutil.copyfile(root/"backend.py",build/"backend.py")
source=(root/"ChromaWebM.swift").read_text().split("let application=NSApplication.shared")[0]
harness=r'''
let application=NSApplication.shared
application.setActivationPolicy(.prohibited)
let editor=App()
editor.window=NSWindow(contentRect:NSRect(x:0,y:0,width:200,height:100),styleMask:[],backing:.buffered,defer:false)
let input=CommandLine.arguments[1]
let original=try! Data(contentsOf:URL(fileURLWithPath:input))
editor.current=input
editor.queue=[CommandLine.arguments[2]]
editor.duration=1
editor.seek.doubleValue=0.25
editor.sliders["similarity"]=NSSlider(value:0.09,minValue:0.00001,maxValue:0.5,target:nil,action:nil)
func awaitExport() {
    let deadline=Date().addingTimeInterval(45)
    while (editor.busy || !editor.exportButton.isEnabled) && Date()<deadline {
        RunLoop.main.run(until:Date().addingTimeInterval(0.02))
    }
    precondition(!editor.busy && editor.exportButton.isEnabled,editor.status.stringValue)
}
editor.exportVideo(nil)
awaitExport()
let archive=editor.current!, output=editor.exportOutput!
precondition(URL(fileURLWithPath:archive).deletingLastPathComponent().lastPathComponent=="chroma-originals")
precondition(!FileManager.default.fileExists(atPath:input))
precondition(editor.exportButton.title=="Export Again")
precondition(editor.queue.count==1)
precondition(editor.seek.doubleValue==0.25)
precondition(try! Data(contentsOf:URL(fileURLWithPath:archive))==original)
let firstOutput=try! Data(contentsOf:URL(fileURLWithPath:output))
editor.sliders["similarity"]!.doubleValue=0.22
editor.changed(nil)
awaitExport()
editor.exportVideo(nil)
awaitExport()
precondition(editor.current==archive)
precondition(editor.exportOutput==output)
precondition(editor.sliders["similarity"]!.doubleValue==0.22)
precondition(editor.seek.doubleValue==0.25)
precondition(editor.queue.count==1)
precondition(try! Data(contentsOf:URL(fileURLWithPath:archive))==original)
precondition(try! Data(contentsOf:URL(fileURLWithPath:output)) != firstOutput)
precondition(!FileManager.default.fileExists(atPath:URL(fileURLWithPath:archive).deletingLastPathComponent().appendingPathComponent("chroma-originals").path))
try? FileManager.default.removeItem(at:editor.scratch)
print("Native editor: follows archive, retains frame/settings/queue, re-exports same output PASS")
'''
(build/"editor.swift").write_text(source+harness)
subprocess.run(["swiftc",str(build/"editor.swift"),"-o",str(build/"editor"),"-framework","Cocoa"],check=True)
subprocess.run([str(build/"editor"),str(fixture),str(second)],check=True)
