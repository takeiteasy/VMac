//
//  main.swift
//  vmac
//
//  Created by George Watson on 27/11/2021.
//

import Foundation
import Cocoa
import ArgumentParser

@available(macOS 12, *)
@main
struct vmac: ParsableCommand {
    @Argument(help: "Path to the image")
    var path: String
    
    @Option(name: .shortAndLong,
            help: "Set RAM allocation (Max: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024 / 1024)gb)",
            transform: { arg in
        var ret: Int64 = Int64(arg) ?? -1
        if let match = try! NSRegularExpression(pattern: #"^(?<size>\d+)(?<unit>[gmk]?b)$"#,
                                                options: .caseInsensitive).firstMatch(in: arg,
                                                                                      options: [],
                                                                                      range: NSRange(location: 0,
                                                                                                     length: arg.utf16.count)) {
            if let type = Range(match.range(withName: "unit"),
                                in: arg),
               let size = Range(match.range(withName: "size"),
                                in:arg) {
                let n: Int64 = Int64(arg[size]) ?? -1
                switch arg[type].lowercased() {
                case "gb":
                    ret = n * 1024 * 1024 * 1024
                case "mb":
                    ret = n * 1024 * 1024
                case "kb":
                    ret = n * 1024
                case "b":
                    ret = n
                default:
                    assertionFailure("ERROR: Unknown error with regex engine. Please report this.")
                }
            }
        } else {
            assertionFailure("ERROR: Invalid argument supplied to --ram \"\(arg)\"")
        }
        assert(ret > 0, "ERROR: Invalid argument supplied to --ram \"\(arg)\"")
        assert(ret < Int(ProcessInfo.processInfo.physicalMemory), "ERROR: Invalid argument supplied to --ram \"\(arg)/\(ret)b\" - Not enough physical RAM available. Max = \(ProcessInfo.processInfo.physicalMemory)b")
        return ret
    })
    var ram: Int64 = 4 * 1024 * 1024 * 1024
    
    @Option(name: .shortAndLong,
            help: "Set number of cores to use (Max: \(ProcessInfo.processInfo.processorCount))",
            transform: { arg in
        let ret: Int = Int(arg)!
        assert(ret > 0, "ERROR: Invalid argument supplied to --cores \"\(ret)\"")
        assert(ret < Int(ProcessInfo.processInfo.processorCount), "ERROR: Invalid argument supplied to --cores \"\(ret)\" - Not enough physical cores available. Max = \(ProcessInfo.processInfo.processorCount)")
        return ret
    })
    var cores: Int = 2
    
    @Option(name: .shortAndLong,
            help: "Add storage (e.g. 32gb,8192mb+ro,4194304kb+rw) (Max: \(disk_space_remaining() / 1024 / 1024 / 1024)gb)",
            transform: { arg in
        let regex: NSRegularExpression = try! NSRegularExpression(pattern: #"((?<size>\d+)(?<unit>[gmk]?b))?(\+(?<access>r[ow]))?$"#,
                                                                  options: .caseInsensitive)
        var ret: [VMStorage] = []
        var i = 0, total: Int64 = 0
        arg.split(separator: ",").forEach {
            let str = $0.trimmingCharacters(in: .whitespaces)
            guard let match = regex.firstMatch(in: str,
                                               options: [],
                                               range: NSRange(location: 0,
                                                              length: str.utf16.count)) else {
                assertionFailure("ERROR: Invalid argument supplied to --disk \"\(str)\" - Format is: N[gb|mb|kb|b](+[ro|rw]),...")
                return
            }
            guard let size = Range(match.range(withName: "size"),
                                   in: str),
                  let unit = Range(match.range(withName: "unit"),
                                   in: str) else {
                      assertionFailure("ERROR: Invalid argument supplied to --disk \"\(str)\" - Format is: N[gb|mb|kb|b](+[ro|rw]),...")
                      return
                  }
            var n: Int64 = Int64(str[size]) ?? -1
            switch str[unit].lowercased() {
            case "gb":
                break
            case "mb":
                n = n / 1024
            case "kb":
                n = n / 1024 / 1024
            case "b":
                n = n / 1024 / 1024 / 1024
            default:
                break
            }
            var readOnly = false
            if let write = Range(match.range(withName: "access"),
                                 in: str) {
                readOnly = str[write] == "ro"
            }
            assert(n > 0, "ERROR: Invalid argument supplied to --disk \"\(str)\" - Disk must be at least 1gb")
            let disk_space = disk_space_remaining()
            total += n
            assert(total < (disk_space / 1024 / 1024 / 1024), "ERROR: Insufficent disk space: \(disk_space)")
            ret.append(VMStorage(size: Int(n),
                                 readOnly: readOnly))
        }
        return ret
    })
    var disks: [VMStorage]?
    
    @Option(name: .shortAndLong,
            help: "Add network interface (e.g. nat,bridge,bridge@en1,bridge@bridge0)",
            transform: { arg in
        let regex: NSRegularExpression = try! NSRegularExpression(pattern: #"^(?<type>nat|bridge)(@(?<bridge>en|bridge)(?<addr>\d+))?$"#,
                                                                  options: .caseInsensitive)
        var ret: [VMEthInterface] = []
        var nat_added = false
        arg.split(separator: ",").forEach {
            let str = $0.trimmingCharacters(in: .whitespaces)
            guard let match = regex.firstMatch(in: str,
                                               options: [],
                                               range: NSRange(location: 0,
                                                              length: str.utf16.count)) else {
                assertionFailure("ERROR: Invalid argument supplied to --eth \"\(str)\" - Format is: <nat|bridge(@<en|bridge><id>)>,...")
                return
            }
            guard let type = Range(match.range(withName: "type"),
                                   in: str) else {
                assertionFailure("ERROR: Invalid argument supplied to --eth \"\(str)\" - Format is: <nat|bridge(@<en|bridge><id>)>,...")
                return
            }
            switch str[type].lowercased() {
            case "nat":
                if !nat_added {
                    ret.append(VMEthInterface(type: .NAT,
                                              iface: ""))
                    nat_added = true
                }
                break
            case "bridge":
                if let addr = Range(match.range(withName: "addr"),
                                    in: str),
                   let bridge = Range(match.range(withName: "bridge"), in: str) {
                    ret.append(VMEthInterface(type: .Bridge,
                                              iface: "\(str[bridge])\(str[addr])"))
                } else {
                    ret.append(VMEthInterface(type: .Bridge,
                                              iface: ""))
                }
                break
            default:
                assertionFailure("ERROR: Unknown error with regex engine. Please report this.")
            }
        }
        return ret
    })
    var eth: [VMEthInterface]?
    @Option(name: .shortAndLong,
            help: "Set graphics options - Format is: <width>x<height>@<ppi>",
            transform: { arg in
        let regex: NSRegularExpression = try! NSRegularExpression(pattern: #"^(?<width>\d+)x(?<height>\d+)@(?<ppi>\d+)?$"#,
                                                                  options: .caseInsensitive)
        let match = regex.firstMatch(in: arg,
                                           options: [],
                                           range: NSRange(location: 0,
                                                          length: arg.utf16.count))
        if match == nil {
            assertionFailure("ERROR: Invalid argument supplied to --video \"\(arg)\"")
        }
        let width = Range(match!.range(withName: "width"),
                          in: arg)
        let height = Range(match!.range(withName: "height"),
                           in: arg)
        let pixels = Range(match!.range(withName: "pixels"),
                           in: arg)
        if width == nil || height == nil || pixels == nil {
            assertionFailure("ERROR: Invalid argument supplied to --video \"\(arg)\"")
        }
        return VMGraphics(width: Int(arg[width!]) ?? 0,
                          height: Int(arg[height!]) ?? 0,
                          ppi: Int(arg[pixels!]) ?? 0)
    })
    var video: VMGraphics = VMGraphics(width: 2560,
                                       height: 1600,
                                       ppi: 220)
    
    @Option(name: .shortAndLong,
            help: "Path to save VM when installing OS")
    var out: String?
    
    @Flag(name: [.customShort("b"),
                 .long],
          help: "Set to boot into recovery mode (TODO)")
    var recoveryMode: Bool = false
    
    @Flag(name: [.customShort("a"),
                 .long],
          help: "Set to disable audio")
    var noAudio: Bool = false
    
    @Flag(name: [.customShort("x"),
                 .long],
          help: "Set to disable GUI")
    var noGUI: Bool = false
    
    @Flag(name: [.customShort("H"),
                 .long],
          help: "Sets --no-audio and --no-gui to true")
    var headless: Bool = false {
        didSet {
            noAudio = true
            noGUI = true
        }
    }
    @Flag(name: .shortAndLong,
          help: "Mute output")
    var quiet: Bool = false
    @Flag(name: .customShort("R"),
          help: "Run VM after installation")
    var runAfterInstall: Bool = false
    @Flag(name: .shortAndLong,
          help: "Delete after run")
    var tmp: Bool = false {
        didSet {
            self.out = "/tmp/\(UUID().uuidString).macosvm"
            self.runAfterInstall = true
        }
    }
    
    @available(macOS 12, *)
    func run() throws {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: self.path)
        switch url.pathExtension.lowercased() {
        case "ipsw":
            assert(self.disks != nil, "ERROR: No disks provided for installer")
            assert(self.out != nil, "ERROR: No out path provided for installer")
            assert(!fm.fileExists(atPath: self.out!))
            try fm.createDirectory(at: URL(fileURLWithPath: self.out!),
                                   withIntermediateDirectories: true)
            Global.shared.path = self.out!
        case "macosvm":
            assert(fm.fileExists(atPath: self.path))
            Global.shared.path = self.path
            break
        default:
            assertionFailure("ERROR: Invalid filetype: \(url.pathExtension)")
        }
        
        Global.shared.tmp = self.tmp
        Global.shared.verbose = !self.quiet
        
        let vm = VMDelegate(path: self.path,
                            content: VMContent(id: UUID(),
                                               cores: self.cores,
                                               ram: self.ram,
                                               disks: self.disks,
                                               eth: self.eth ?? [],
                                               video: self.video,
                                               recovery: self.recoveryMode,
                                               noAudio: self.noAudio,
                                               noGUI: self.noGUI),
                            runAfterInstall: self.runAfterInstall)
        
        NSApplication.shared.delegate = vm
        NSApplication.shared.run()
    }
}
