//
//  utils.swift
//  vmac
//
//  Created by George Watson on 01/01/2022.
//

import Foundation
import Darwin

func print_progress_bar(units: Int, progress: Double) {
    print("\r  [", terminator: "")
    let x = Int((progress * Double(units)).rounded())
    if x > 0 {
        print(String(repeating: "*", count: x), terminator: "")
    }
    let y = units - x
    if y > 0 {
        print(String(repeating: "-", count: y), terminator: "")
    }
    print("] \(Int((progress * 100.0).rounded()))%", terminator: "")
    fflush(stdout)
}

func create_new_disk(size: Int, path: String) throws {
    let url = URL(fileURLWithPath: path)
    try "".write(to: url, atomically: true, encoding: .utf8)
    let fh: FileHandle? = try FileHandle(forWritingTo: url)
    
    let bufsz: Int64 = 32768
    let buf: Data = Data(repeating: 0, count: Int(bufsz))
    let size: Int64 = Int64(size) * 1024 * 1024 * 1024
    var written: Int64 = 0, remain: Int64 = 0
    while (written < size) {
        print_progress_bar(units: 20, progress: Double(written) / Double(size))
        remain = size - written
        if (remain > bufsz) {
            remain = bufsz
        }
        fh?.write(buf)
        written += remain
    }
}

func disk_space_remaining() -> Int64 {
    let String = FileManager.default.urls(for: .documentDirectory,
                                       in: .userDomainMask)[0]
    let values = try? String.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    if let capacity = values?.volumeAvailableCapacityForImportantUsage {
        return capacity
    } else {
        NSLog("ERROR: volumeAvailableCapacityForImportantUsage not available")
        return -1
    }
}
