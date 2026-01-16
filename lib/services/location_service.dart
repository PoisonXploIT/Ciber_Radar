
import 'package:geolocator/geolocator.dart';

class LocationService {
  
  Stream<Position> get positionStream {
    // LocationSettings can be customized for accuracy vs battery
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
