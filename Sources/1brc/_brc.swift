import Foundation

struct Entry {
    var min: Float
    var max: Float
    var sum: Float
    var count: Int
    var mean: Float {
        sum / Float(count)
    }
}

extension Entry: CustomStringConvertible {
    var description: String {
        String(format: "%.1f/%.1f/%.1f", min, max, mean)
    }
}

typealias Results = [Data: Entry]

@main
struct _brc {
    static func main() throws {
        let path = getenv("INPUT_FILE").flatMap { String(cString: $0) } ?? "measurements.txt"
        precondition(FileManager.default.fileExists(atPath: path))
        
        guard let handle = FileHandle(forReadingAtPath: path) else {
            fatalError("unable to read file")
        }
        
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let size = attrs[.size] as! Int64
        
        let formatter = ByteCountFormatter()
        print("File is: \(formatter.string(fromByteCount: Int64(size)))")
        
        var results: Results = [:]
        
        let bufferSize = 10 * 1024 * 1024
        var remainderBytes: Data = Data()
        while let chunk = try handle.read(upToCount: bufferSize) {
            let lastNewLineIndex = findLastNewLine(in: chunk.span)
            
            processNewLineAlignedChunk(remainderBytes + chunk[0...lastNewLineIndex], results: &results)
            if lastNewLineIndex + 1 > size {
                break
            }
            remainderBytes = chunk[(lastNewLineIndex + 1)...]
        }
        
        let entries = results.reduce(into: [:]) { dict, pair in
            dict[String(decoding: pair.0, as: UTF8.self)] = pair.1
        }
        for city in entries.keys.sorted() {
            print("\(city)=\(entries[city]!)")
        }
    }
    
    static func processNewLineAlignedChunk(_ chunk: Data, results: inout Results) {
        print("CHUNK----------------------------------")
        
        var span = chunk.span
        var chunkOffset = chunk.startIndex
        while true {
            guard let semiIndex = findNext(byte: .semicolon, in: span) else { break }
            let cityBytes = chunk[chunkOffset..<(chunkOffset + semiIndex)]
            
            span = span.extracting((semiIndex + 1)...)
            chunkOffset += semiIndex + 1

            guard let newLineIndex = findNext(byte: .newLineByte, in: span) else {
                fatalError("Expected to always find a new line byte here: \(String(data: chunk[chunkOffset...], encoding: .utf8) ?? "????")")
            }
            
            let temperatureBytes = chunk[chunkOffset..<(chunkOffset + newLineIndex)]
            chunkOffset += newLineIndex + 1
            span = span.extracting((newLineIndex + 1)...)

            let temperature = Float(String(decoding: temperatureBytes, as: UTF8.self))!
            var entry = results[cityBytes] ?? Entry(min: .greatestFiniteMagnitude, max: .leastNormalMagnitude, sum: 0, count: 0)
            entry.count += 1
            entry.min = min(entry.min, temperature)
            entry.max = max(entry.max, temperature)
            entry.sum += temperature
            results[cityBytes] = entry
        }
    }
    
    static func findNext(byte: UInt8, in span: Span<UInt8>) -> Int? {
        for index in 0..<span.count {
            if span[index] == byte {
                return index
            }
        }
        
        return nil
    }
    
    static func findLastNewLine(in data: Span<UInt8>) -> Int {
        // "\n" is 1 byte and is NOT present in any utf8 sequence
        
        for index in stride(from: data.count-1, to: 0, by: -1) {
            if data[index] == .newLineByte {
                return index
            }
        }
        
        fatalError("didn't find newline in data!")
    }
}

extension UInt8 {
    static let newLineByte: UInt8 = 0x0A
    static let semicolon: UInt8 = 59
}
