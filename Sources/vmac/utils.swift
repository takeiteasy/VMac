//
//  utils.swift
//  vmac
//
//  Created by George Watson on 01/01/2022.
//

import Foundation
import Darwin

func printProgress(progress: Double, length: Int = 20) {
    print("\r  [", terminator: "")
    let x = Int((progress * Double(length)).rounded())
    if x > 0 {
        print(String(repeating: "*", count: x), terminator: "")
    }
    let y = length - x
    if y > 0 {
        print(String(repeating: "-", count: y), terminator: "")
    }
    print("] \(Int((progress * 100.0).rounded()))%", terminator: "")
    fflush(stdout)
}

func createBlankDisk(size: Int64, path: String) throws {
    let url = URL(fileURLWithPath: path)
    try "".write(to: url, atomically: true, encoding: .utf8)
    let fh: FileHandle? = try FileHandle(forWritingTo: url)
    
    let bufsz: Int64 = 32768
    let buf: Data = Data(repeating: 0, count: Int(bufsz))
    var written: Int64 = 0, remain: Int64 = 0
    while (written < size) {
        printProgress(progress: Double(written) / Double(size))
        remain = size - written
        if (remain > bufsz) {
            remain = bufsz
        }
        fh?.write(buf)
        written += remain
    }
    try fh?.close()
}

func diskSpaceRemaining() -> Int64 {
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

func toBytes(n: Int64, suffix: String) -> Int64 {
    switch suffix {
    case "gb":
        return n * 1024 * 1024 * 1024
    case "mb":
        return n * 1024 * 1024
    case "kb":
        return n * 1024
    case "b":
        return n
    default:
        assertionFailure("ERROR: Unknown error with regex engine. Please report this.")
    }
    return -1
}

// https://stackoverflow.com/a/52600783
extension Data {
    /// A hexadecimal string representation of the bytes.
    func hexEncodedString() -> String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(count * 2)
        
        for byte in self {
            let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }
        
        return String(utf16CodeUnits: hexChars, count: hexChars.count)
    }
}

extension String {
    /// A data representation of the hexadecimal bytes in this string.
    func hexDecodedData() -> Data {
        // Get the UTF8 characters of this string
        let chars = Array(utf8)
        
        // Keep the bytes in an UInt8 array and later convert it to Data
        var bytes = [UInt8]()
        bytes.reserveCapacity(count / 2)
        
        // It is a lot faster to use a lookup map instead of strtoul
        let map: [UInt8] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 01234567
            0x08, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 89:;<=>?
            0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // @ABCDEFG
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // HIJKLMNO
        ]
        
        // Grab two characters at a time, map them and turn it into a byte
        for i in stride(from: 0, to: count, by: 2) {
            let index1 = Int(chars[i] & 0x1F ^ 0x10)
            let index2 = Int(chars[i + 1] & 0x1F ^ 0x10)
            bytes.append(map[index1] << 4 | map[index2])
        }
        
        return Data(bytes)
    }
}
