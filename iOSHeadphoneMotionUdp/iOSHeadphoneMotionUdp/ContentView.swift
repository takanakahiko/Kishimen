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

struct ConnectionSetting {
    var address = "192.168.3.9"
    var port: UInt16 = 41234
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
    
    func connect(setting: ConnectionSetting) {
        
        if isConnectionReady {
            disconnect()
        }
        
        if let port = NWEndpoint.Port(rawValue: setting.port) {
            connection = NWConnection(
                host: NWEndpoint.Host(setting.address),
                port: port,
                using: NWParameters.udp
            )
        } else {
            print("invalid port number")
            return
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
    
    func send(content: Foundation.Data) {
        if let connection = connection {
            let completion = NWConnection.SendCompletion.contentProcessed { (error: NWError?) in
                if let error = error {
                    print("error")
                    print(error)
                }
                //print("送信完了")
            }
            connection.send(content: content, completion: completion)
        }
    }
}

// Data っていう命名はどう考えてもおかしいんだけど妥当な名前が思いつかない
class Data: ObservableObject {
    @Published var motion: CMDeviceMotion?
    @Published var connectionSetting = ConnectionSetting() {
        willSet {
            if started {
                restart()
            }
        }
    }
    @Published var started = false
    
    var hmm = CMHeadphoneMotionManager()
    var cm = ConnectionManager()
    
    init() {
        stop()
    }
    
    func restart() {
        stop()
        cm.connect(setting: connectionSetting)
        hmm.startDeviceMotionUpdates(to: .main) { (receivedMotion, error) in
            if let receivedMotion = receivedMotion {
                
                // 以下をコメントアウトするとUIが遅くなる(例えばSettingsModalを閉じるボタンが反応しない)
                // ここらへんのテクニックを使う必要がありそう https://stackoverflow.com/questions/63678438/swiftui-updating-ui-with-high-frequency-data
                // self.motion = receivedMotion
                
                self.sendMotion(receivedMotion: receivedMotion)
            }
            if let error = error {
                print(error)
                self.hmm.stopDeviceMotionUpdates()
            }
        }
        started = true
    }
    
    func stop() {
        hmm.stopDeviceMotionUpdates()
        cm.disconnect()
        started = false
    }
    
    func sendMotion(receivedMotion: CMDeviceMotion) {
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
                //print(String(data: data, encoding: .utf8)!)
                self.cm.send(content: data)
            } catch {
                print("Unexpected error: \(error).")
            }
            
        }
    }
}

struct SettingCard: View {
    var setting: ConnectionSetting
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading) {
                        Text("Address: \(setting.address)")
                            .fontWeight(.black)
                            .foregroundColor(.primary)
                        Text("Port: \(setting.port)")
                            .fontWeight(.black)
                            .foregroundColor(.primary)
                    }.padding(.vertical)
                    Text("Tap to edit settings".uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .layoutPriority(100)
                Spacer()
            }
            .padding()
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.sRGB, red: 150/255, green: 150/255, blue: 150/255, opacity: 0.1), lineWidth: 3)
        )
        .border(Color(.sRGB, red: 150/255, green: 150/255, blue: 150/255, opacity: 0.1), width: 3)
        .padding([.top, .horizontal])
    }
}

struct SettingModal: View {
    @Binding var showSheetView: Bool
    @Binding var setting: ConnectionSetting
    
    // ここらへんの実装が怪しいのでどうにかしたい
    // 外の State とは別に内部的に State を持ち、最後に Save を押したら外部の State に反映するというやつ
    @State private var settingInternal = ConnectionSetting()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading)  {

                Text("Address").font(.headline)
                TextField("Enter address...", text: $settingInternal.address)
                    .padding(.all)
                    .background(Color(red: 239.0/255.0, green: 243.0/255.0, blue: 244.0/255.0, opacity: 1.0))
                    .cornerRadius(5.0)
                
                Text("Port").font(.headline)
                TextField("Enter port...", value: $settingInternal.port, formatter: NumberFormatter())
                    .padding(.all)
                    .background(Color(red: 239.0/255.0, green: 243.0/255.0, blue: 244.0/255.0, opacity: 1.0))
                    .cornerRadius(5.0)
                
                Spacer()
                
            }
            .padding()
            .background(Color.init(red: 0.99, green: 0.99, blue: 0.99))
            .navigationBarTitle("Settings")
            .navigationBarItems(trailing: Button("Save"){
                print("Dismissing sheet view...")
                self.setting = self.settingInternal
                self.showSheetView = false
            })
        }.onAppear(perform: {
            print("initiarise internal state")
            settingInternal = setting
        })
    }
}

struct ContentView: View {
    @ObservedObject var data = Data()
    @State var showSheetView = false
    
    var body: some View {
        VStack()  {
            Spacer()
            StatusCircle(started: $data.started)
            Spacer()
            StartStopButton(started: $data.started, startFunc: data.restart, stopFunc: data.stop)
            Spacer()
            SettingCard(setting: data.connectionSetting)
                .onTapGesture {
                    self.showSheetView.toggle()
                }
                .sheet(isPresented: $showSheetView) {
                    SettingModal(
                        showSheetView: self.$showSheetView,
                        setting: self.$data.connectionSetting
                    )
                }
            Spacer()
        }.padding()
    }
}

struct StatusCircle: View {
    @Binding var started: Bool
    
    var body: some View{
        ZStack {
            Circle()
                .fill()
                .foregroundColor(self.started ? Color.green : Color.gray)
                .opacity(0.6)
                .frame(width: 200, height: 200)
            Text(self.started ? "Sending Now" : "Not working")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(.white)
        }
    }
}

struct StartStopButton: View {
    @Binding var started: Bool
    
    var startFunc: () -> Void
    var stopFunc: () -> Void
    
    var body: some View{
        HStack {
            Spacer()
            Button(action: startFunc) {
                Text("Start")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 30)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            Spacer()
            Button(action: stopFunc ) {
                Text("Stop")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 30)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            Spacer()
        }.padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SettingModal(
            showSheetView: .constant(true),
            setting: .constant(ConnectionSetting())
        )
    }
}

struct ContentView_Previews2: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.8, green: 0.8, blue: 0.8),
                Color(red: 0.95, green: 0.95, blue: 0.95)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                Spacer()
                StatusCircle(started: .constant(true))
                Spacer()
                StartStopButton(started: .constant(true), startFunc: {}, stopFunc: {})
                Spacer()
                SettingCard(setting: ConnectionSetting())
                Spacer()
            }
        }.edgesIgnoringSafeArea(.all)
    }
}
