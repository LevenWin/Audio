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
    
    func config(path: String) {
        if let curlRef = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, UnsafePointer<UInt8>(path), path.count, false) {
            self.curlRef = curlRef
        }

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
