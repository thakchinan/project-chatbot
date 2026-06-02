import 'dart:async';
import 'package:flutter/material.dart';
import '../services/muse_service.dart';
import 'stream/muse2_eeg_stream.dart';
import 'preprocessing/eeg_preprocessor.dart';
import 'spectral/eeg_fft_engine.dart';
import 'quality/eeg_quality_monitor.dart';
import 'virtual/virtual_channel.dart';
import 'models/quality_metrics.dart';
import 'visualizer/eeg_visualizer.dart';

/// Research Mode Screen — หน้าจอหลักสำหรับ research-grade EEG
///
/// รวมทุก component:
/// - Muse2EegStream: BLE + raw data
/// - EegPreprocessor: filter, artifact removal, ICA
/// - EegFftEngine: FFT, PSD, band power, features
/// - EegQualityMonitor: SNR, quality scoring
/// - VirtualChannelInterpolator: 4→32 channels
/// - EegVisualizer: UI ทั้งหมด
class EegResearchScreen extends StatefulWidget {
  const EegResearchScreen({super.key});

  @override
  State<EegResearchScreen> createState() => _EegResearchScreenState();
}

class _EegResearchScreenState extends State<EegResearchScreen>
    with SingleTickerProviderStateMixin {
  // === Core components ===
  late final Muse2EegStream _stream;
  late final EegPreprocessor _preprocessor;
  late final EegFftEngine _fftEngine;
  late final EegQualityMonitor _qualityMonitor;
  late final VirtualChannelInterpolator _virtualChannel;

  // === UI State ===
  Map<String, List<double>> _channelData = {};
  List<double> _psdCurve = [];
  double _freqResolution = 1.0;
  Map<String, double> _relativePower = {};
  Map<String, double> _absolutePower = {};
  OverallQuality _quality = OverallQuality.empty();
  double _alphaBetaRatio = 0;
  double _thetaAlphaRatio = 0;
  double _sampleEntropy = 0;
  double _spectralEdge95 = 0;
  Map<String, double> _coherence = {};

  // === Settings ===
  double _notchFreq = 50.0; // 50 Hz (Thailand)
  int _frameSize = 256;
  bool _isSimulating = false;
  bool _isProcessing = false;

  // === Update timer ===
  Timer? _updateTimer;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize components
    _stream = Muse2EegStream(MuseService());
    _preprocessor = EegPreprocessor(
      notchFrequency: _notchFreq,
    );
    _fftEngine = EegFftEngine(
      frameSize: _frameSize,
    );
    _qualityMonitor = EegQualityMonitor();
    _virtualChannel = VirtualChannelInterpolator();

    // Listen to stream updates
    _stream.addListener(_onStreamUpdate);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _stream.removeListener(_onStreamUpdate);
    _stream.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onStreamUpdate() {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      _processData();
    } finally {
      _isProcessing = false;
    }
  }

  /// Full DSP pipeline: raw → preprocess → FFT → features → quality
  void _processData() {
    final buffers = _stream.channelBuffers;
    final minLen = _stream.bufferLength;

    if (minLen < _frameSize) return;

    // 1. Preprocessing
    final frame = _preprocessor.process(buffers);

    // 2. FFT + Band Power (use average across channels)
    final allPsd = <String, List<double>>{};
    final allBandPower = <String, BandPowerResult>{};

    for (final entry in frame.channels.entries) {
      if (entry.value.length >= _frameSize) {
        final psd = _fftEngine.welchPSD(entry.value);
        allPsd[entry.key] = psd;
        allBandPower[entry.key] = _fftEngine.computeBandPower(psd);
      }
    }

    // Average PSD across channels
    if (allPsd.isNotEmpty) {
      final firstPsd = allPsd.values.first;
      final avgPsd = List<double>.filled(firstPsd.length, 0.0);
      for (final psd in allPsd.values) {
        for (int i = 0; i < psd.length && i < avgPsd.length; i++) {
          avgPsd[i] += psd[i];
        }
      }
      for (int i = 0; i < avgPsd.length; i++) {
        avgPsd[i] /= allPsd.length;
      }

      final avgBandPower = _fftEngine.computeBandPower(avgPsd);

      // 3. Advanced features
      final entropy = EegFftEngine.sampleEntropy(
        frame.channels.values.first,
      );

      // 4. Channel coherence
      final coh = _fftEngine.allCoherences(frame.channels);

      // 5. Quality assessment
      final quality = _qualityMonitor.assess(frame.channels);

      // 6. Update UI state
      if (mounted) {
        setState(() {
          _channelData = frame.channels;
          _psdCurve = avgPsd;
          _freqResolution = _fftEngine.frequencyResolution;
          _relativePower = avgBandPower.relative;
          _absolutePower = avgBandPower.absolute;
          _quality = quality;
          _alphaBetaRatio = avgBandPower.alphaBetaRatio;
          _thetaAlphaRatio = avgBandPower.thetaAlphaRatio;
          _sampleEntropy = entropy;
          _spectralEdge95 = avgBandPower.spectralEdgeFreq95;
          _coherence = coh;
        });
      }
    }
  }

  void _startSimulation() {
    _stream.startSimulation();
    setState(() => _isSimulating = true);

    // Schedule periodic processing
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _onStreamUpdate(),
    );
  }

  void _stopSimulation() {
    _updateTimer?.cancel();
    _stream.stopSimulation();
    setState(() => _isSimulating = false);
  }

  void _clearData() {
    _stream.clearBuffers();
    _qualityMonitor.reset();
    setState(() {
      _channelData = {};
      _psdCurve = [];
      _relativePower = {};
      _absolutePower = {};
      _quality = OverallQuality.empty();
      _coherence = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Control bar
          _buildControlBar(),
          // Tab bar
          Container(
            color: const Color(0xFF0D1B2A),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00D4AA),
              labelColor: const Color(0xFF00D4AA),
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: '📊 Dashboard'),
                Tab(text: '⚙️ Settings'),
                Tab(text: 'ℹ️ Info'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildSettingsTab(),
                _buildInfoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1B2A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
        onPressed: () {
          if (_isSimulating) _stopSimulation();
          Navigator.pop(context);
        },
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.science, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Research Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'EEG Research-Grade Pipeline',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Research score badge
        if (_quality.researchScore > 0)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _quality.researchLevel.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _quality.researchLevel.color.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  color: _quality.researchLevel.color,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_quality.researchScore.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _quality.researchLevel.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0D1B2A),
      child: Row(
        children: [
          // Start/Stop button
          ElevatedButton.icon(
            onPressed: _isSimulating ? _stopSimulation : _startSimulation,
            icon: Icon(
              _isSimulating ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(
              _isSimulating ? 'Stop' : 'Start Simulation',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSimulating
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF00D4AA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Clear button
          OutlinedButton.icon(
            onPressed: _clearData,
            icon: const Icon(Icons.delete_sweep, size: 16),
            label: const Text('Clear', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: const BorderSide(color: Colors.white12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const Spacer(),

          // Status indicator
          if (_isSimulating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D4AA),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_stream.totalSamples} samples',
                    style: const TextStyle(
                      color: Color(0xFF00D4AA),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return EegVisualizer(
      channels: _channelData,
      psdCurve: _psdCurve,
      frequencyResolution: _freqResolution,
      relativePower: _relativePower,
      absolutePower: _absolutePower,
      quality: _quality,
      alphaBetaRatio: _alphaBetaRatio,
      thetaAlphaRatio: _thetaAlphaRatio,
      sampleEntropy: _sampleEntropy,
      spectralEdge95: _spectralEdge95,
      coherence: _coherence,
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingSection('Notch Filter', [
            _buildDropdown('Frequency', _notchFreq, [50.0, 60.0], (v) {
              setState(() => _notchFreq = v);
              _preprocessor = EegPreprocessor(notchFrequency: v);
            }, suffix: 'Hz'),
          ]),
          const SizedBox(height: 16),
          _buildSettingSection('FFT', [
            _buildDropdown('Frame Size', _frameSize.toDouble(),
                [128.0, 256.0, 512.0], (v) {
              setState(() => _frameSize = v.toInt());
            }, suffix: 'samples'),
          ]),
          const SizedBox(height: 16),
          _buildSettingSection('Preprocessing', [
            _buildInfoRow('Band-pass', '1-45 Hz (4th-order Butterworth)'),
            _buildInfoRow('Artifact', 'Blink + Jaw + Movement + Flatline'),
            _buildInfoRow('ICA', 'Regression-based blink removal'),
          ]),
          const SizedBox(height: 16),
          _buildSettingSection('Virtual Channel', [
            ..._virtualChannel.summary().entries.map((e) =>
                _buildInfoRow(e.key, e.value.toString())),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            '🔬 Research-Grade Pipeline',
            'ระบบประมวลผลสัญญาณ EEG ระดับวิจัย\n'
            'ออกแบบให้ Muse 2 มีคุณภาพ 80-90% เทียบเท่าอุปกรณ์วิจัย',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            '📊 Processing Steps',
            '1. DC Offset Removal + Linear Detrend\n'
            '2. 4th-order Butterworth Band-pass (1-45 Hz)\n'
            '3. Notch Filter (${_notchFreq.toInt()} Hz)\n'
            '4. Artifact Detection (Blink/Jaw/Movement/Flatline)\n'
            '5. ICA-based Blink Removal\n'
            '6. Complex FFT (Cooley-Tukey)\n'
            '7. Welch\'s PSD (50% overlap)\n'
            '8. Band Power + Advanced Features',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            '📏 Quality Thresholds',
            'SNR: >10 dB = ดี, 5-10 dB = พอใช้, <5 dB = แย่\n'
            'Artifact Rate: <10% = ดี, 10-30% = พอใช้, >30% = แย่\n'
            'Contact: Based on RMS + flatline detection\n'
            'Research Score: SNR(30%) + Artifact(30%) + PSD(20%) + Contact(20%)',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            '📚 References',
            '• Cooley & Tukey (1965) — FFT Algorithm\n'
            '• Welch (1967) — PSD Estimation\n'
            '• Perrin et al. (1989) — Spherical Spline\n'
            '• Krigolson et al. (2017) — Muse Validation\n'
            '• IFCN Standards (2017) — Digital EEG Recording\n'
            '• Richman & Moorman (2000) — Sample Entropy',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Settings Helpers
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSettingSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, double value, List<double> options,
      ValueChanged<double> onChanged,
      {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<double>(
              value: value,
              dropdownColor: const Color(0xFF1A2332),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              isDense: true,
              items: options.map((v) {
                return DropdownMenuItem(
                  value: v,
                  child: Text('${v.toStringAsFixed(0)} $suffix'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
