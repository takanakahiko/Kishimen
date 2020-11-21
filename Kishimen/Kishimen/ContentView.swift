//
//  ContentView.swift
//  Kishimen
//
//  Created by takanakahiko on 2020/09/27.
//

import SwiftUI
import CoreMotion
import Network

struct ConnectionSetting {
    var address = "192.168.0.1"
    var port: UInt16 = 12345
}

var defaultKeyForAddress = "ConnectionSettingAdress"
var defaultKeyForPort = "ConnectionSettingPort"

func setDefaultConnectionSetting(setting: ConnectionSetting) {
    UserDefaults.standard.set(setting.address, forKey: defaultKeyForAddress)
    UserDefaults.standard.set(setting.port, forKey: defaultKeyForPort)
}

func loadDefaultConnectionSetting() -> ConnectionSetting {
    var setting = ConnectionSetting()
    if let address = UserDefaults.standard.string(forKey: defaultKeyForAddress) {
        setting.address = address
    }
    let port = UserDefaults.standard.integer(forKey: defaultKeyForPort)
    if port != 0 {
        setting.port = UInt16(port)
    }
    return setting
}


class ConnectionManager {
    
    private var connection: NWConnection?
    private(set) var isConnectionReady: Bool = false
    
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
                    self.isConnectionReady = true
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
        isConnectionReady = false
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
        didSet {
            setDefaultConnectionSetting(setting: connectionSetting)
        }
    }
    @Published var started = false
    
    var hmm = CMHeadphoneMotionManager()
    var cm = ConnectionManager()
    
    init() {
        stop()
        connectionSetting = loadDefaultConnectionSetting()
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
            let udpData = ConvertMotion2Codable(motion: receivedMotion)
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(udpData)
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
                        Text("Port: \(String(setting.port))")
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            StatusCircle(started: .constant(true))
            Spacer()
            StartStopButton(started: .constant(true), startFunc: {}, stopFunc: {})
            Spacer()
            SettingCard(setting: ConnectionSetting())
            Spacer()
        }.padding()
    }
}


struct SettingModal_Previews: PreviewProvider {
    static var previews: some View {
        SettingModal(
            showSheetView: .constant(true),
            setting: .constant(ConnectionSetting())
        )
    }
}
