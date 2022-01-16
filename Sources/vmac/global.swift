//
//  global.swift
//  vmac
//
//  Created by George Watson on 02/01/2022.
//

import Foundation

final public class Global {
    public static let shared = Global()
    private let q = DispatchQueue(label: "com.takeiteasy.vmac-queue-\(UUID())",
                                  qos: .default,
                                  attributes: .concurrent)
    private var _vmc: VMContent = VMContent()
    var content: VMContent {
        get {
            return q.sync {
                self._vmc
            }
        }
        set {
            q.async(flags: .barrier) {
                self._vmc = newValue
            }
        }
    }
    private var _path: String = ""
    var path: String {
        get {
            return q.sync {
                self._path
            }
        }
        set {
            q.async(flags: .barrier) {
                self._path = newValue
            }
        }
    }
    private var _verbose: Bool = true
    var verbose: Bool {
        get {
            return q.sync {
                self._verbose
            }
        }
        set {
            q.async(flags: .barrier) {
                self._verbose = newValue
            }
        }
    }
    private var _tmp: Bool = false
    var tmp: Bool {
        get {
            return q.sync {
                self._tmp
            }
        }
        set {
            q.async(flags: .barrier) {
                self._tmp = newValue
            }
        }
    }
    
    func load() -> VMContent {
        do {
            self._vmc = try JSONDecoder().decode(VMContent.self,
                                           from: try Data(contentsOf: URL(fileURLWithPath: self.path + "/manifest.json")))
        } catch {
            assertionFailure("ERROR: Failed to load manifest from: \(self.path)")
        }
        return self._vmc
    }
    
    func save() {
        do {
            try String(data: try JSONEncoder().encode(self._vmc),
                       encoding: .utf8)?.write(to: URL(fileURLWithPath: self.path + "/manifest.json"),
                                               atomically: true,
                                               encoding: .utf8)
        } catch {
            assertionFailure("ERROR: Failed to encode manifest to json")
        }
    }
    
    private init() {}
}
