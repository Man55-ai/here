import 'package:uuid/uuid.dart';

void main() {
  final uuid = const Uuid();
  print("UUID v4: ${uuid.v4()}");
}
