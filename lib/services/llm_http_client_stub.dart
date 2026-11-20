import 'package:http/http.dart' as http;

http.Client? createDirectHttpClient() => null;

bool isTransportConnectionError(Object error) =>
    error is http.ClientException;
