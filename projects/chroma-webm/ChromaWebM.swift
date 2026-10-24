import Cocoa

// Native editing workbench: paired frame views above a compact bank of controls.
// System typography and controls follow macOS appearance and keyboard conventions.
final class PreviewView: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var sampleBitmap: NSBitmapImageRep?
    var backing = 0 { didSet { needsDisplay = true } }
    var sample: ((String) -> Void)?
    var imageRect: NSRect {
        guard let image = image else { return .zero }
        let scale = min(bounds.width/image.size.width, bounds.height/image.size.height)
        let size = NSSize(width:image.size.width*scale,height:image.size.height*scale)
        return NSRect(x:(bounds.width-size.width)/2,y:(bounds.height-size.height)/2,width:size.width,height:size.height)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); bounds.fill()
        let rect=imageRect
        guard image != nil else { return }
        if backing == 0 {
            NSColor(white:0.8,alpha:1).setFill(); rect.fill()
            NSColor(white:0.6,alpha:1).setFill()
            let size:CGFloat=16
            for y in 0...Int(rect.height/size) {
                for x in 0...Int(rect.width/size) where (x+y)%2 == 0 {
                    NSRect(x:rect.minX+CGFloat(x)*size,y:rect.minY+CGFloat(y)*size,width:size,height:size).intersection(rect).fill()
                }
            }
        } else {
            [NSColor.black, .white, NSColor.systemPink][backing-1].setFill(); rect.fill()
        }
        image?.draw(in:rect,from:.zero,operation:.sourceOver,fraction:1)
    }
    override func mouseDown(with event: NSEvent) {
        sampleColor(at: convert(event.locationInWindow,from:nil))
    }
    func sampleColor(at point: NSPoint) {
        guard let bitmap=sampleBitmap else { return }
        let rect=imageRect
        guard rect.contains(point) else { return }
        let x=min(bitmap.pixelsWide-1,Int((point.x-rect.minX)/rect.width*CGFloat(bitmap.pixelsWide)))
        let y=min(bitmap.pixelsHigh-1,Int((rect.maxY-point.y)/rect.height*CGFloat(bitmap.pixelsHigh)))
        var pixel=[Int](repeating:0,count:bitmap.samplesPerPixel)
        bitmap.getPixel(&pixel,atX:x,y:y)
        guard bitmap.bitsPerSample == 8, pixel.count >= 3 else { return }
        sample?(String(format:"%02X%02X%02X",Int(pixel[0]),Int(pixel[1]),Int(pixel[2])))
    }
}

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window:NSWindow!
    var sourceView=PreviewView(), resultView=PreviewView()
    var titleLabel=NSTextField(labelWithString:"Choose a video")
    var status=NSTextField(wrappingLabelWithString:"")
    var timeLabel=NSTextField(labelWithString:"0.00 s")
    var colorField=NSTextField(string:"FF9B00")
    var colorWell=NSColorWell()
    var seek=NSSlider(value:0,minValue:0,maxValue:1,target:nil,action:nil)
    var sliders:[String:NSSlider]=[:], values:[String:NSTextField]=[:]
    var exportButton=NSButton(title:"Export WebM",target:nil,action:nil)
    var cancelButton=NSButton(title:"Cancel",target:nil,action:nil)
    var audio=NSButton(checkboxWithTitle:"Keep audio",target:nil,action:nil)
    var backing=NSSegmentedControl(labels:["Checkerboard","Black","White","Pink"],trackingMode:.selectOne,target:nil,action:nil)
    var spinner=NSProgressIndicator()
    var queue=[String](), current:String?, duration=0.0
    var generation=0, pending:DispatchWorkItem?
    var busy=false, closing=false
    var exportProcess:Process?
    let worker=DispatchQueue(label:"chroma.preview",qos:.userInitiated)
    let backend=Bundle.main.resourceURL!.appendingPathComponent("backend.py").path
    let python=Bundle.main.object(forInfoDictionaryKey:"ChromaPython") as? String ?? "/opt/homebrew/bin/python3"
    let scratch=FileManager.default.temporaryDirectory.appendingPathComponent("chroma-preview-"+UUID().uuidString)
    var settings:[String:Any] {
        var s:[String:Any]=["color":colorField.stringValue.trimmingCharacters(in:.whitespacesAndNewlines),"audio":audio.state == .on,"crf":28]
        for (key, slider) in sliders { s[key]=slider.doubleValue }
        return s
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        makeMenu(); build()
        let args=Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-psn_") }
        queue += args
        NSApp.activate(ignoringOtherApps:true)
        if !queue.isEmpty { next() }
        else { DispatchQueue.main.async { if self.current == nil && self.queue.isEmpty { self.choose(nil) } } }
    }
    func application(_ sender:NSApplication, openFiles filenames:[String]) {
        queue += filenames
        if window != nil && current == nil { next() }
        sender.reply(toOpenOrPrint:.success)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        if busy { cancel(nil); return .terminateCancel }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification:Notification) { try? FileManager.default.removeItem(at:scratch) }
    func windowShouldClose(_ sender:NSWindow)->Bool { if busy { cancel(nil); return false }; return true }
    func makeMenu() {
        let menu=NSMenu(), appItem=NSMenuItem(), appMenu=NSMenu()
        appMenu.addItem(withTitle:"Quit Chroma WebM",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        appItem.submenu=appMenu; menu.addItem(appItem)
        let edit=NSMenuItem(), editMenu=NSMenu(title:"Edit")
        for (name,sel,key) in [("Cut","cut:","x"),("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")] {
            editMenu.addItem(withTitle:name,action:Selector(sel),keyEquivalent:key)
        }
        edit.submenu=editMenu; menu.addItem(edit); NSApp.mainMenu=menu
    }
    func label(_ text:String,_ bold:Bool=false)->NSTextField {
        let l=NSTextField(labelWithString:text)
        l.font=bold ? .boldSystemFont(ofSize:13) : .systemFont(ofSize:13)
        return l
    }
    func stack(_ views:[NSView],_ vertical:Bool=false)->NSStackView {
        let s=NSStackView(views:views); s.orientation=vertical ? .vertical : .horizontal
        s.spacing=12; s.alignment=vertical ? .leading : .centerY
        return s
    }
    func build() {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1120,height:840),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Chroma WebM"; window.minSize=NSSize(width:1000,height:820); window.delegate=self
        let root=stack([],true); root.spacing=12
        root.translatesAutoresizingMaskIntoConstraints=false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:24),root.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-24),root.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),root.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-20)])
        titleLabel.font = .boldSystemFont(ofSize:20); titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
        let chooseButton=NSButton(title:"Choose Videos…",target:self,action:#selector(choose(_:)))
        let skipButton=NSButton(title:"Skip Video",target:self,action:#selector(skip(_:)))
        let header=stack([titleLabel,skipButton,chooseButton]); titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant:600).isActive=true
        root.addArrangedSubview(header)
        let sourceTitle=label("Original · click the background to sample",true), keyedTitle=label("Transparent result",true)
        let left=stack([sourceTitle,sourceView],true), right=stack([keyedTitle,resultView],true)
        let images=stack([left,right]); images.distribution = .fillEqually; images.alignment = .top
        for (panel,view) in [(left,sourceView),(right,resultView)] {
            view.translatesAutoresizingMaskIntoConstraints=false
            view.widthAnchor.constraint(equalTo:panel.widthAnchor).isActive=true
            view.heightAnchor.constraint(equalTo:images.heightAnchor,constant:-30).isActive=true
        }
        sourceView.sample={ [weak self] hex in self?.setColor(hex); self?.changed(nil) }
        root.addArrangedSubview(images)
        images.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        images.heightAnchor.constraint(greaterThanOrEqualToConstant:280).isActive=true
        seek.target=self; seek.action=#selector(changed(_:)); seek.isContinuous=true
        seek.setAccessibilityLabel("Preview time")
        let timeRow=stack([label("Frame"),seek,timeLabel])
        seek.widthAnchor.constraint(greaterThanOrEqualToConstant:530).isActive=true
        root.addArrangedSubview(timeRow)
        backing.selectedSegment=0; backing.target=self; backing.action=#selector(backingChanged(_:))
        root.addArrangedSubview(stack([label("Inspect edges on"),backing]))
        colorField.widthAnchor.constraint(equalToConstant:90).isActive=true; colorField.target=self; colorField.action=#selector(colorTyped(_:))
        colorField.setAccessibilityLabel("Background color hex")
        colorWell.target=self; colorWell.action=#selector(colorPicked(_:))
        let detectButton=NSButton(title:"Detect Background",target:self,action:#selector(detectAgain(_:)))
        root.addArrangedSubview(stack([label("Background",true),colorWell,label("#"),colorField,detectButton]))
        for (key,name,max,value,help) in [
            ("similarity","Similarity",0.5,0.09,"Higher removes a wider range of background colors."),
            ("blend","Edge softness",0.25,0.035,"Feathers the transition between transparent and opaque."),
            ("trim","Alpha cleanup",0.5,0.04,"Removes faint alpha residue; too much erases fine detail."),
            ("spill","Color fringe cleanup",1.0,0.55,"Subtracts sampled background color from semitransparent edges.")
        ] {
            let l=label(name); l.widthAnchor.constraint(equalToConstant:150).isActive=true
            let slider=NSSlider(value:value,minValue:key=="similarity" ? 0.00001 : 0,maxValue:max,target:self,action:#selector(changed(_:)))
            slider.isContinuous=true; slider.toolTip=help; slider.setAccessibilityLabel(name)
            slider.widthAnchor.constraint(greaterThanOrEqualToConstant:350).isActive=true
            let number=label(String(format:"%.3f",value)); number.font = .monospacedDigitSystemFont(ofSize:13,weight:.regular)
            number.widthAnchor.constraint(equalToConstant:50).isActive=true
            sliders[key]=slider; values[key]=number
            let hint=label(help); hint.textColor = .secondaryLabelColor; hint.font = .systemFont(ofSize:11)
            hint.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
            let row=stack([l,slider,number,hint]); root.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        }
        audio.toolTip="Audio is removed by default. Enable to encode existing audio as Opus."
        root.addArrangedSubview(audio)
        let note=NSTextField(wrappingLabelWithString:"Exports beside the video as transparent VP9 WebM (CRF 28). After verification, the original moves to ./chroma-originals. Existing files receive a numbered name.")
        note.font = .systemFont(ofSize:12); note.textColor = .secondaryLabelColor
        root.addArrangedSubview(note); note.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        status.font = .systemFont(ofSize:12); status.maximumNumberOfLines=3
        spinner.style = .spinning; spinner.controlSize = .small; spinner.isDisplayedWhenStopped=false
        exportButton.target=self; exportButton.action=#selector(exportVideo(_:)); exportButton.keyEquivalent="\r"
        cancelButton.target=self; cancelButton.action=#selector(cancel(_:)); cancelButton.isHidden=true
        let footer=stack([spinner,status,cancelButton,exportButton])
        status.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
        root.addArrangedSubview(footer); footer.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        exportButton.isEnabled=false
        window.center(); window.makeKeyAndOrderFront(nil)
    }
    func setColor(_ hex:String) {
        colorField.stringValue=hex
        if let value=UInt32(hex,radix:16) {
            colorWell.color=NSColor(srgbRed:CGFloat((value>>16)&255)/255,green:CGFloat((value>>8)&255)/255,blue:CGFloat(value&255)/255,alpha:1)
        }
    }
    @objc func choose(_ sender:Any?) {
        guard !busy else { return }
        let panel=NSOpenPanel(); panel.allowsMultipleSelection=true; panel.canChooseDirectories=false
        panel.message="Choose videos with a solid-color background"
        if panel.runModal() == .OK { queue += panel.urls.map(\.path); current=nil; next() }
    }
    @objc func skip(_ sender:Any?) { guard !busy else { return }; current=nil; if !queue.isEmpty { next() } else { choose(nil) } }
    func next() {
        guard !queue.isEmpty else { return }
        current=queue.removeFirst(); titleLabel.stringValue=URL(fileURLWithPath:current!).lastPathComponent
        seek.doubleValue=0; generation += 1; sourceView.image=nil; sourceView.sampleBitmap=nil; resultView.image=nil
        detectAgain(nil)
    }
    func call(_ action:String,_ path:String,_ s:[String:Any]=[:],_ extras:[String]=[],processCallback:((Process)->Void)?=nil)throws->[String:Any] {
        let data=try JSONSerialization.data(withJSONObject:s)
        let p=Process(); p.executableURL=URL(fileURLWithPath:python)
        p.arguments=[backend,action,path,"--settings",String(data:data,encoding:.utf8)!]+extras
        var env=ProcessInfo.processInfo.environment
        env["PATH"]="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"; p.environment=env
        let out=Pipe(),err=Pipe(); p.standardOutput=out; p.standardError=err
        try p.run(); processCallback?(p)
        let result=out.fileHandleForReading.readDataToEndOfFile()
        let errors=err.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw NSError(domain:"Chroma",code:1,userInfo:[NSLocalizedDescriptionKey:String(data:errors,encoding:.utf8) ?? "Conversion failed."]) }
        return try JSONSerialization.jsonObject(with:result) as! [String:Any]
    }
    @objc func detectAgain(_ sender:Any?) {
        guard let path=current, !busy else { return }
        generation += 1; let token=generation
        setControls(false)
        status.stringValue="Sampling borders across the video…"; exportButton.isEnabled=false; spinner.startAnimation(nil)
        worker.async {
            do {
                let info=try self.call("info",path)
                DispatchQueue.main.async {
                    guard token==self.generation else { return }
                    self.setControls(true)
                    self.duration=info["duration"] as? Double ?? 0
                    self.seek.maxValue=max(0.01,self.duration-0.05)
                    self.setColor(info["color"] as? String ?? "FF9B00")
                    for key in ["similarity","blend","trim","spill"] { self.sliders[key]?.doubleValue=info[key] as? Double ?? 0 }
                    let confidence=info["confidence"] as? Double ?? 0
                    self.status.stringValue=confidence<0.6 ? "Border colors vary. Click the intended background in Original, then adjust settings." : "Background detected. Scrub several frames and inspect edges before exporting."
                    self.changed(nil)
                }
            } catch { DispatchQueue.main.async { self.setControls(true); self.showError(error); self.spinner.stopAnimation(nil) } }
        }
    }
    @objc func colorTyped(_ sender:Any?) { setColor(colorField.stringValue.replacingOccurrences(of:"#",with:"")); changed(nil) }
    @objc func colorPicked(_ sender:Any?) {
        guard let c=colorWell.color.usingColorSpace(.sRGB) else { return }
        setColor(String(format:"%02X%02X%02X",Int(c.redComponent*255),Int(c.greenComponent*255),Int(c.blueComponent*255))); changed(nil)
    }
    @objc func backingChanged(_ sender:Any?) { resultView.backing=backing.selectedSegment }
    @objc func changed(_ sender:Any?) {
        guard let path=current,!busy else { return }
        for (key,slider) in sliders { values[key]?.stringValue=String(format:"%.3f",slider.doubleValue) }
        timeLabel.stringValue=String(format:"%.2f / %.2f s",seek.doubleValue,duration)
        generation += 1; let token=generation, s=settings, t=seek.doubleValue
        pending?.cancel(); exportButton.isEnabled=false; spinner.startAnimation(nil)
        let task=DispatchWorkItem { [weak self] in
            guard let self=self else { return }
            self.worker.async {
                guard token==self.generation else { return }
                let dir=self.scratch.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at:dir) }
                do {
                    let data=try self.call("preview",path,s,["--time",String(t),"--directory",dir.path])
                    let original=NSImage(contentsOfFile:data["original"] as! String), keyed=NSImage(contentsOfFile:data["keyed"] as! String)
                    let bitmap=NSBitmapImageRep(data:try Data(contentsOf:URL(fileURLWithPath:data["original"] as! String)))
                    DispatchQueue.main.async {
                        guard token==self.generation else { return }
                        self.sourceView.image=original; self.sourceView.sampleBitmap=bitmap; self.resultView.image=keyed
                        self.exportButton.isEnabled=true; self.spinner.stopAnimation(nil)
                    }
                } catch { DispatchQueue.main.async { if token==self.generation { self.status.stringValue=error.localizedDescription; self.spinner.stopAnimation(nil) } } }
            }
        }
        pending=task; DispatchQueue.main.asyncAfter(deadline:.now()+0.25,execute:task)
    }
    @objc func exportVideo(_ sender:Any?) {
        guard let path=current,!busy else { return }
        busy=true; generation += 1; pending?.cancel()
        let s=settings
        exportButton.isEnabled=false; cancelButton.isHidden=false; spinner.startAnimation(nil)
        status.stringValue="Encoding and verifying transparent WebM… Original stays in place until verification succeeds."
        setControls(false)
        DispatchQueue.global(qos:.userInitiated).async {
            do {
                let result=try self.call("export",path,s,processCallback:{ process in DispatchQueue.main.async { self.exportProcess=process; if self.closing { process.terminate() } } })
                DispatchQueue.main.async {
                    self.endExport()
                    if let warning=result["warning"] as? String { self.status.stringValue=warning }
                    else { self.status.stringValue="Saved "+(result["output"] as? String ?? "")+" · Original archived." }
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:result["output"] as! String)])
                    self.current=nil
                    if !self.queue.isEmpty { self.next() }
                }
            } catch { DispatchQueue.main.async { self.endExport(); self.status.stringValue=self.closing ? "Cancelled. Original preserved." : error.localizedDescription; self.closing=false; self.changed(nil) } }
        }
    }
    func setControls(_ enabled:Bool) {
        seek.isEnabled=enabled; colorField.isEnabled=enabled; colorWell.isEnabled=enabled; audio.isEnabled=enabled
        for slider in sliders.values { slider.isEnabled=enabled }
        sourceView.sample=enabled ? { [weak self] hex in self?.setColor(hex); self?.changed(nil) } : nil
    }
    func endExport() { busy=false; exportProcess=nil; cancelButton.isHidden=true; spinner.stopAnimation(nil); setControls(true) }
    @objc func cancel(_ sender:Any?) { closing=true; status.stringValue="Cancelling…"; exportProcess?.terminate() }
    func showError(_ error:Error) { status.stringValue=error.localizedDescription; exportButton.isEnabled=false }
}

let application=NSApplication.shared
let delegate=App()
application.delegate=delegate
application.run()

