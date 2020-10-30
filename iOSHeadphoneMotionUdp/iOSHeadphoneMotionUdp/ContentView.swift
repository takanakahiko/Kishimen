//
//  ContentView.swift
//  iOSHeadphoneMotionUdp
//
//  Created by takanakahiko on 2020/09/27.
//

import SwiftUI
import CoreMotion
import Network

struct Motion: Codable {
    var attitude: Attitude
    var rotationRate: RotationRate
    var gravity: Acceleration
    var userAcceleration: Acceleration
    var magneticField: CalibratedMagneticField
    var heading: Double
    var sensorLocation: Int
    var timestamp: TimeInterval
    
    struct Attitude: Codable {
        var roll: Double
        var pitch: Double
        var yaw: Double
        var rotationMatrix: RotationMatrix
        var quaternion: Quaternion
        
        struct RotationMatrix: Codable {
            var m11: Double
            var m12: Double
            var m13: Double
            var m21: Double
            var m22: Double
            var m23: Double
            var m31: Double
            var m32: Double
            var m33: Double
        }
        
        struct Quaternion: Codable {
            var x: Double
            var y: Double
            var z: Double
            var w: Double
        }
    }
    
    struct RotationRate: Codable {
        var x: Double
        var y: Double
        var z: Double
    }

    struct Acceleration: Codable {
        var x: Double
        var y: Double
        var z: Double
    }
    
    struct CalibratedMagneticField: Codable {
        var field: MagneticField
        var accuracy: Int32
        
        struct MagneticField: Codable {
            var x: Double
            var y: Double
            var z: Double
        }
        
        // これだとうまく receivedMotion.magneticField.accuracy を代入できなかった。たすけて。
        enum MagneticFieldCalibrationAccuracy: Int32, Codable {
            case uncalibrated = -1
            case low = 0
            case medium = 1
            case high = 2
        }
    }
    
    // これだとうまく receivedMotion.sensorLocation を代入できなかった。たすけて。
    enum SensorLocation : Int, Codable {
        case `default` = 0
        case headphoneLeft = -1
        case headphoneRight = -2
    }

}

struct UdpData: Codable {
    let motion: Motion
}

class ConnectionManager {
    
    private var connection: NWConnection?
    
    // Readonly なプロパティを実装したい場合ってこれでいいんだろうか
    var _isConnectionReady = false
    var isConnectionReady:Bool {
        get{
            return _isConnectionReady
        }
    }
    
    func connect(host: String, port: Int32) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: 41234, using: NWParameters.udp)
        if isConnectionReady {
            disconnect()
        }
        if let connection = connection {
            connection.stateUpdateHandler = { (state: NWConnection.State) in
                switch(state) {
                case .ready:
                    self._isConnectionReady = true
                case .waiting(let error):
                    print(error)
                case .failed(let error):
                    print(error)
                default:
                    break
                }
            }
            let connectionQueue = DispatchQueue(label: "ExampleNetwork")
            connection.start(queue: connectionQueue)
        }
    }
    
    func disconnect(){
        if let connection = connection {
            connection.cancel()
        }
        _isConnectionReady = false
    }
    
    func send(content: Foundation.Data, completion: NWConnection.SendCompletion) {
        if let connection = connection {
            connection.send(content: content, completion: completion)
        }
    }
}

class Data: ObservableObject {
    @Published var motion: CMDeviceMotion?
    @Published var address = "192.168.3.3"
    
    var hmm = CMHeadphoneMotionManager()
    var cm = ConnectionManager()
    
    init() {
        cm.connect(host: self.address, port: 41234)
        
        hmm.startDeviceMotionUpdates(to: .main) { (receivedMotion, error) in
            if let receivedMotion = receivedMotion {
                self.sendMotion(receivedMotion: receivedMotion)
            }
            if let error = error {
                print(error)
                self.hmm.stopDeviceMotionUpdates()
            }
        }
        
    }
    
    func sendMotion(receivedMotion: CMDeviceMotion) {
        self.motion = receivedMotion
        if self.cm.isConnectionReady {
            // このパースがヤバすぎるのでもう少しスマートに出来ないか
            // あるいは struct 定義とともに別のソースに移せないか
            let udpData = UdpData(
                motion: .init(
                    attitude: .init(
                        roll: receivedMotion.attitude.roll,
                        pitch: receivedMotion.attitude.pitch,
                        yaw: receivedMotion.attitude.yaw,
                        rotationMatrix: .init(
                            m11: receivedMotion.attitude.rotationMatrix.m11,
                            m12: receivedMotion.attitude.rotationMatrix.m12,
                            m13: receivedMotion.attitude.rotationMatrix.m13,
                            m21: receivedMotion.attitude.rotationMatrix.m21,
                            m22: receivedMotion.attitude.rotationMatrix.m22,
                            m23: receivedMotion.attitude.rotationMatrix.m23,
                            m31: receivedMotion.attitude.rotationMatrix.m31,
                            m32: receivedMotion.attitude.rotationMatrix.m32,
                            m33: receivedMotion.attitude.rotationMatrix.m33
                        ),
                        quaternion: .init(
                            x: receivedMotion.attitude.quaternion.x,
                            y: receivedMotion.attitude.quaternion.y,
                            z: receivedMotion.attitude.quaternion.z,
                            w: receivedMotion.attitude.quaternion.w
                        )
                    ),
                    rotationRate: .init(
                        x: receivedMotion.rotationRate.x,
                        y: receivedMotion.rotationRate.y,
                        z: receivedMotion.rotationRate.z
                    ),
                    gravity: .init(
                        x: receivedMotion.gravity.x,
                        y: receivedMotion.gravity.y,
                        z: receivedMotion.gravity.z
                    ),
                    userAcceleration: .init(
                        x: receivedMotion.userAcceleration.x,
                        y: receivedMotion.userAcceleration.y,
                        z: receivedMotion.userAcceleration.z
                    ),
                    magneticField: .init(
                        field: .init(
                            x: receivedMotion.magneticField.field.x,
                            y: receivedMotion.magneticField.field.y,
                            z: receivedMotion.magneticField.field.z
                        ),
                        accuracy: receivedMotion.magneticField.accuracy.rawValue
                    ),
                    heading: receivedMotion.heading,
                    sensorLocation: receivedMotion.sensorLocation.rawValue,
                    timestamp: receivedMotion.timestamp
                )
            )
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(udpData)
                print(String(data: data, encoding: .utf8)!)
                let completion = NWConnection.SendCompletion.contentProcessed { (error: NWError?) in
                    if let error = error {
                        print("error")
                        print(error)
                    }
                    print("送信完了")
                }
                self.cm.send(content: data, completion: completion)
            } catch {
                print("Unexpected error: \(error).")
            }
            
        }
    }
}

struct ContentView: View {
    @ObservedObject var data = Data()
    
    var body: some View {
        VStack {
            if let motion = data.motion {
                Text("motion = \(motion)").padding()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
