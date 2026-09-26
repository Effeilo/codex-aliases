import Foundation
import AVFoundation
import CoreVideo
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 1280, height = 720, fps: Int32 = 24
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
var index: Int64 = 0
while true {
    var bytes = Data()
    while bytes.count < width * height * 4 {
        let chunk = FileHandle.standardInput.readData(ofLength: width * height * 4 - bytes.count)
        if chunk.isEmpty { break }
        bytes.append(chunk)
    }
    if bytes.isEmpty { break }
    guard bytes.count == width * height * 4 else { fatalError("Incomplete frame") }
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adapter.pixelBufferPool!, &buffer)
    let pixel = buffer!
    CVPixelBufferLockBaseAddress(pixel, [])
    let target = CVPixelBufferGetBaseAddress(pixel)!
    let stride = CVPixelBufferGetBytesPerRow(pixel)
    bytes.withUnsafeBytes { source in
        for row in 0..<height { memcpy(target.advanced(by: row * stride), source.baseAddress!.advanced(by: row * width * 4), width * 4) }
    }
    CVPixelBufferUnlockBaseAddress(pixel, [])
    guard adapter.append(pixel, withPresentationTime: CMTime(value: index, timescale: fps)) else { fatalError("Encoding failed") }
    index += 1
}
input.markAsFinished()
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
guard writer.status == .completed else { fatalError("Video failed: \(String(describing: writer.error))") }
