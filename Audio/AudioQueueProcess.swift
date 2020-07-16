//
//  AudioQueueProcess.swift
//  Audio
//
//  Created by leven on 2020/7/14.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

class AudioQueueProcess {
    enum Mode {
        case work
        case free
    }
    
    class Node {
        var data: UnsafeMutableRawPointer? = nil
        var size: Int = 0
        var index: Int = 0
        var userData: UnsafeRawPointer? = nil
        var next: Node?
    }
    
    class Queue {
        var size: Int = 0
        var front: Node?
        var rear: Node?
        var type: Mode = .work
    }
    
    lazy var free_queue: Queue = {
        let queue = Queue()
        queue.type = .free
        return queue
    }()
    
    lazy var work_queue: Queue = {
        let queue = Queue()
        queue.type = .work
        return queue
    }()
    
    private var free_queue_lock: pthread_mutex_t = pthread_mutex_t()
    private var work_queue_lock: pthread_mutex_t = pthread_mutex_t()
    
    static var nodeIndex = 0
    
    init() {
        for _ in 1 ... 20 {
            let node = Node()
            node.data = UnsafeMutableRawPointer.allocate(byteCount: 8192, alignment: 8)
            node.size = 0
            node.index = 0
            self.enQueue(queue: free_queue, node: node)
        }
    }
    
    func enQueue(queue: Queue, node: Node) {
        if queue.type == .free {
            pthread_mutex_lock(&free_queue_lock)
            if queue.front == nil {
                queue.front = node
                queue.rear = node
            } else {
                node.next = queue.front
                queue.front = node
            }
            queue.size += 1
            pthread_mutex_unlock(&free_queue_lock)
        } else {
            pthread_mutex_lock(&work_queue_lock)
            AudioQueueProcess.nodeIndex += 1
            node.index = AudioQueueProcess.nodeIndex
            
            if queue.front == nil {
                queue.front = node
                queue.rear = node
            } else {
                queue.rear?.next = node
                queue.rear = node
            }
            queue.size += 1
            
            pthread_mutex_unlock(&work_queue_lock)
        }
    }
    
    func deQueue(queue: Queue) -> Node? {
        var locker: pthread_mutex_t
        if queue.type == .work {
            locker = work_queue_lock
        } else {
            locker = free_queue_lock
        }
        pthread_mutex_lock(&locker)
        
        defer {
            pthread_mutex_unlock(&locker)
        }
        
        if let node = queue.front, queue.size > 0 {
            queue.front = queue.front?.next
            queue.size -= 1
            return node
        } else {
            return nil
        }
    }
    
    func resetQueue() {
        let size = work_queue.size
        for _ in [1...size] {
            if let node = deQueue(queue: work_queue) {
                node.data = nil
                enQueue(queue: free_queue, node: node)
            }
        }
    }
    

    
    
}
