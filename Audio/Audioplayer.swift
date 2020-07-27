//
//  Audioplayer.swift
//  Audio
//
//  Created by leven on 2020/7/14.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import AudioUnit

class AudioPlayer {
    class Info {
        var mDataFormat: AudioStreamBasicDescription? = nil
        var mQueue: AudioQueueRef? = nil
        var mBuffers: [AudioQueueBufferRef] = []
        var mBufferSize: Int = 0
        var audioSize: UInt64 = 0
        var fileRef: AudioFileID? = nil
        var outNumPacketToRead: UInt32 = 0
        var packetDescs: UnsafeMutablePointer<AudioStreamPacketDescription>? =  nil
        
        var currentPacket: UInt64 = 0
    }
    
    var isRunning = false
    var isInitFinish = false
    var info = Info()
    var audioBufferQueue = AudioQueueProcess()
    
    var didPlayToEnd: (() -> ())?
    var didPlayToProgress: ((Progress) -> ())?

    private(set) var progress: Progress = Progress()
    
    var currentPlaySize: UInt32 = 0
    
    
    func startPlay() {
        if self.isInitFinish {
            
            let status = AudioQueueStart(info.mQueue!, nil)
            isRunning = true
            while isRunning {
                CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.25, false)
            }
            
            if status != noErr {
               print("播放失败！！")
            }
        }
    }
    
    func pauseAudioPlayer() {
        if self.isRunning {
            if AudioQueuePause(info.mQueue!)  == noErr {
                self.isRunning = false
            }
        }
    }
    
    func resumePlayer() {
        let status = AudioQueueStart(info.mQueue!, nil)
        if status == noErr {
            
        }
        
    }
    
    var HandeOutputBuffer: AudioQueueOutputCallback?
    
    
    func configAudio(path: String) {
        info.mDataFormat = getASBD(filePath: path)
        info.mBufferSize = 8192
        
        HandeOutputBuffer = { inUserData, inAQ, inBuffer in
            
            guard let p = inUserData else { return }
            let player = Unmanaged<AudioPlayer>.fromOpaque(p).takeUnretainedValue()
            guard let fileRef = player.info.fileRef else { return }
            
        
            
            var bufferSize = UInt32(player.info.mBufferSize)
            var packetToRead = UInt32(player.info.outNumPacketToRead)
            let status = AudioFileReadPacketData(fileRef,
                                                 false,
                                                 &bufferSize,
                                                 player.info.packetDescs,
                                                 (Int64(player.info.currentPacket)),
                                                 &packetToRead, inBuffer.pointee.mAudioData)
            
            
            if packetToRead > 0 {
                inBuffer.pointee.mAudioDataByteSize = bufferSize
                
                if player.info.mDataFormat!.mBytesPerPacket - 0 > 0 && player.info.mDataFormat!.mFramesPerPacket - 0 > 0 {
                    player.info.packetDescs = nil
                }
                
                if AudioQueueEnqueueBuffer(inAQ,
                                           inBuffer,
                                           player.info.packetDescs == nil ? 0 : packetToRead,
                                           player.info.packetDescs) == noErr {
                    player.currentPlaySize += bufferSize
                    print(String(format: "%.2f", Float(player.currentPlaySize) / Float( player.info.audioSize)))
                    if player.currentPlaySize == player.info.audioSize {
//                        player.didPlayToEnd?()
                    }
                    player.progress.totalUnitCount = Int64(player.info.audioSize)
                    player.progress.completedUnitCount = Int64(player.currentPlaySize)
                    player.didPlayToProgress?(player.progress)
                    player.info.currentPacket += UInt64(packetToRead)
                    print("取出 \(bufferSize) 字节，\(packetToRead)包， 总取出\(player.currentPlaySize)字节，歌曲大小为\(player.info.audioSize)")
                } else {
                    print("入对失败！")
                }
                
            } else {
                print("真的一滴都没了！")
            }
        }
        
        
        let listener: AudioQueuePropertyListenerProc = { inUserData, inAQ, inBuffer in
            guard let p = inUserData else { return }
            let player = Unmanaged<AudioPlayer>.fromOpaque(p).takeUnretainedValue()
            var isRunning: UInt32 = 0
            var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
            if AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size) == noErr {
                player.isRunning = isRunning > 0
            } else {
                player.isRunning = false
            }
            print("播放状态改变! \(player.isRunning)")

        }
        
        if var mDataFormat = info.mDataFormat, let fileRef = info.fileRef {
            let point = Unmanaged.passUnretained(self).toOpaque()
            // 生成AudioQueue
            var status = AudioQueueNewOutput(&mDataFormat, HandeOutputBuffer!, point, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &info.mQueue)
            guard let mQueue = info.mQueue else { return }
            if status != noErr { return }
            
            // 播放状态回调
            status = AudioQueueAddPropertyListener(mQueue, kAudioQueueProperty_IsRunning, listener, point)
            
            if status != noErr { return }
            
            var size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            
            
            
            status = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &mDataFormat, &size)
            
            if status != noErr { return }
            

            size = UInt32(MemoryLayout<UInt32>.size)
            

            
            if size > 0 {
                let cookie = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 8)
                status = AudioFileGetProperty(fileRef, kAudioFilePropertyMagicCookieData, UnsafeMutablePointer.init(&size), cookie)
                if status == noErr {
                    status = AudioQueueSetProperty(mQueue, kAudioQueueProperty_MagicCookie, cookie, size)
                }
            }
                    
            // Volume
            status = AudioQueueSetParameter(mQueue, kAudioQueueParam_Volume, 1.0)

            if status != noErr { return }
            
            deriveBufferSize()
            
 
            isInitFinish = true
        }
        
    }
    
    func deriveBufferSize() {
        let maxBufferSize = 0x50000
        let minBufferSize = 0x4000
        let second = 0.5
        guard let ASBDesc = info.mDataFormat, let fileRef = info.fileRef else { return }
        
        var maxPacketSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        var maxSizeData: UInt32 = 0
        var status =  AudioFileGetProperty(fileRef, kAudioFilePropertyPacketSizeUpperBound, UnsafeMutablePointer.init(&maxPacketSize), UnsafeMutableRawPointer(&maxSizeData))
        
        if ASBDesc.mFramesPerPacket > 1 {
            let numPacketForTime = ASBDesc.mSampleRate / Double(ASBDesc.mFramesPerPacket) * second
            
            info.mBufferSize = Int(numPacketForTime * Double(maxSizeData))
        } else {
            info.mBufferSize = maxBufferSize > maxSizeData ? maxBufferSize : Int(maxSizeData)
        }
        
        if info.mBufferSize > maxBufferSize &&  maxBufferSize > maxSizeData {
            info.mBufferSize = maxBufferSize
        } else if info.mBufferSize < minBufferSize {
            info.mBufferSize = minBufferSize
        }
        
        
        info.outNumPacketToRead = UInt32(info.mBufferSize) / maxSizeData

        
        if ASBDesc.mBytesPerPacket == 0 || ASBDesc.mFramesPerPacket == 0 {
            info.packetDescs = UnsafeMutablePointer.allocate(capacity: MemoryLayout<AudioStreamPacketDescription>.size * Int(info.outNumPacketToRead))
            
        } else {
            info.packetDescs = nil
        }
        
        var cookieDataSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        
        status = AudioFileGetPropertyInfo(fileRef, kAudioFilePropertyMagicCookieData, &cookieDataSize, nil)
        if status == noErr, cookieDataSize > 0 {
            let cookieData = UnsafeMutableRawPointer.allocate(byteCount: Int(cookieDataSize), alignment: 8)
            status = AudioFileGetProperty(fileRef, kAudioFilePropertyMagicCookieData,  &cookieDataSize, cookieData)
            
            status = AudioQueueSetProperty(info.mQueue!, kAudioQueueProperty_MagicCookie, cookieData, cookieDataSize)
            
        }
        
        let selfPoint = Unmanaged.passUnretained(self).toOpaque()

        for _ in 1 ... 3 {
             var buffer: AudioQueueBufferRef? = nil
             status = AudioQueueAllocateBuffer(info.mQueue!, UInt32(info.mBufferSize), &buffer)
             if let b = buffer {
                info.mBuffers.append(b)
                HandeOutputBuffer?(selfPoint, info.mQueue!, b)
             }
         }
        
        
    }
    
    func getASBD(filePath: String) -> AudioStreamBasicDescription? {
         if let curlRef = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, UnsafePointer<UInt8>(filePath), filePath.count, false) {
         
             var fileRef: AudioFileID? = nil
             var status = AudioFileOpenURL(curlRef, AudioFilePermissions.readPermission, 0, &fileRef)
             
             if status != 0 {
                 return nil
             }

             var desc: AudioStreamBasicDescription  = AudioStreamBasicDescription()
             var dataFormatSize:UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
             guard let ref = fileRef  else {
                 return nil
             }
            info.fileRef = ref
             
            status = AudioFileGetProperty(ref, kAudioFilePropertyDataFormat, &dataFormatSize, &desc)
            if status != 0 { return nil }
            
            var size = UInt32(MemoryLayout<UInt64>.size)
                 
            status = AudioFileGetProperty(ref, kAudioFilePropertyAudioDataByteCount, &size, &(info.audioSize))
            
//            var cookieDataSize = UInt32(MemoryLayout<UInt32>.size)
//
//            status = AudioFileGetPropertyInfo(ref, kAudioFilePropertyMagicCookieData, &cookieDataSize, nil)
//
//            if cookieDataSize > 0 {
//                   let cookie = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 8)
//                   status = AudioFileGetProperty(ref, kAudioFilePropertyMagicCookieData, UnsafeMutablePointer.init(&size), cookie)
//                   if status == noErr {
//                   }
//
//            }
                        
            
            
            return desc
            
        }
        return nil
    }

    
    
}

