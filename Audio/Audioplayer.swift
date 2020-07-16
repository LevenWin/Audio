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
            for i in 0 ..< info.mBuffers.count {
                info.mBuffers[i].pointee.mAudioDataByteSize = UInt32(info.mBufferSize)
                let status =  AudioQueueEnqueueBuffer(info.mQueue!, info.mBuffers[i], 0, nil)
                print(status)
            }
            
            let status = AudioQueueStart(info.mQueue!, nil)
            if status == noErr {
                
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
    
    
    func configAudio(path: String) {
        info.mDataFormat = getASBD(filePath: path)
        info.mBufferSize = 8192
        
        let callbackProc: AudioQueueOutputCallback = { inUserData, inAQ, inBuffer in
            guard let p = inUserData else { return }
            let player = Unmanaged<AudioPlayer>.fromOpaque(p).takeUnretainedValue()
            if let node = player.audioBufferQueue.deQueue(queue: player.audioBufferQueue.work_queue) {
                if node.size > 0, let data = node.data {
                    
                    inBuffer.pointee.mAudioData.copyMemory(from: data, byteCount: node.size)
                    inBuffer.pointee.mAudioDataByteSize = UInt32(node.size)
                    if AudioQueueEnqueueBuffer(inAQ,
                                            inBuffer,
                                            0,
                                            nil) == noErr {
                        player.currentPlaySize += UInt32(node.size)
                        print(String(format: "%.2f", Float(player.currentPlaySize) / Float( player.info.audioSize)))
                        if player.currentPlaySize == player.info.audioSize {
                            player.didPlayToEnd?()
                        }
                        player.progress.totalUnitCount = Int64(player.info.audioSize)
                        player.progress.completedUnitCount = Int64(player.currentPlaySize)
                        player.didPlayToProgress?(player.progress)

        
                    }
                }
                
                player.audioBufferQueue.enQueue(queue: player.audioBufferQueue.free_queue, node: node)
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
        }
        
        if var mDataFormat = info.mDataFormat {
            let point = Unmanaged.passUnretained(self).toOpaque()
            var status = AudioQueueNewOutput(&mDataFormat, callbackProc, point, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &info.mQueue)
            guard let mQueue = info.mQueue else { return }
            if status != noErr { return }
            
            status = AudioQueueAddPropertyListener(mQueue, kAudioQueueProperty_IsRunning, listener, point)
            
            if status != noErr { return }
            
            var size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            
            status = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &mDataFormat, &size)
            
            if status != noErr { return }
            
            

//            status = AudioQueueSetProperty(mQueue, kAudioQueueProperty_StreamDescription, &mDataFormat, size)
            
            if status != noErr { return }
            
            status = AudioQueueSetParameter(mQueue, kAudioQueueParam_Volume, 1.0)

            if status != noErr { return }

            for _ in 1 ... 3 {
                var buffer: AudioQueueBufferRef? = nil
                status = AudioQueueAllocateBuffer(mQueue, UInt32(info.mBufferSize), &buffer)
                if let b = buffer {
                    info.mBuffers.append(b)
                }
            }
            isInitFinish = true
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
            
            return desc
            
        }
        return nil
    }

    
    
}

