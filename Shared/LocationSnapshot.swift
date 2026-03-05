import Foundation
import SwiftData

@Model
final class LocationSnapshot {
    var id: String
    var memberID: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var syncedToFirebase: Bool

    init(memberID: String, latitude: Double, longitude: Double) {
        self.id = UUID().uuidString
        self.memberID = memberID
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = Date()
        self.syncedToFirebase = false
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "memberID": memberID,
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }

    /// Distance to another snapshot in meters
    func distance(to other: LocationSnapshot) -> Double {
        let earthRadius = 6_371_000.0 // meters
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                 cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180) *
                 sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
