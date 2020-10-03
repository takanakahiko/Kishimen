//
//  ContentView.swift
//  iOSHeadphoneMotionUdp
//
//  Created by takanakahiko on 2020/09/27.
//

import SwiftUI
import CoreMotion

struct ContentView: View {
    @State private var hmm = CMHeadphoneMotionManager()
    
    var body: some View {
        Text("isDeviceMotionAvailable = " + String(hmm.isDeviceMotionAvailable))
            .padding()
        Text("isDeviceMotionActive = " + String(hmm.isDeviceMotionActive))
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
