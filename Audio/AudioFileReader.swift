//
//  AudioFileReader.swift
//  Audio
//
//  Created by leven on 2020/8/5.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import AudioToolbox

struct AudioBufferData {
    var bufferList: AudioBufferList?
    var numFrames: UInt32 = 0
}

class AudioFileReader {
    
    var filePath: String? {
        didSet {
            setupFileReader()
        }
    }
    
    var outputDesc: AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    var isRepeat: Bool = false
    private(set) var readAvailable = false
    
    var audioFileRef: ExtAudioFileRef?
    
    var fileDesc: AudioStreamBasicDescription?
    
    var packetSize: UInt32 = 0
    
    var desireFormat: AudioStreamBasicDescription? {
        didSet {
            modifyOutDescByDesireFormat()
            if readAvailable, let fileRef = audioFileRef {
                let size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                ExtAudioFileSetProperty(fileRef, kExtAudioFileProperty_ClientDataFormat, size, &outputDesc)
            }
        }
    }
    
    var totalFrames: Int64 = 0
    
    
    func setupFileReader() {
        guard let filePath = filePath else {
            return
        }
        
        let fileUrl = URL(fileURLWithPath: filePath)
        // 打开文件获取文件的引用
        var status = ExtAudioFileOpenURL(fileUrl as CFURL, &audioFileRef)
        guard let fileRefID = audioFileRef else { return }
        
        var descSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        // 获取文件格式
        status = ExtAudioFileGetProperty(fileRefID, kExtAudioFileProperty_FileDataFormat, &descSize, &fileDesc)
        
        outputDesc.mSampleRate = 44100
        outputDesc.mFormatID = kAudioFormatLinearPCM
        outputDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        outputDesc.mReserved = 0
        outputDesc.mChannelsPerFrame = 1
        outputDesc.mBitsPerChannel = 16
        outputDesc.mFramesPerPacket = 1
        outputDesc.mBytesPerFrame = outputDesc.mChannelsPerFrame * outputDesc.mBitsPerChannel / 8
        outputDesc.mBytesPerPacket = outputDesc.mBytesPerFrame * outputDesc.mFramesPerPacket
        
        modifyOutDescByDesireFormat()
        
        // 设置输出的w数据格式
        status = ExtAudioFileSetProperty(fileRefID, kExtAudioFileProperty_ClientDataFormat, descSize, &outputDesc)
        
        var packetMemorySize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        
        // 获取数据中最大包大小
        status = ExtAudioFileGetProperty(fileRefID, kExtAudioFileProperty_ClientMaxPacketSize, &packetMemorySize, &packetSize)
        
        // 获取数据中frame的个数
        var numMemorySize = UInt32(MemoryLayout<Int64>.size)
        status = ExtAudioFileGetProperty(fileRefID, kExtAudioFileProperty_FileLengthFrames, &numMemorySize, &totalFrames)
        print(status)
        readAvailable = true
    }
    
    
    func resetReader() {
        if let fileRef = audioFileRef {
            ExtAudioFileDispose(fileRef)
            audioFileRef = nil
        }
        readAvailable = false
    }
    
    func modifyOutDescByDesireFormat() {
        guard let desireDesc = desireFormat else { return }
        if desireDesc.mSampleRate > 0 {
            outputDesc.mSampleRate = desireDesc.mSampleRate
        }
        if desireDesc.mChannelsPerFrame > 0 {
            outputDesc.mChannelsPerFrame = desireDesc.mChannelsPerFrame
        }
        
        if desireDesc.mBitsPerChannel > 0 {
            outputDesc.mBitsPerChannel = desireDesc.mBitsPerChannel
        }
        if desireDesc.mFormatFlags > 0 && desireDesc.mFormatFlags != outputDesc.mFormatFlags {
            outputDesc.mFormatFlags = desireDesc.mFormatFlags
        }
        
        let isNonInterleaved = outputDesc.mFormatFlags & kLinearPCMFormatFlagIsNonInterleaved
        
        outputDesc.mBytesPerFrame = (isNonInterleaved == kLinearPCMFormatFlagIsNonInterleaved
            ? UInt32(1) : outputDesc.mChannelsPerFrame) * outputDesc.mBitsPerChannel / 8
        outputDesc.mBytesPerPacket = outputDesc.mBytesPerFrame
        
    }
    
    func read(frames: UnsafeMutablePointer<UInt32>, bufferData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        guard let fileRef = audioFileRef else {
            return -1
        }
        if readAvailable == false {
            frames.pointee = 0
            return -1
        }
        if isRepeat {
            var curFrameOffset: Int64 = 0
            // 获取文件头的位置
            if ExtAudioFileTell(fileRef, &curFrameOffset) == noErr {
                if curFrameOffset >= totalFrames {
                    // 返回到原点
                    if ExtAudioFileSeek(fileRef, 0) != noErr {
                        frames.pointee = 0
                        resetReader()
                        return -1
                    }
                }
            }
        }
        let status = ExtAudioFileRead(fileRef, frames, bufferData)
        if status != noErr {
            resetReader()
        }
        return status
    }
    
    
}
