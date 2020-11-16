//
//  Types.swift
//  Kishimen
//
//  Created by takanakahiko on 2020/11/17.
//

import Foundation
import CoreMotion

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


func ConvertMotion2Codable (motion: CMDeviceMotion) -> UdpData {
    return UdpData(
        motion: .init(
            attitude: .init(
                roll: motion.attitude.roll,
                pitch: motion.attitude.pitch,
                yaw: motion.attitude.yaw,
                rotationMatrix: .init(
                    m11: motion.attitude.rotationMatrix.m11,
                    m12: motion.attitude.rotationMatrix.m12,
                    m13: motion.attitude.rotationMatrix.m13,
                    m21: motion.attitude.rotationMatrix.m21,
                    m22: motion.attitude.rotationMatrix.m22,
                    m23: motion.attitude.rotationMatrix.m23,
                    m31: motion.attitude.rotationMatrix.m31,
                    m32: motion.attitude.rotationMatrix.m32,
                    m33: motion.attitude.rotationMatrix.m33
                ),
                quaternion: .init(
                    x: motion.attitude.quaternion.x,
                    y: motion.attitude.quaternion.y,
                    z: motion.attitude.quaternion.z,
                    w: motion.attitude.quaternion.w
                )
            ),
            rotationRate: .init(
                x: motion.rotationRate.x,
                y: motion.rotationRate.y,
                z: motion.rotationRate.z
            ),
            gravity: .init(
                x: motion.gravity.x,
                y: motion.gravity.y,
                z: motion.gravity.z
            ),
            userAcceleration: .init(
                x: motion.userAcceleration.x,
                y: motion.userAcceleration.y,
                z: motion.userAcceleration.z
            ),
            magneticField: .init(
                field: .init(
                    x: motion.magneticField.field.x,
                    y: motion.magneticField.field.y,
                    z: motion.magneticField.field.z
                ),
                accuracy: motion.magneticField.accuracy.rawValue
            ),
            heading: motion.heading,
            sensorLocation: motion.sensorLocation.rawValue,
            timestamp: motion.timestamp
        )
    )
}
