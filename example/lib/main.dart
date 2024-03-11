import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_kinesis_video_webrtc/flutter_kinesis_video_webrtc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KVSWebrtcExample',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FlutterKinesisVideoWebrtcExample(),
    );
  }
}

class FlutterKinesisVideoWebrtcExample extends StatefulWidget {
  const FlutterKinesisVideoWebrtcExample({super.key});

  @override
  State<FlutterKinesisVideoWebrtcExample> createState() =>
      _FlutterKinesisVideoWebrtcExampleState();
}

class _FlutterKinesisVideoWebrtcExampleState
    extends State<FlutterKinesisVideoWebrtcExample> {
  final TextEditingController _accessKeyController = TextEditingController();
  final TextEditingController _secretKeyController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _channelNameController = TextEditingController();
  final RTCVideoRenderer _rtcVideoRenderer = RTCVideoRenderer();
  RTCPeerConnection? _rtcPeerConnection;
  late SignalingClient _signalingClient;
  bool sendAudio = false;
  bool sendVideo = false;
  MediaStream? _localStream;

  @override
  void initState() {
    // for not type manually to check app working or not
    // _accessKeyController.text = 'YOUR_AWS_ACCESS_KEY';
    // _secretKeyController.text = 'YOUR_AWS_SECRET_KEY';
    // _regionController.text = 'YOUR_REGION';
    // _channelNameController.text = 'YOUR_CHANNEL_NAME';
    _rtcVideoRenderer.initialize();
    super.initState();
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _regionController.dispose();
    _channelNameController.dispose();
    _rtcVideoRenderer.dispose();
    _rtcPeerConnection?.dispose();
    super.dispose();
  }

  peerConnection() async {
    _signalingClient = SignalingClient(
      channelName: _channelNameController.text.trim(),
      accessKey: _accessKeyController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
      region: _regionController.text.trim(),
    );

    await _signalingClient.init();

    _rtcPeerConnection = await createPeerConnection({
      'iceServers': _signalingClient.iceServers,
      'iceTransportPolicy': 'all'
    });

    _rtcPeerConnection!.onTrack = (event) {
      _rtcVideoRenderer.srcObject = event.streams[0];
      setState(() {});
    };

    // for send your audio and video
    if (sendAudio || sendVideo) {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': sendAudio,
        'video': sendVideo,
      });

      _localStream!.getTracks().forEach((track) {
        _rtcPeerConnection!.addTrack(track, _localStream!);
        setState(() {});
      });
    }

    var webSocket = SimpleWebSocket(_signalingClient.domain ?? '',
        _signalingClient.signedQueryParams ?? <String, dynamic>{});

    webSocket.onMessage = (data) async {
      if (data != '') {
        var objectOfData = jsonDecode(data);
        print(
            "-------------------- receiving ${objectOfData['messageType']} --------------------");
        if (objectOfData['messageType'] == "SDP_ANSWER") {
          var decodedAns = jsonDecode(
              utf8.decode(base64.decode(objectOfData['messagePayload'])));
          await _rtcPeerConnection?.setRemoteDescription(RTCSessionDescription(
            decodedAns["sdp"],
            decodedAns["type"],
          ));
        } else if (objectOfData['messageType'] == "ICE_CANDIDATE") {
          var decodedCandidate = jsonDecode(
              utf8.decode(base64.decode(objectOfData['messagePayload'])));
          await _rtcPeerConnection?.addCandidate(
            RTCIceCandidate(decodedCandidate["candidate"],
                decodedCandidate["sdpMid"], decodedCandidate["sdpMLineIndex"]),
          );
        }
      }
    };

    webSocket.onOpen = () async {
      if (kDebugMode) {
        print("-------------------- socket opened --------------------");
        print("-------------------- sending 'SDP_OFFER' --------------------");
      }
      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer({
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      });
      await _rtcPeerConnection!.setLocalDescription(offer);
      RTCSessionDescription? localDescription =
          await _rtcPeerConnection?.getLocalDescription();
      var request = {};
      request["action"] = "SDP_OFFER";
      request["messagePayload"] =
          base64.encode(jsonEncode(localDescription?.toMap()).codeUnits);
      webSocket.send(jsonEncode(request));
    };
    _rtcPeerConnection!.onIceCandidate = (dynamic candidate) {
      if (kDebugMode) {
        print(
            "-------------------- sending 'ICE_CANDIDATE' --------------------");
      }

      var request = {};
      request["action"] = "ICE_CANDIDATE";
      request["messagePayload"] =
          base64.encode(jsonEncode(candidate.toMap()).codeUnits);
      webSocket.send(jsonEncode(request));
    };

    await webSocket.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 1.4,
            child: Column(
              children: [
                Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ACCESS-KEY",
                            textScaleFactor: 1.0,
                          ),
                          TextFormField(
                            keyboardType: TextInputType.text,
                            maxLength: 128,
                            controller: _accessKeyController,
                            decoration: const InputDecoration(
                              hintText: "Enter access key",
                              counterText: "",
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "SECRET-KEY ",
                            textScaleFactor: 1.0,
                          ),
                          TextFormField(
                            keyboardType: TextInputType.visiblePassword,
                            obscureText: true,
                            controller: _secretKeyController,
                            decoration: const InputDecoration(
                              hintText: "Enter secret key",
                              counterText: "",
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "REGION",
                            textScaleFactor: 1.0,
                          ),
                          TextFormField(
                            keyboardType: TextInputType.text,
                            controller: _regionController,
                            decoration: const InputDecoration(
                              hintText: "Enter region ex: us-east-1",
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "CHANNEL NAME",
                            textScaleFactor: 1.0,
                          ),
                          TextFormField(
                            keyboardType: TextInputType.text,
                            controller: _channelNameController,
                            decoration: const InputDecoration(
                              hintText: "Enter channel name",
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                peerConnection();
                                setState(() {});
                              },
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  width: MediaQuery.of(context).size.width - 80,
                                  child: const Text(
                                    "START WEBRTC",
                                    textAlign: TextAlign.center,
                                    textScaleFactor: 1.0,
                                  )),
                            ),
                          ),
                        ],
                      ),
                    )),
                Expanded(
                  flex: 6,
                  child: _rtcVideoRenderer.renderVideo
                      ? Center(
                          child: AspectRatio(
                              aspectRatio: _rtcVideoRenderer.value.aspectRatio,
                              child: RTCVideoView(
                                _rtcVideoRenderer,
                              )))
                      : const Center(
                          child: CircularProgressIndicator(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
