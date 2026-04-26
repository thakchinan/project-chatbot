
class EEGDevice {
  final int? deviceId;
  final int? userId;
  final String deviceName;
  final String? modelName;
  final String? serialNumber;
  final String? macAddress;
  final String? firmwareVersion;
  final String status;
  final bool isConnected;
  final DateTime? lastConnectedAt;
  final int? batteryLevel;
  final DateTime? createdAt;

  EEGDevice({
    this.deviceId,
    this.userId,
    required this.deviceName,
    this.modelName,
    this.serialNumber,
    this.macAddress,
    this.firmwareVersion,
    this.status = 'active',
    this.isConnected = false,
    this.lastConnectedAt,
    this.batteryLevel,
    this.createdAt,
  });

  factory EEGDevice.fromJson(Map<String, dynamic> json) {
    return EEGDevice(
      deviceId: json['device_id'],
      userId: json['user_id'],
      deviceName: json['device_name'] ?? 'Unknown',
      modelName: json['model_name'],
      serialNumber: json['serial_number'],
      macAddress: json['mac_address'],
      firmwareVersion: json['firmware_version'],
      status: json['status'] ?? 'active',
      isConnected: json['is_connected'] ?? false,
      lastConnectedAt: json['last_connected_at'] != null
          ? DateTime.tryParse(json['last_connected_at'].toString())
          : null,
      batteryLevel: json['battery_level'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'user_id': userId,
      'device_name': deviceName,
      if (modelName != null) 'model_name': modelName,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (macAddress != null) 'mac_address': macAddress,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
      'status': status,
      'is_connected': isConnected,
    };
  }

  bool checkConnected() {
    return isConnected && status == 'active';
  }

  EEGDevice disconnect() {
    return EEGDevice(
      deviceId: deviceId,
      userId: userId,
      deviceName: deviceName,
      modelName: modelName,
      serialNumber: serialNumber,
      macAddress: macAddress,
      firmwareVersion: firmwareVersion,
      status: 'inactive',
      isConnected: false,
      lastConnectedAt: lastConnectedAt,
      batteryLevel: batteryLevel,
      createdAt: createdAt,
    );
  }

  int updateFirmware(String newVersion) {

    final parts = newVersion.split('.');
    if (parts.isNotEmpty) {
      return int.tryParse(parts.first) ?? 0;
    }
    return 0;
  }
}
