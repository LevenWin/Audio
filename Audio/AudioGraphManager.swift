//
//  AudioGraph.swift
//  Audio
//
//  Created by leven on 2020/7/27.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import AudioToolbox
import AudioUnit
import AVFoundation

class AudioGraphManager {
    enum AudioChannelType {
        case left
        case right
        case stereo
    }
    
    var outputPath: String?
    
    var mixInputCount: UInt32 = 2
    var channelTypes: [Int : AudioChannelType] = [:]
    var sourceStreamFormats: [Int : AVAudioFormat] = [:]

    var audioReaders1: AudioFileReader = AudioFileReader()
    var audioReaders2: AudioFileReader = AudioFileReader()

    var audioWriters: AudioFileWriter = AudioFileWriter()
    
    var mixerFormat: AudioStreamBasicDescription?
    
    var mPlayerGraph: AUGraph?
    
    var inputNode: AUNode = 0
    var inputNodeUnit: AudioUnit?

    var mixerNode: AUNode = 0
    var mixerNodeUnit: AudioUnit?
    
    var mAudioFormat = AudioStreamBasicDescription()
    var mBuffers: AudioBufferList?

    init() {
        config()
    }
    
    func config() {
    
        do {
            try?          AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.01)
            try?         AVAudioSession.sharedInstance().setCategory(.multiRoute)
            try?         AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        }
        
        var unitDesc = AudioComponentDescription()
        unitDesc.componentType = kAudioUnitType_Output
        unitDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO
        unitDesc.componentManufacturer = kAudioUnitManufacturer_Apple
        unitDesc.componentFlags = 0
        unitDesc.componentFlagsMask = 0
    
        
        var status = NewAUGraph(&mPlayerGraph)
        
        status = AUGraphOpen(mPlayerGraph!)

        if status != noErr {}

        // 构建io node
        status = AUGraphAddNode(mPlayerGraph!, &unitDesc, &inputNode)
        
        var mixerDesc = AudioComponentDescription()
        mixerDesc.componentType = kAudioUnitType_Mixer
        mixerDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer
        mixerDesc.componentManufacturer = kAudioUnitManufacturer_Apple
        mixerDesc.componentFlags = 0
        mixerDesc.componentFlagsMask = 0
        
        // 构建mix node
        status = AUGraphAddNode(mPlayerGraph!, &mixerDesc, &mixerNode)
        
        if status != noErr {}
        
        // 获取ioUnit
        status = AUGraphNodeInfo(mPlayerGraph!, inputNode, nil, &inputNodeUnit)
        // 获取mix Unit
        status = AUGraphNodeInfo(mPlayerGraph!, mixerNode, nil, &mixerNodeUnit)

        if status != noErr {}
        
        // 连接混响的输出和播放的输出
        status = AUGraphConnectNodeInput(mPlayerGraph!, mixerNode, 0, inputNode, 0)
        
        
        var oneFlag: UInt32 = 1
        // 开启输出
        status = AudioUnitSetProperty(inputNodeUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        if status != noErr {}
        // 开启输入
        status = AudioUnitSetProperty(inputNodeUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        if status != noErr {}
    
        
        let size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        let numBuffers = 1

        let buffer = AudioBuffer(mNumberChannels: mAudioFormat.mChannelsPerFrame, mDataByteSize: 2048 * 2 * 10, mData: UnsafeMutableRawPointer.allocate(byteCount: Int(2048 * 2 * 10), alignment: 8))
        mBuffers = AudioBufferList(mNumberBuffers: UInt32(numBuffers), mBuffers: buffer)
           
           
        // 录音的回调
//        let inputCallBack: AURenderCallback = { inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData in
//            let manager = Unmanaged<AudioGraphManager>.fromOpaque(inRefCon).takeUnretainedValue()
//            let status = AudioUnitRender(manager.inputNodeUnit!,
//                            ioActionFlags,
//                            inTimeStamp,
//                            inBusNumber,
//                            inNumberFrames,
//                            &(manager.mBuffers!))
//            return status
//        }
        
        
        
        // 播放的回调
        let renderCallBack: AURenderCallback = { inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData in
           
            if ioActionFlags.pointee.rawValue & AudioUnitRenderActionFlags.unitRenderAction_PostRender.rawValue == AudioUnitRenderActionFlags.unitRenderAction_PostRender.rawValue {
                let manager = Unmanaged<AudioGraphManager>.fromOpaque(inRefCon).takeUnretainedValue()
                var bufferData = AudioBufferData(bufferList: ioData?.pointee, numFrames: inNumberFrames)
                manager.audioWriters.receiveNewAudioBuffers(bufferData: ioData!, numFrames: inNumberFrames)

            }
            return noErr
        }
        
        // 录音的回调
//        var inputProc = AURenderCallbackStruct(inputProc: inputCallBack, inputProcRefCon: Unmanaged<AudioGraphManager>.passRetained(self).toOpaque())
        
//        status = AudioUnitSetProperty(inputNodeUnit!, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &inputProc, UInt32(MemoryLayout<AURenderCallbackStruct>.size))

        // 混响混合后的回调
        status = AudioUnitAddRenderNotify(mixerNodeUnit!, renderCallBack, Unmanaged<AudioGraphManager>.passRetained(self).toOpaque())
        
        setChannelType()
        setStreamFormats()
        setupAudioReadersAndWriters()

        
//        var flag = 0
//        status = AudioUnitSetProperty(inputNodeUnit!, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, 1, &flag, UInt32(MemoryLayout<UInt32>.size))
        
        status = AUGraphInitialize(mPlayerGraph!)
        
        status = AUGraphUpdate(mPlayerGraph!, nil)
    }
    
    func setChannelType() {
        self.channelTypes[1] = .stereo
        self.channelTypes[2] = .stereo
    }
    
    func setStreamFormats() {
        for i in 1 ... mixInputCount {
            // 立体声
            if self.channelTypes[Int(i)] == .stereo {
                self.sourceStreamFormats[Int(i)] = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)
            } else {
                self.sourceStreamFormats[Int(i)] = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: true)

            }
        }
        mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)?.streamDescription.pointee
        
        mAudioFormat.mSampleRate = AVAudioSession.sharedInstance().preferredSampleRate
        mAudioFormat.mFormatID = kAudioFormatLinearPCM
        mAudioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        mAudioFormat.mFramesPerPacket = 1
        mAudioFormat.mBitsPerChannel = 16
        mAudioFormat.mChannelsPerFrame = 1
        mAudioFormat.mBytesPerFrame = mAudioFormat.mBitsPerChannel * mAudioFormat.mFramesPerPacket / 8
        mAudioFormat.mBytesPerPacket = mAudioFormat.mBytesPerFrame * mAudioFormat.mFramesPerPacket
        mAudioFormat.mReserved = 0
        
    
        var status = AudioUnitSetProperty(inputNodeUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &mAudioFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var flag: UInt32 = 1
        status = AudioUnitSetProperty(inputNodeUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flag, UInt32(MemoryLayout<UInt32>.size))
        
        status = AudioUnitSetProperty(mixerNodeUnit!, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 1, &mixInputCount, UInt32(MemoryLayout<UInt32>.size))
        
        // 混响的回调
        let mixerRenderCallback: AURenderCallback = {inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData in
            let manager = Unmanaged<AudioGraphManager>.fromOpaque(inRefCon).takeUnretainedValue()
            var inNumberFrames = inNumberFrames
            var status = noErr
            if inBusNumber == 0 {
                // 文件音频数据
                manager.readAudioFile(inNumFrames: &inNumberFrames, toBuffer: ioData!)
            } else {
                // 录音数据
                status = AudioUnitRender(manager.inputNodeUnit!, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData!)
            }
            
            return status
        }
        
        // 每个输入源的回调函数
        for i in 0 ..< mixInputCount {
            var mixerInputCallback = AURenderCallbackStruct(inputProc: mixerRenderCallback, inputProcRefCon: Unmanaged<AudioGraphManager>.passUnretained(self).toOpaque())
            status = AUGraphSetNodeInputCallback(mPlayerGraph!, mixerNode, i, &mixerInputCallback)
            if i == mixInputCount - 1 {
                // 录音数据输出到mixer node
                status = AudioUnitSetProperty(mixerNodeUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &mAudioFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
                status = AudioUnitSetParameter(mixerNodeUnit!, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1, 0)
            } else{
                // 音频数据输出到mixer node
                status = AudioUnitSetProperty(mixerNodeUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &mixerFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
                status = AudioUnitSetParameter(mixerNodeUnit!, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1, 0)
            }
            status = AudioUnitSetParameter(mixerNodeUnit!, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, i, 1, 0)
            
        }
        // 设置mixer 数据输出的格式
        status = AudioUnitSetProperty(mixerNodeUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mixerFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        
        // 设置mix输出音量
        status = AudioUnitSetParameter(mixerNodeUnit!, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0)
        
        // 设置
    }
    
    func readAudioFile(inNumFrames: UnsafeMutablePointer<UInt32>, toBuffer: UnsafeMutablePointer<AudioBufferList>) {
        let status = self.audioReaders1.read(frames: inNumFrames, bufferData: toBuffer)
        print(status)
    }
    
    func setupAudioReadersAndWriters() {
        audioReaders1.isRepeat = true
        audioReaders1.desireFormat = self.sourceStreamFormats[1]?.streamDescription.pointee
        audioReaders1.filePath = Bundle.main.path(forResource: "like", ofType: "mp3")

        audioWriters.fileType = kAudioFileM4AType
        audioWriters.audioDesc = mixerFormat!
    }
    func start() {
        audioWriters.updateFilePath(outputPath ?? "")
        
        let status = AUGraphStart(mPlayerGraph!)
        print(status)
    }
    func stop() {
        let status = AUGraphStop(mPlayerGraph!)
        audioWriters.close()
        audioReaders1.resetReader()
        print(status)
    }
}
