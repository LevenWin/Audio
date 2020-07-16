//
//  ViewController.swift
//  Audio
//
//  Created by leven on 2020/7/13.
//  Copyright © 2020 leven. All rights reserved.
//

import UIKit
import AVFoundation
class ViewController: UIViewController {

    lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("播放", for: .normal)
        button.setTitle("暂停", for: .selected)
        button.setTitleColor(.orange, for: .normal)
        button.addTarget(self, action: #selector(didClickPlay), for: .touchUpInside)
        return button
    }()
    
    lazy var audioButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("录制", for: .normal)
        button.setTitle("结束", for: .selected)
        button.setTitleColor(.orange, for: .normal)
        button.addTarget(self, action: #selector(didClickRecord), for: .touchUpInside)
        return button
    }()
    
    var player = AudioPlayer()
    
    var fileHanlder = FileHandler()
    
    var progressView = UIView()
    var timer: Timer?
    
    @objc func didClickRecord() {
        self.audioButton.isSelected = !self.audioButton.isSelected
        if self.audioButton.isSelected {
            
        } else {
            
        }
        
    }
    
    @objc func didClickPlay() {
        self.playButton.isSelected = !self.playButton.isSelected

        if self.playButton.isSelected {
            prepareAudioData()
            player.startPlay()
        } else {
            player.pauseAudioPlayer()
        }
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        self.view.addSubview(self.playButton)
        self.view.addSubview(self.audioButton)
        var filePath = Bundle.main.path(forResource: "checkingiftdeny", ofType: "mp3") ?? ""
        filePath = Bundle.main.path(forResource: "testPCM", ofType: "caf") ?? ""

        fileHanlder.config(path: filePath)
        player.configAudio(path: filePath)
        
        player.didPlayToEnd = { [weak self] in
            self?.didClickPlay()
        }
        
        player.didPlayToProgress = { [weak self] progress in
            guard let self = self else {
                return
            }
            let rect = self.view.bounds
            let p = String(format: "%.2f", Float(self.player.currentPlaySize) / Float( self.player.info.audioSize))
            let width = rect.size.width * CGFloat(1.00 - (Double(p) ?? 0.0))
            UIView.animate(withDuration: 0.2) {
                    self.progressView.frame = CGRect(x: (rect.width - width) / 2.0, y: 150, width: width, height: 2)

            }
        }
        self.progressView.backgroundColor = .orange
        self.progressView.layer.cornerRadius = 1
        self.view.addSubview(self.progressView)
    }
    
    func prepareAudioData() {
        let packetDesc = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: MemoryLayout<AudioStreamPacketDescription>.size)
        timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self](timer) in
            guard let self = self else { return }
            if self.playButton.isSelected == false {
                timer.invalidate()
                self.fileHanlder.resetFile()
            } else {
                let audioData =  UnsafeMutableRawPointer.allocate(byteCount: 8192, alignment: 8)
                let readBytes = self.fileHanlder.readAudio(dataRef: audioData, packetDesc: packetDesc, readPacketNum: 4096)
                if readBytes > 0 {
                    let queueProcess = self.player.audioBufferQueue
                    if let node = queueProcess.deQueue(queue: queueProcess.free_queue) {
                        node.data?.copyMemory(from: audioData, byteCount: 8192)
                        node.size = Int(readBytes)
                        node.userData = UnsafeRawPointer.init(packetDesc)
                        queueProcess.enQueue(queue: queueProcess.work_queue, node: node)
                    }
                } else {
                    timer.invalidate()
                }
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
        timer?.fire()

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        playButton.frame = CGRect(x: 50, y: 100, width: 70, height: 35)
        audioButton.frame = CGRect(x: self.view.frame.size.width - 70 - 50, y: 100, width: 70, height: 35)

    }


}





