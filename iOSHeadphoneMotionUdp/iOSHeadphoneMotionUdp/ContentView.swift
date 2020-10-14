//
//  ContentView.swift
//  iOSHeadphoneMotionUdp
//
//  Created by takanakahiko on 2020/09/27.
//

import SwiftUI
import CoreMotion
import Network

class Data: ObservableObject {
    @Published var motion: CMDeviceMotion?
    
    var hmm = CMHeadphoneMotionManager()
    var connection: NWConnection
    var isConnectionReady = false
    init() {
        connection = NWConnection(host: "192.168.3.3", port: 41234, using: NWParameters.udp)
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            switch(state) {
            case .ready:
                print("ready")
                self.isConnectionReady = true
            case .waiting(let error):
                print("waiting")
                print(error)
            case .failed(let error):
                print("failed")
                print(error)
            default:
                print("defaults")
                break
            }
        }
        let connectionQueue = DispatchQueue(label: "ExampleNetwork")
        connection.start(queue: connectionQueue)
        
        hmm.startDeviceMotionUpdates(to: .main) { (receivedMotion, error) in
            if let receivedMotion = receivedMotion {
                self.motion = receivedMotion
                if self.isConnectionReady {
                    let motionString = """
                    {
                        "QuaternionX":           \(receivedMotion.attitude.quaternion.x),
                        "QuaternionY":           \(receivedMotion.attitude.quaternion.y),
                        "QuaternionZ":           \(receivedMotion.attitude.quaternion.z),
                        "QuaternionW":           \(receivedMotion.attitude.quaternion.w),
                        "UserAccelX":            \(receivedMotion.userAcceleration.x),
                        "UserAccelY":            \(receivedMotion.userAcceleration.y),
                        "UserAccelZ":            \(receivedMotion.userAcceleration.z),
                        "RotationRateX":         \(receivedMotion.rotationRate.x),
                        "RotationRateY":         \(receivedMotion.rotationRate.y),
                        "RotationRateZ":         \(receivedMotion.rotationRate.z),
                        "MagneticFieldX":        \(receivedMotion.magneticField.field.x),
                        "MagneticFieldY":        \(receivedMotion.magneticField.field.y),
                        "MagneticFieldZ":        \(receivedMotion.magneticField.field.z),
                        "MagneticFieldAccuracy": \(receivedMotion.magneticField.accuracy.rawValue),
                        "Heading":               \(receivedMotion.heading)
                    }
                    """
                    let data = motionString.data(using: .utf8)
                    let completion = NWConnection.SendCompletion.contentProcessed { (error: NWError?) in
                        if let error = error {
                            print("error")
                            print(error)
                        }
                        print("送信完了")
                    }
                    self.connection.send(content: data, completion: completion)
                }
            }
            if let error = error {
                print(error)
                self.hmm.stopDeviceMotionUpdates()
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
