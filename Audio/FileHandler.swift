//
//  FileHandler.swift
//  Audio
//
//  Created by leven on 2020/7/15.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import AudioUnit
class FileHandler {
    
    var isPlayFileWorking = false
    
    var recordFilePath: String = ""
    
    var curlRef: CFURL? = nil
    var fileRef: AudioFileID? = nil
    
    var m_playCurrentPacket: Int64 = 0
    
    var m_recordCurrentPacket: Int64 = 0
    func config(path: String) {
        if let curlRef = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, UnsafePointer<UInt8>(path), path.count, false) {
            self.curlRef = curlRef
        }
    }
    
    func writefile(inNumBytes: UInt32, ioNumPackerts: UInt32, inBuffer: UnsafeMutableRawPointer, packetDesc: UnsafePointer<AudioStreamPacketDescription>?) {
        guard let fileId = self.fileRef else { return  }
        var ioNumPackerts = ioNumPackerts
        var inNumBytes = inNumBytes
        let status = AudioFileWriteBytes(fileId, false, m_recordCurrentPacket, &inNumBytes, inBuffer)
//        let status = AudioFileWritePackets(fileId,
//                                           false,
//                                           inNumBytes,
//                                           packetDesc,
//                                           m_recordCurrentPacket,
//                                           &ioNumPackerts,
//                                           inBuffer)
        
        m_recordCurrentPacket = Int64(inNumBytes) + m_recordCurrentPacket
        print("当前包: ", m_recordCurrentPacket)
        if status != noErr {print("写入失败！！")}
    }
    
    func stopRecord(queue: AudioQueueRef, needCookie: Bool) {
        if needCookie {
            copyCookieToFile(queue: queue, fileRef: fileRef!)
        }
        AudioFileClose(fileRef!)
        m_recordCurrentPacket = 0
    }
    
    func startRecord(queue: AudioQueueRef, needCookie: Bool, audioDesc: AudioStreamBasicDescription) {
        self.recordFilePath = generateRecordPath()
        var descFormate = audioDesc
        var fileID: AudioFileID? = nil
        let curlRef = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, UnsafePointer<UInt8>(recordFilePath), recordFilePath.count, false)
        let status = AudioFileCreateWithURL(curlRef!, kAudioFileAIFFType, &descFormate, AudioFileFlags.eraseFile, &fileID)
        if status != noErr {}
        self.curlRef = curlRef
        fileRef = fileID
        
        if let file = fileID, needCookie {
            copyCookieToFile(queue: queue, fileRef: file)
        }
        
        
    }
    
    func copyCookieToFile(queue: AudioQueueRef, fileRef: AudioFileID) {
        var size:UInt32  = 0
        var status = AudioQueueGetPropertySize(queue, kAudioQueueProperty_MagicCookie, &size)
        if status != noErr {}
        
        let cookie = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 8)
        status = AudioQueueGetProperty(queue, kAudioQueueProperty_MagicCookie, cookie, &size)
        if status != noErr {}
        
        status = AudioFileSetProperty(fileRef, kAudioFilePropertyMagicCookieData, size, cookie)
        if status != noErr {}
        
    }
    func generateRecordPath() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy_MM_dd__HH_mm_ss"
        
        let dateString = dateFormatter.string(from: Date())
        var searchPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
        searchPath = searchPath + "/Voice"
        
        if FileManager.default.fileExists(atPath: searchPath) == false {
            do {
                try! FileManager.default.createDirectory(at: URL(fileURLWithPath: searchPath), withIntermediateDirectories: true, attributes: nil)
            }
            
        }
        searchPath = searchPath.appending("/\(dateString).caf")
        return searchPath
    }
    
    func readAudio(dataRef: UnsafeMutableRawPointer,
                   packetDesc: UnsafeMutablePointer<AudioStreamPacketDescription>,
                   readPacketNum: UInt32) -> UInt32 {
        
        if self.isPlayFileWorking == false, let curlRef = self.curlRef {
            self.isPlayFileWorking = true
            
            if AudioFileOpenURL(curlRef, AudioFilePermissions.readPermission, kAudioFileCAFType, &fileRef) == noErr {
                
            }

        }
        
        var bytesRead: UInt32 = 8192
        var numPackets = readPacketNum
        let status =  AudioFileReadPacketData(fileRef!, false, &bytesRead, packetDesc, m_playCurrentPacket, &numPackets, dataRef)
        if status == noErr {
            
        }
        if bytesRead > 0 {
            m_playCurrentPacket += Int64(numPackets)
        } else {
            
        }
        return bytesRead
        
    }
    func resetFile() {
        if AudioFileClose(fileRef!) == noErr {
            
        }
        self.isPlayFileWorking = false
        self.m_playCurrentPacket = 0
    }

}
