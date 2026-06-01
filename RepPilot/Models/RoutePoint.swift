import Foundation
import CoreLocation

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double    // meters

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ location: CLLocation) {
        self.latitude  = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude  = location.altitude
    }
}
