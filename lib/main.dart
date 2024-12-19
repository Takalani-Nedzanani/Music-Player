import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(MyApp());
}

class  MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MusicPlayer(),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Map<String, String>> _playlist = [];
  int _currentTrackIndex = 0;
  bool _isPlaying = false;

  Future<void> _requestPermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      _pickFiles();
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Storage permission is required. Click here to grant it."),
          action: SnackBarAction(
            label: "Grant",
            onPressed: () async {
              if (await Permission.storage.request().isGranted) {
                _pickFiles();
              }
            },
          ),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _playlist = result.files
            .map((file) => {
                  'path': file.path!,
                  'name': file.name,
                })
            .toList();
      });
      _loadTrack(0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No files selected")),
      );
    }
  }

  Future<void> _loadTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    setState(() {
      _currentTrackIndex = index;
      _isPlaying = false;
    });
    await _audioPlayer.setFilePath(_playlist[index]['path']!);
    _playPause();
  }

  void _playPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      _audioPlayer.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _nextTrack() {
    if (_currentTrackIndex < _playlist.length - 1) {
      _loadTrack(_currentTrackIndex + 1);
    }
  }

  void _previousTrack() {
    if (_currentTrackIndex > 0) {
      _loadTrack(_currentTrackIndex - 1);
    }
  }

  Stream<DurationState> get _durationStateStream =>
      Rx.combineLatest2<Duration, Duration?, DurationState>(
        _audioPlayer.positionStream,
        _audioPlayer.durationStream,
        (position, duration) => DurationState(position, duration ?? Duration.zero),
      );

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Music Player"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.library_music),
            onPressed: _requestPermission,
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_playlist.isNotEmpty) ...[
            Text(
              "Now Playing: ${_playlist[_currentTrackIndex]['name']}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            StreamBuilder<DurationState>(
              stream: _durationStateStream,
              builder: (context, snapshot) {
                final durationState = snapshot.data;
                final position = durationState?.position ?? Duration.zero;
                final duration = durationState?.duration ?? Duration.zero;
                return Column(
                  children: [
                    Slider(
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble(),
                      value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                      onChanged: (value) {
                        _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                    Text(
                      "${_formatDuration(position)} / ${_formatDuration(duration)}",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 48),
                  onPressed: _previousTrack,
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 64,
                    color: Colors.teal,
                  ),
                  onPressed: _playPause,
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, size: 48),
                  onPressed: _nextTrack,
                ),
              ],
            ),
          ] else ...[
            Text(
              "No tracks loaded. Use the button in the app bar to pick files.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ]
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class DurationState {
  final Duration position;
  final Duration duration;

  DurationState(this.position, this.duration);
}
