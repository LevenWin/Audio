//
//  AudioUnitDemo.swift
//  Audio
//
//  Created by leven on 2020/7/24.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import AVFoundation
import AudioUnit
import AudioToolbox

class AudioUnitManager {
    
    struct Info {
        var mAudioUnit: AudioUnit?
        var mBuffers: AudioBufferList?
        var mAudioFormat: AudioStreamBasicDescription?
        var isRunning: Bool = false
        var auGraph: AUGraph?
        var callback: AURenderCallbackStruct?
    }
    
    var info: Info = Info()
    
    init() {
        config()
    }
    
    func config() {
        
        var status = noErr
        
        // init desc
        var mAudioFormat = AudioStreamBasicDescription()
        mAudioFormat.mSampleRate = AVAudioSession.sharedInstance().preferredSampleRate
        mAudioFormat.mChannelsPerFrame = UInt32(AVAudioSession.sharedInstance().preferredInputNumberOfChannels)
        mAudioFormat.mFormatID = kAudioFormatLinearPCM
        if mAudioFormat.mFormatID == kAudioFormatLinearPCM {
            mAudioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
            mAudioFormat.mBitsPerChannel = 16
            mAudioFormat.mBytesPerFrame = (mAudioFormat.mBitsPerChannel) / 8 * mAudioFormat.mChannelsPerFrame
            mAudioFormat.mBytesPerPacket = mAudioFormat.mBytesPerFrame
            mAudioFormat.mFramesPerPacket = 1
        }
        info.mAudioFormat = mAudioFormat
        
        do {
            try?         AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.01)
            try?         AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try?         AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        }
        
        // init Audio Unit
        var audioUnit: AudioUnit?
        var audioDesc = AudioComponentDescription()
        audioDesc.componentType = kAudioUnitType_Output
        audioDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO
        audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple
        audioDesc.componentFlags = 0
        audioDesc.componentFlagsMask = 0
        
        let component = AudioComponentFindNext(nil, &audioDesc)
        status = AudioComponentInstanceNew(component!, &audioUnit)
        if status != noErr {}
        guard let validAudioUnit = audioUnit else { return }
        info.mAudioUnit = validAudioUnit
        // init Buffer
        var flag: UInt32 = 0
        if status != noErr {}
        
        let numBuffers = 1

        let buffer = AudioBuffer(mNumberChannels: info.mAudioFormat?.mChannelsPerFrame ?? 1, mDataByteSize: 2048 * 2 * 10, mData: UnsafeMutableRawPointer.allocate(byteCount: Int(2048 * 2 * 10), alignment: 8))
        info.mBuffers = AudioBufferList(mNumberBuffers: UInt32(numBuffers), mBuffers: buffer)
        
        

        
        if status != noErr {}
        
        flag = 1
        // 打开录音
        status = AudioUnitSetProperty(validAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flag, UInt32(MemoryLayout<UInt32>.size))
        if status != noErr {}
        // 打开播放
        status = AudioUnitSetProperty(validAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flag, UInt32(MemoryLayout<UInt32>.size))
        
        // 设置播放的音频格式
        status = AudioUnitSetProperty(validAudioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      1,
                                      &mAudioFormat,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
         // 设置录制的音频格式
        status = AudioUnitSetProperty(validAudioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      0,
                                      &mAudioFormat,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size))

        // 录音的回调
        let inputCallBack: AURenderCallback = { inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData in
            let manager = Unmanaged<AudioUnitManager>.fromOpaque(inRefCon).takeUnretainedValue()
            manager.info.mBuffers?.mNumberBuffers = 1
            let status = AudioUnitRender(manager.info.mAudioUnit!,
                            ioActionFlags,
                            inTimeStamp,
                            inBusNumber,
                            inNumberFrames,
                            &(manager.info.mBuffers!))
            return status
        }
        
        // 播放的l回调
        let renderCallBack: AURenderCallback = { inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData in
            let manager = Unmanaged<AudioUnitManager>.fromOpaque(inRefCon).takeUnretainedValue()
            ioData?.pointee.mBuffers = manager.info.mBuffers!.mBuffers
            ioData?.pointee.mNumberBuffers = manager.info.mBuffers!.mNumberBuffers
            return noErr
        }
        
        var renderCallBackIns = AURenderCallbackStruct(inputProc: inputCallBack, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())

        // 设置声音采集回调函数
        status = AudioUnitSetProperty(validAudioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &renderCallBackIns, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        
        // 设置声音输出回调函数。 需要声音的时候，会回调。
        renderCallBackIns = AURenderCallbackStruct(inputProc: renderCallBack, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        status = AudioUnitSetProperty(validAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &renderCallBackIns, UInt32(MemoryLayout<AURenderCallbackStruct>.size))

        flag = 0
        status = AudioUnitSetProperty(validAudioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, 1, &flag, UInt32(MemoryLayout<UInt32>.size))
        
        
        
        status = AudioUnitInitialize(validAudioUnit)

        
    }
    
    func start() {
        if info.isRunning == false {
            let status = AudioOutputUnitStart(info.mAudioUnit!)
            print(status)
            info.isRunning = true
        }
        
    }
    func stop() {
        if info.isRunning == true {
            let status = AudioOutputUnitStop(info.mAudioUnit!)
            info.isRunning = false
            print(status)
        }
    }
}
