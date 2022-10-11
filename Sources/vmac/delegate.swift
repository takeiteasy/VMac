//
//  delegate.swift
//  vmac
//
//  Created by George Watson on 02/01/2022.
//

import Foundation
import Virtualization
import Cocoa

public func print(_ items: String..., filename: String = #file, function : String = #function, line: Int = #line, separator: String = " ", terminator: String = "\n") {
    if !Global.shared.verbose {
        return
    }
    Swift.print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
}

class VMDelegate: NSObject, NSApplicationDelegate, VZVirtualMachineDelegate, NSWindowDelegate {
    private(set) var vm: VZVirtualMachine?
    private(set) var content: VMContent?
    private(set) var view: VZVirtualMachineView?
    private(set) var window: NSWindow?
    private(set) var path: String
    private(set) var installed = false
    
    init(path: String, content: VMContent, runAfterInstall: Bool) {
        print("Arguments = \(String(describing: content))")
        self.path = path
        super.init()
        
        let url = URL(fileURLWithPath: self.path)
        switch url.pathExtension.lowercased() {
        case "ipsw":
            assert(FileManager.default.fileExists(atPath: self.path), "ERROR: No file at \"\(self.path)\"")
            print("* LOADING ISPW: \(url.relativePath)", terminator: "...")
            fflush(stdout)
            VZMacOSRestoreImage.load(from: url) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let image):
                        print("SUCCESS")
                        guard let config = image.mostFeaturefulSupportedConfiguration else {
                            assertionFailure("ERROR: Failed to meet minimum requirements for image")
                            return
                        }
                        
                        assert(config.minimumSupportedCPUCount <= content.cores!, "ERROR: Imagine requires a minimum of \(config.minimumSupportedCPUCount) cores - Configured value: \(content.cores!)")
                        assert(config.minimumSupportedMemorySize <= content.ram!, "ERROR: Imagine requires a minimum of \(config.minimumSupportedMemorySize) bytes of RAM - Configured value: \(content.cores!)")
                       
                        self.content = VMContent(id: content.id,
                                                 hwModel: config.hardwareModel.dataRepresentation.hexEncodedString(),
                                                 machineId: VZMacMachineIdentifier().dataRepresentation.hexEncodedString(),
                                                 cores: content.cores,
                                                 ram: content.ram,
                                                 disks: [],
                                                 eth: content.eth,
                                                 video: content.video,
                                                 recovery: content.recovery,
                                                 noAudio: content.noAudio,
                                                 noGUI: content.noGUI)
                        for (i, var d) in content.disks!.enumerated() {
                            d.setPath(path: Global.shared.path + "/disk\(i).img")
                            self.content?.disks?.append(d)
                        }
                        Global.shared.content = self.content!
                        print("Content = \(String(describing: self.content!))")
                        
                        print("* CREATING DISKS...")
                        let fm = FileManager.default
                        for d in self.content!.disks! {
                            print("* \(d.path!)...")
                            do {
                                if fm.fileExists(atPath: d.path!) {
                                    print(" ALREADY EXISTS")
                                } else {
                                    try createBlankDisk(size: d.size, path: d.path!)
                                    print(" SUCCESS")
                                }
                            } catch {
                                assertionFailure("ERROR: Failed to create disk @ \(d.path!) - \(error)")
                            }
                        }
                        
                        print("* GENERATING CONFIG", terminator: "...")
                        fflush(stdout)
                        guard let conf = Global.shared.content.configuration(path: Global.shared.path,
                                                                             requirements: config) else {
                            assertionFailure("ERROR: Failed to generate configuration")
                            return
                        }
                        
                        do {
                            try conf.validate()
                            if !Global.shared.tmp {
                                Global.shared.save()
                            } else {
                                print("* -t FLAG TRIGGERED: NOT SAVING MANIFEST")
                            }
                        } catch {
                            assertionFailure("ERROR: Invalid configuration - \(error)")
                        }
                        print("SUCCESS")
                        
                        print("* INSTALLING VIRTUAL MACHINE...")
                        self.vm = VZVirtualMachine(configuration: conf,
                                                   queue: .main)
                        self.vm!.delegate = self
                        
                        dynamic let installer = VZMacOSInstaller(virtualMachine: self.vm!,
                                                                 restoringFromImageAt: image.url)
                        let x = installer.progress.observe(\Progress.fractionCompleted, options: .initial) { p, _ in
                            printProgress(progress: p.fractionCompleted)
                        }
                        
                        installer.install { [weak self] result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    x.invalidate()
                                    print(" SUCCESS")
                                    print(Global.shared.content.description)
                                    if !runAfterInstall {
                                        NSApp.terminate(nil)
                                    } else {
                                        print("* -R FLAG TRIGGERED: STARTING VIRTUAL MACHINE")
                                        self!.vm = nil
                                        self?.start_vm()
                                    }
                                case .failure(let error):
                                    assertionFailure("ERROR: \(error)")
                                }
                            }
                        }
                        break
                    case .failure(let error):
                        assertionFailure("\(FileManager.default.currentDirectoryPath) ERROR: Failed to load image from \"\(self.path)\" - \(error)")
                    }
                }
            }
        case "macosvm":
            print("* LOADING MACOSVM: \(Global.shared.path)", terminator: "...")
            fflush(stdout)
            let fm = FileManager.default
            var isDir:ObjCBool = true
            assert(fm.fileExists(atPath: Global.shared.path, isDirectory: &isDir), "ERROR: \(Global.shared.path) doesn't exist")
            self.content = Global.shared.load()
            print("SUCCESS")
            print("* CHECKING DISKS...")
            for d in self.content!.disks! {
                print("* CHECKING \(d.path!)", terminator: "...")
                fflush(stdout)
                if !fm.fileExists(atPath: d.path!) {
                    assertionFailure("ERROR: No disk @ \(d.path!)")
                } else {
                    print("SUCCESS")
                }
            }
            self.start_vm()
            break
        default:
            assertionFailure("ERROR: Invalid file type/path provided: \"\(path)\"")
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if Global.shared.tmp {
            print("* -t FLAG TRIGGERED: DELETING UP DISKS")
            let fm = FileManager.default
            let disks_raw: [VMStorage] = (self.content?.disks != nil ? self.content!.disks! as [VMStorage] : [])
            var disks: [String] = []
            do {
                disks = try disks_raw.map { (d: VMStorage) throws -> String in
                    return d.path ?? ""
                }
            } catch {
                assertionFailure("ERROR: \(error)")
            }
            
            disks.append("/tmp/aux.img")
            for d in disks {
                if fm.fileExists(atPath: d) {
                    print("* DELETING \(d)", terminator:"...")
                    do {
                        try fm.removeItem(atPath: d)
                        print("SUCCESS")
                    } catch {
                        assertionFailure("\(error)")
                    }
                }
            }
        }
    }
    
    private func create_window() {
        print("* CREATING WINDOW", terminator: "...")
        fflush(stdout)
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit",
                        action: #selector(NSApplication.terminate),
                        keyEquivalent: "q")
        
        NSApp.activate(ignoringOtherApps: true)
        
        self.window = NSWindow(contentRect: NSMakeRect(0, 0, CGFloat(self.content?.video?.width ?? 640), CGFloat(self.content?.video?.height ?? 480)),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable],
                               backing: .buffered,
                               defer: false)
        self.window!.center()
        self.window!.title = "vmac-\(self.content?.id.uuidString ?? "")"
        self.window!.makeKeyAndOrderFront(self.window)
        
        self.view = VZVirtualMachineView()
        self.view!.virtualMachine = self.vm
        self.view!.capturesSystemKeys = true
        self.window!.contentView = self.view
        self.window?.makeFirstResponder(self.view)
        print("SUCCESS")
        print(Global.shared.content.description)
    }
    
    private func start_vm() {
        print("* STARTING VIRTUAL MACHINE: Content = \(String(describing: content))")
        print("* GENERATING CONFIG", terminator: "...")
        fflush(stdout)
        guard let conf = Global.shared.content.configuration(path: Global.shared.path,
                                                             requirements: nil) else {
            assertionFailure("ERROR: Failed to generate configuration")
            return
        }
        
        do {
            try conf.validate()
        } catch {
            assertionFailure("ERROR: Invalid configuration - \(error)")
        }
        print("SUCCESS")
        
        print("* LAUNCHING VIRTUAL MACHINE", terminator: "...")
        fflush(stdout)
        self.vm = VZVirtualMachine(configuration: conf,
                                   queue: .main)
        self.vm!.delegate = self
        
        self.vm!.start { result in
            switch result {
            case .success:
                print("SUCCESS")
                if !(self.content?.noGUI ?? false) {
                    self.create_window()
                } else {
                    print("* -x FLAG TRIGGERED: SKIPPING WINDOW CREATION")
                }
            case .failure(let error):
                assertionFailure("ERROR: \(error)")
            }
        }
    }
    
    private func stop_vm() {
        self.vm?.stop(completionHandler: { _ in
            print("* VIRTUAL MACHINE STOPPED")
        })
    }
}
