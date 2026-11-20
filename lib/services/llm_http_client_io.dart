import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client? createDirectHttpClient() {
  final ioClient = HttpClient()..findProxy = (_) => 'DIRECT';
  return IOClient(ioClient);
}

bool isTransportConnectionError(Object error) =>
    error is http.ClientException ||
    error is SocketException ||
    error is HandshakeException ||
    error is TlsException;
