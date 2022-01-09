//
//  types.swift
//  vmac
//
//  Created by George Watson on 02/01/2022.
//

import Foundation
import Virtualization

struct VMGraphics: Codable {
    var width, height, ppi: Int
    
    public var description: String {
        return "\(self.width)x\(self.height)@\(self.ppi)"
    }
}

enum VMEthType: String, Codable {
    case NAT
    case Bridge
}

struct VMEthInterface: Codable {
    var type: VMEthType
    var iface: String
    
    public var description: String {
        return
"""
Type: \(self.type)
Interface: \(self.iface)
"""
    }
}

struct VMStorage: Codable {
    var path: String?
    var size: Int
    var readOnly: Bool
    
    public mutating func setPath(path: String) {
        self.path = path
    }
    
    public var description: String {
        return
"""
Path: \(self.path ?? "N/A")
Size: \(self.size)
Read-only?: \(self.readOnly)
"""
    }
}

struct VMContent: Codable {
    var id: UUID = UUID()
    
    var hw_model: Data?
    var m_id: Data?
    
    var cores: Int?
    var ram: Int64?
    var disks: [VMStorage]?
    var eth: [VMEthInterface]?
    var video: VMGraphics?
    
    var recovery: Bool = false
    var noAudio: Bool = false
    var noGUI: Bool = false
    
    public var description: String {
        return
"""
ID: \(self.id)
HW Model: \(String(describing: self.hw_model))
Machine ID: \(String(describing: self.m_id))
Cores: \(self.cores ?? -1)
RAM: \(self.ram ?? -1)
Storage (\(self.disks?.count ?? -1)): [
  \(self.disks?.reduce("", {$0 + $1.description}) ?? "")
]
Interfaces: (\(self.eth?.count ?? -1)) [
  \(self.eth?.reduce("", {$0 + $1.description}) ?? "")
]
Video: \(self.video?.description ?? "")
Recovery Boot?: \(self.recovery)
Disable Audio?: \(self.noAudio)
Disable GUI?: \(self.noGUI)
"""
    }
    
    public func configuration(path: String,
                              requirements: VZMacOSConfigurationRequirements?) -> VZVirtualMachineConfiguration? {
        if requirements != nil {
            assert(requirements!.minimumSupportedCPUCount <= self.cores!, "ERROR: Imagine requires a minimum of \(requirements!.minimumSupportedCPUCount) cores - Configured value: \(self.cores!)")
            assert(requirements!.minimumSupportedMemorySize <= self.ram!, "ERROR: Imagine requires a minimum of \(requirements!.minimumSupportedMemorySize) bytes of RAM - Configured value: \(self.cores!)")
        }
        
        let conf = VZVirtualMachineConfiguration()
        conf.bootLoader = VZMacOSBootLoader()
        conf.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        conf.keyboards = [VZUSBKeyboardConfiguration()]
        conf.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        conf.cpuCount = self.cores!
        conf.memorySize = UInt64(self.ram!)
        
        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = VZMacHardwareModel(dataRepresentation: self.hw_model!)!
        platform.machineIdentifier = VZMacMachineIdentifier(dataRepresentation: self.m_id!)!
        let aux_path = path + "/aux.img"
        do {
            platform.auxiliaryStorage = try VZMacAuxiliaryStorage(
                creatingStorageAt: URL(fileURLWithPath: aux_path),
                hardwareModel: platform.hardwareModel,
                options: [.allowOverwrite]
            )
        } catch {
            assertionFailure("ERROR: Failed to create aux storage @ \(aux_path)")
        }
        conf.platform = platform
        
        do {
            conf.storageDevices = try (self.disks?.map { (d: VMStorage) -> VZVirtioBlockDeviceConfiguration in
                return VZVirtioBlockDeviceConfiguration(attachment: try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: d.path!), readOnly: d.readOnly))
            })!
        } catch {
            assertionFailure("ERROR: \(error)")
        }
        
        var eth: [VZVirtioNetworkDeviceConfiguration] = []
        for e in self.eth! {
            let d = VZVirtioNetworkDeviceConfiguration()
            switch e.type {
            case .NAT:
                d.attachment = VZNATNetworkDeviceAttachment()
            case .Bridge:
                assert(VZBridgedNetworkInterface.networkInterfaces.count > 0, "ERROR: No host interfaces are available for bridging")
                var br: VZBridgedNetworkInterface?
                if e.iface.isEmpty {
                    br = VZBridgedNetworkInterface.networkInterfaces[0]
                } else {
                    for b in VZBridgedNetworkInterface.networkInterfaces {
                        if b.identifier == e.iface {
                            br = b
                            break
                        }
                    }
                }
                assert(br != nil, "ERROR: No host interface named: \(e.iface)")
                d.attachment = VZBridgedNetworkDeviceAttachment(interface: br!)
            }
            eth.append(d)
        }
        conf.networkDevices = eth
        
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [
            VZMacGraphicsDisplayConfiguration(
                widthInPixels: self.video?.width ?? 0,
                heightInPixels: self.video?.height ?? 0,
                pixelsPerInch: self.video?.ppi ?? 0
            )
        ]
        conf.graphicsDevices = [graphics]
        
        if self.noAudio {
            conf.audioDevices = []
        } else {
            let soundDevice = VZVirtioSoundDeviceConfiguration()
            let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
            outputStream.sink = VZHostAudioOutputStreamSink()
            soundDevice.streams.append(outputStream)
            let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
            inputStream.source = VZHostAudioInputStreamSource()
            soundDevice.streams.append(inputStream)
            conf.audioDevices = [soundDevice]
        }
        
        return conf
    }
}
