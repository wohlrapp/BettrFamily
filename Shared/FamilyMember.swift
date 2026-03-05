import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@Model
final class FamilyMember {
    var id: String // Firebase Auth UID
    var name: String
    var email: String
    var familyGroupID: String
    var deviceName: String
    var lastHeartbeat: Date?
    var isCurrentDevice: Bool

    init(
        id: String,
        name: String,
        email: String,
        familyGroupID: String,
        deviceName: String = "",
        isCurrentDevice: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.familyGroupID = familyGroupID
        #if canImport(UIKit)
        self.deviceName = deviceName.isEmpty ? UIDevice.current.name : deviceName
        #else
        self.deviceName = deviceName.isEmpty ? "Unknown" : deviceName
        #endif
        self.lastHeartbeat = Date()
        self.isCurrentDevice = isCurrentDevice
    }
}
