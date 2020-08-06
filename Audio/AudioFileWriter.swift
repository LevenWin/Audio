//
//  AudioFileWriter.swift
//  Audio
//
//  Created by leven on 2020/8/5.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import AudioToolbox
class AudioFileWriter {
    
    var fileType: AudioFileTypeID = kAudioFileAIFFType
     
    private(set) var filePath: String?
    
    var audioDesc: AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    private(set) var fileRef: ExtAudioFileRef?
    
    private(set) var bufferData: AudioBufferData?
    
    func updateFilePath(_ filePath: String) {
        self.filePath = filePath
        configAudioFile()
    }
    
    func configAudioFile() {
        if var filePath = filePath, audioDesc.mSampleRate != 0, fileType != 0 {
            filePath = filePath + "." + pathExtension(fileType: fileType)
            let recordUrl = URL(fileURLWithPath: filePath)
            // 有损压缩格式
            let fileDir = recordUrl.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: fileDir.absoluteString) == false {
                do {
                    try? FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true, attributes: nil)
                }
            }
            var outputDesc = AudioStreamBasicDescription()

            if fileType == kAudioFileM4AType {
                outputDesc.mFormatID = kAudioFormatMPEG4AAC
                outputDesc.mFormatFlags = AudioFormatFlags(MPEG4ObjectID.AAC_LC.rawValue)
                outputDesc.mChannelsPerFrame = audioDesc.mChannelsPerFrame
                outputDesc.mSampleRate = audioDesc.mSampleRate
                outputDesc.mFramesPerPacket = 1024
                outputDesc.mBytesPerFrame = 0
                outputDesc.mBytesPerPacket = 0
                outputDesc.mBitsPerChannel = 0
                outputDesc.mReserved = 0
            } else if fileType == kAudioFileCAFType || fileType == kAudioFileWAVEType {
                outputDesc.mFormatID = kAudioFormatLinearPCM;
                outputDesc.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
                outputDesc.mChannelsPerFrame = 2;
                outputDesc.mSampleRate = audioDesc.mSampleRate;
                outputDesc.mFramesPerPacket = 1;
                outputDesc.mBytesPerFrame = 4;
                outputDesc.mBytesPerPacket = 4;
                outputDesc.mBitsPerChannel = 16;
                outputDesc.mReserved = 0;
            }
            
            var status = ExtAudioFileCreateWithURL(recordUrl as CFURL, fileType, &outputDesc, nil, AudioFileFlags.eraseFile.rawValue, &fileRef)
            let sizeUInt32 = UInt32(MemoryLayout<UInt32>.size)
            var codecManf = kAppleSoftwareAudioCodecManufacturer
            let descSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            status = ExtAudioFileSetProperty(fileRef!, kExtAudioFileProperty_CodecManufacturer, sizeUInt32, &codecManf)
            status = ExtAudioFileSetProperty(fileRef!, kExtAudioFileProperty_ClientDataFormat, descSize, &audioDesc)
            print(status)
        }
    }
    
//    func receiveNewAudioBuffers(bufferData: UnsafePointer<AudioBufferData>) -> OSStatus{
//        if let fileRef = fileRef, var bufferList = bufferData.pointee.bufferList {
//            let status = ExtAudioFileWrite(fileRef, bufferData.pointee.numFrames, &bufferList)
//            return status
//        }
//        return -1
//    }
//
    func receiveNewAudioBuffers(bufferData: UnsafePointer<AudioBufferList>, numFrames: UInt32) -> OSStatus{
        if let fileRef = fileRef {
            let status = ExtAudioFileWrite(fileRef, numFrames, bufferData)
            return status
        }
        return -1
    }
    func close() {
        if fileRef != nil {
            ExtAudioFileDispose(fileRef!)
            fileRef = nil
        }
    }
    
    func pathExtension(fileType: AudioFileTypeID) -> String {
        switch fileType {
        case kAudioFileM4AType:
            return "m4a"
        case kAudioFileWAVEType:
            return "wav"
        case kAudioFileCAFType:
            return "caf"
        default:
            return ""
        }
    }
}
