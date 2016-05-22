//
//  TransportTests.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/21/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

@testable import Embassy

class TransportTests: XCTestCase {
    let queue = dispatch_queue_create("com.envoy.embassy-tests.event-loop", DISPATCH_QUEUE_SERIAL)
    func testBigChunkReadAndWrite() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        var clientReceivedData: [String] = []
        var serverReceivedData: [String] = []
        var totalReceivedSize = 0
        let dataChunk1 = makeRandomString(128)
        let dataChunk2 = makeRandomString(5743)
        let dataChunk3 = makeRandomString(2731)
        let dataChunk4 = makeRandomString(538)
        let dataChunk5 = makeRandomString(2048)
        let dataChunk6 = makeRandomString(1)
        let totalDataSize = [
            dataChunk1,
            dataChunk2,
            dataChunk3,
            dataChunk4,
            dataChunk5,
            dataChunk6
        ].reduce(0) { $0.0 + $0.1.characters.count }
        
        let clientSocket = try! TCPSocket()
        let clientTransport = Transport(socket: clientSocket, eventLoop: loop) { data in
            clientReceivedData.append(String(bytes: data, encoding: NSUTF8StringEncoding)!)
            totalReceivedSize += clientReceivedData.last!.characters.count
            if totalReceivedSize >= totalDataSize {
                loop.stop()
            }
        }
        var acceptedSocket: TCPSocket!
        var serverTransport: Transport!
        
        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            serverTransport = Transport(socket: acceptedSocket, eventLoop: loop) { data in
                serverReceivedData.append(String(bytes: data, encoding: NSUTF8StringEncoding)!)
                totalReceivedSize += serverReceivedData.last!.characters.count
                if totalReceivedSize >= totalDataSize {
                    loop.stop()
                }
            }
        }
        
        try! clientSocket.connect("::1", port: port)

        
        loop.callLater(1) {
            clientTransport.writeUTF8(dataChunk1)
        }
        loop.callLater(2) {
            serverTransport.writeUTF8(dataChunk2)
        }
        loop.callLater(3) {
            clientTransport.writeUTF8(dataChunk3)
        }
        loop.callLater(4) {
            serverTransport.writeUTF8(dataChunk4)
        }
        loop.callLater(5) {
            clientTransport.writeUTF8(dataChunk5)
        }
        loop.callLater(6) {
            serverTransport.writeUTF8(dataChunk6)
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(30 * NSEC_PER_SEC)), queue) {
            loop.stop()
        }
        
        loop.runForever()
        
        XCTAssertEqual(serverReceivedData.joinWithSeparator(""), [
            dataChunk1,
            dataChunk3,
            dataChunk5
        ].joinWithSeparator(""))
        XCTAssertEqual(clientReceivedData.joinWithSeparator(""), [
            dataChunk2,
            dataChunk4,
            dataChunk6
        ].joinWithSeparator(""))
    }
    
    func testReadAndWrite() {
        let loop = try! EventLoop(selector: try! KqueueSelector())
        
        let port = try! getUnusedTCPPort()
        let listenSocket = try! TCPSocket()
        try! listenSocket.bind(port)
        try! listenSocket.listen()
        
        var clientReceivedData: [String] = []
        var serverReceivedData: [String] = []
        
        let clientSocket = try! TCPSocket()
        let clientTransport = Transport(socket: clientSocket, eventLoop: loop) { data in
            clientReceivedData.append(String(bytes: data, encoding: NSUTF8StringEncoding)!)
            if clientReceivedData.count >= 3 && serverReceivedData.count >= 3 {
                loop.stop()
            }
        }
        var acceptedSocket: TCPSocket!
        var serverTransport: Transport!
        
        loop.setReader(listenSocket.fileDescriptor) {
            acceptedSocket = try! listenSocket.accept()
            serverTransport = Transport(socket: acceptedSocket, eventLoop: loop) { data in
                serverReceivedData.append(String(bytes: data, encoding: NSUTF8StringEncoding)!)
                if clientReceivedData.count >= 3 && serverReceivedData.count >= 3 {
                    loop.stop()
                }
            }
        }
        
        try! clientSocket.connect("::1", port: port)
        
        loop.callLater(1) {
            clientTransport.writeUTF8("a")
        }
        loop.callLater(2) {
            serverTransport.writeUTF8("1")
        }
        loop.callLater(3) {
            clientTransport.writeUTF8("b")
        }
        loop.callLater(4) {
            serverTransport.writeUTF8("2")
        }
        loop.callLater(5) {
            clientTransport.writeUTF8("c")
        }
        loop.callLater(6) {
            serverTransport.writeUTF8("3")
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(30 * NSEC_PER_SEC)), queue) {
            loop.stop()
        }
        
        loop.runForever()
        
        XCTAssertEqual(serverReceivedData, ["a", "b", "c"])
        XCTAssertEqual(clientReceivedData, ["1", "2", "3"])
    }

}