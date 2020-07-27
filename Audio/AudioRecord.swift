//
//  AudioRecord.swift
//  Audio
//
//  Created by leven on 2020/7/17.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import AudioUnit
import AVFoundation
import AudioToolbox

class AudioRecord {
    
    class Info {
        var mDataFormat: AudioStreamBasicDescription? = nil
        var mQueue: AudioQueueRef? = nil
        var mBuffers: [AudioQueueBufferRef] = []
        var mBufferSize: UInt32 = 0
    }
    
    var info: Info = Info()
    
    var isRunning: Bool = false
    
    init() {
        config()
    }
    
    var fileHandler: FileHandler?
    var inputHandle: AudioQueueInputCallback?
    
    func generateDataFormat(formateID: AudioFormatID) -> AudioStreamBasicDescription {

        var dataFormat = AudioStreamBasicDescription()
                
        dataFormat.mSampleRate = AVAudioSession.sharedInstance().preferredSampleRate

        dataFormat.mChannelsPerFrame =  UInt32(AVAudioSession.sharedInstance().inputNumberOfChannels)
        dataFormat.mChannelsPerFrame = 2
        
        dataFormat.mFormatID = formateID
        
        if dataFormat.mFormatID == kAudioFormatLinearPCM {
            dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
            dataFormat.mBitsPerChannel = 16
            dataFormat.mBytesPerFrame = dataFormat.mBitsPerChannel / 8 * dataFormat.mChannelsPerFrame
            dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame
            dataFormat.mFramesPerPacket = 1
        } else {
            dataFormat.mFormatFlags = AudioFormatFlags(MPEG4ObjectID.aac_Main.rawValue)
        }
        return dataFormat
    }
    
    func config() {
        
        let duringSec = 0.05
        let numBuffers = 3
        
        var dataFormat = generateDataFormat(formateID: kAudioFormatLinearPCM)

        info.mDataFormat = dataFormat

        
        do {
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

            try? AVAudioSession.sharedInstance().setPreferredIOBufferDuration(duringSec)
        }
        
        inputHandle = { inUserData, inAQ, inBuffer, inStartTime, inNumPackets, inPacketDesc in
            let record = Unmanaged<AudioRecord>.fromOpaque(inUserData!).takeUnretainedValue()
            guard let mDataFormat = record.info.mDataFormat else {
                return
            }
            if record.isRunning {
                var inNumPackets = inNumPackets
                let bytePerPacket = mDataFormat.mBytesPerPacket
                if bytePerPacket != 0 && inNumPackets == 0 {
                    inNumPackets = inBuffer.pointee.mAudioDataByteSize / bytePerPacket
                }
                
            }
            print("录制 \(inBuffer.pointee.mAudioDataByteSize) 字节，\(inNumPackets)包")

            record.fileHandler?.writefile(inNumBytes: inBuffer.pointee.mAudioDataByteSize,
                                          ioNumPackerts: inNumPackets,
                                          inBuffer: inBuffer.pointee.mAudioData,
                                          packetDesc: inPacketDesc)
            if record.isRunning {
                AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
            }
        }
        

        let selfPoint = Unmanaged.passRetained(self).toOpaque()
        
        var status = AudioQueueNewInput(&dataFormat,
                                        inputHandle!,
                                        selfPoint,
                                        CFRunLoopGetCurrent(),
                                        CFRunLoopMode.commonModes.rawValue,
                                        0,
                                        &info.mQueue)
        
        if status != noErr { }
        
        
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioQueueGetProperty(info.mQueue!, kAudioQueueProperty_StreamDescription, &dataFormat, &(size))
        if status != noErr { }
        
        let bufferSize = (info.mDataFormat?.mBytesPerPacket ?? 0) * 100
//        computeRecordBufferSizz(format: info.mDataFormat!, queue: info.mQueue!, durationSec: CGFloat(duringSec))
        info.mBufferSize = bufferSize
        for _ in 1 ... numBuffers {
            var buffer: AudioQueueBufferRef? = nil
            status = AudioQueueAllocateBuffer(info.mQueue!, bufferSize, &buffer)
            
            if status != noErr {}
            
            status = AudioQueueEnqueueBuffer(info.mQueue!, buffer!, 0, nil)
            
            if status != noErr {}
        }
        
    }
    
    func  computeRecordBufferSizz(format: AudioStreamBasicDescription, queue: AudioQueueRef, durationSec: CGFloat) -> UInt32 {
        var packets = 0
        var frames = 0
        var bytes = 0
        
        
        frames = Int(ceil(durationSec * CGFloat(format.mSampleRate)))
        if format.mBytesPerFrame > 0 {
            bytes = frames * Int(format.mBytesPerFrame)
        } else {
            var maxPacketSize: UInt32 = 0
            if format.mBytesPerPacket > 0 {
                maxPacketSize = format.mBytesPerPacket // CBR
            } else {
                // VBR
                var propertySize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
                let status = AudioQueueGetProperty(queue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &propertySize)
                if status != noErr {}
            }
            if format.mFramesPerPacket > 0 {
                packets = frames / Int(format.mFramesPerPacket)
            }
            if packets == 0 {
                packets = frames
            }
            bytes = packets * Int(maxPacketSize)
        }
        
        return UInt32(bytes > 0x50000 ? 0x50000 : bytes)
    }
    
    func startCapture(fileHandler: FileHandler) {
        if isRunning == false {
            self.fileHandler = fileHandler
            fileHandler.startRecord(queue: info.mQueue!, needCookie: info.mDataFormat?.mFormatID != kAudioFormatLinearPCM, audioDesc: info.mDataFormat!)
            isRunning = true
            let status = AudioQueueStart(info.mQueue!, nil)
            if status != noErr {}
            
        } else {
            let status = AudioQueuePause(info.mQueue!)
            if status != noErr {}
            isRunning = false
            self.fileHandler?.stopRecord(queue: info.mQueue!, needCookie: info.mDataFormat?.mFormatID != kAudioFormatLinearPCM)
        }
    }
    
    
    
}

extension AudioRecord {
    
    
    
}



