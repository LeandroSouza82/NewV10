// Nunca envia NaN, infinito ou coordenadas fora da faixa ao navegador.
Uri? buildNavigationDestination(String address, double? lat, double? lng, String browser) {
  final valid = lat != null && lng != null && lat.isFinite && lng.isFinite &&
      lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0);
  final destination = valid ? '$lat,$lng' : address.trim();
  if (destination.isEmpty) return null;
  if (browser == 'waze') {
    return Uri.https('waze.com', '/ul', {
      valid ? 'll' : 'q': destination,
      'navigate': 'yes',
    });
  }
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1', 'destination': destination, 'travelmode': 'driving', 'dir_action': 'navigate',
  });
}
