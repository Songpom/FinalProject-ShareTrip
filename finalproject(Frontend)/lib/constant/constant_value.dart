//IPv4 session
const String ipv4 = "192.168.100.76";
//Header session
const Map<String, String> headers = {
  "Access-Control-Allow-Origin": "*",
  'Content-Type': 'application/json',
  'Accept-Language': 'th',
  'Accept': '*/*',
};
// const String baseURL = 'https://3de27bc5a288.ngrok-free.app';

const String baseURL = "http://" + ipv4 + ":8082";
