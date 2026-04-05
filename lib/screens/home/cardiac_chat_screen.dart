import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';

// ─────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────
const _bg = Color(0xFF080D18);
const _surface = Color(0xFF0F1623);
const _card = Color(0xFF161E30);
const _card2 = Color(0xFF1C2438);
const _border = Color(0xFF222D42);
const _borderL = Color(0xFF2A3650);

const _white = Color(0xFFFFFFFF);
const _txt = Color(0xFFD8E4F5);
const _sub = Color(0xFF6B7FA0);
const _muted = Color(0xFF3D4E68);

const _p1 = Color(0xFF5B73E8);
const _p2 = Color(0xFF9B59B6);
const _p3 = Color(0xFF3D5AF1);

const _green = Color(0xFF2DD4A0);
const _amber = Color(0xFFF5A623);
const _red = Color(0xFFFC6B68);

// ─────────────────────────────────────────────────────────────────
// GEMINI CONFIG
// ─────────────────────────────────────────────────────────────────
const _kModels = [
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-robotics-er-1.5-preview',
];

const _kContextWindow = 10;

// ─────────────────────────────────────────────────────────────────
// QUICK SUGGESTIONS  (shown on open + after every AI reply)
// ─────────────────────────────────────────────────────────────────
const _kSuggestions = [
  ('💓', 'Heart health overview'),
  ('📈', 'Is my BP trending up?'),
  ('😴', 'HRV & recovery status'),
  ('🏃', 'Safe to exercise today?'),
  ('⚠️', 'Any warning signs?'),
  ('💊', 'Lifestyle tips for me'),
];

// ═════════════════════════════════════════════════════════════════
// ROUTE
// ═════════════════════════════════════════════════════════════════
class CardiacChatScreen extends StatefulWidget {
  final List<double> systolicSeries;
  final List<double> diastolicSeries;
  final List<double> hrSeries;
  final List<double> hrvSeries;
  final int overallScore;

  const CardiacChatScreen({
    super.key,
    required this.systolicSeries,
    required this.diastolicSeries,
    required this.hrSeries,
    this.hrvSeries = const [],
    this.overallScore = 0,
  });

  static Route<void> route({
    required List<double> systolicSeries,
    required List<double> diastolicSeries,
    required List<double> hrSeries,
    List<double> hrvSeries = const [],
    int overallScore = 0,
  }) =>
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => CardiacChatScreen(
          systolicSeries: systolicSeries,
          diastolicSeries: diastolicSeries,
          hrSeries: hrSeries,
          hrvSeries: hrvSeries,
          overallScore: overallScore,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  @override
  State<CardiacChatScreen> createState() => _CardiacChatScreenState();
}

// ═════════════════════════════════════════════════════════════════
// STATE
// ═════════════════════════════════════════════════════════════════
class _CardiacChatScreenState extends State<CardiacChatScreen>
    with TickerProviderStateMixin {
  GenerativeModel? _model;
  ChatSession? _chat;
  int _modelIndex = 0;

  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_ChatMsg>[];
  bool _isLoading = false;
  bool _historyLoaded = false;

  // Show suggestion chips after every AI reply
  bool _showSuggestions = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _dotCtrl;
  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);

    _initGemini();
    _loadHistory();
    _headerCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    _headerCtrl.dispose();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Gemini ─────────────────────────────────────────────────────
  void _initGemini() {
    if (!AppConfig.hasGeminiApiKey) {
      _model = null;
      _chat = null;
      return;
    }

    _model = GenerativeModel(
      model: _kModels[_modelIndex],
      apiKey: AppConfig.geminiApiKey,
      generationConfig:
          GenerationConfig(temperature: 0.7, topK: 40, topP: 0.95),
      systemInstruction: Content.system(
        'You are CardioAI, a friendly cardiac health assistant in a monitoring app. '
        'You have the user\'s recent HR, HRV, and BP data. '
        'Always refer to it when relevant. Be warm, clear, and encouraging. '
        'Never diagnose or prescribe — recommend a doctor for serious concerns. '
        'Keep responses concise (3 bullets unless asked for more). '
        'No long paragraphs. '
        'Use simple language. Format with light markdown (bold numbers, short bullet points).',
      ),
    );
    _chat = _model!.startChat();
  }

  bool _tryNextModel() {
    if (_modelIndex < _kModels.length - 1) {
      _modelIndex++;
      _initGemini();
      return true;
    }
    return false;
  }

  // ── Context ────────────────────────────────────────────────────
  String _buildContext() {
    List<double> tail(List<double> s) =>
        s.length > _kContextWindow ? s.sublist(s.length - _kContextWindow) : s;

    String fmt(List<double> s) => s.isEmpty
        ? 'no data'
        : tail(s).map((v) => v.toStringAsFixed(1)).join(', ');

    String stats(List<double> s) {
      if (s.isEmpty) return '';
      final t = tail(s);
      final avg = t.reduce((a, b) => a + b) / t.length;
      final mn = t.reduce(math.min);
      final mx = t.reduce(math.max);
      return ' | avg ${avg.toStringAsFixed(1)}, min ${mn.toStringAsFixed(1)}, max ${mx.toStringAsFixed(1)}';
    }

    final sbp = widget.systolicSeries;
    final dbp = widget.diastolicSeries;
    final hr = widget.hrSeries;
    final hrv = widget.hrvSeries;

    return '''
[CARDIAC DATA CONTEXT]
Health Score : ${widget.overallScore}/100
Latest BP    : ${sbp.isNotEmpty && dbp.isNotEmpty ? '${sbp.last.toInt()}/${dbp.last.toInt()} mmHg' : 'no data'}
Latest HR    : ${hr.isNotEmpty ? '${hr.last.toInt()} bpm' : 'no data'}
Latest HRV   : ${hrv.isNotEmpty ? '${hrv.last.toInt()} ms' : 'no data'}
BP series    : ${fmt(sbp)}${stats(sbp)}
DBP series   : ${fmt(dbp)}${stats(dbp)}
HR series    : ${fmt(hr)}${stats(hr)}
HRV series   : ${fmt(hrv)}${stats(hrv)}
[END CONTEXT]
''';
  }

  // ── Firestore ──────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _chatCol {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('cardiac_chats')
        .doc(uid)
        .collection('messages');
  }

  Future<void> _saveMsg(String role, String text) async => _chatCol
      .add({'role': role, 'text': text, 'time': FieldValue.serverTimestamp()});

  Future<void> _loadHistory() async {
    try {
      final snap = await _chatCol
          .orderBy('time', descending: false)
          .limitToLast(50)
          .get();

      setState(() {
        _messages.clear();
        for (final doc in snap.docs) {
          final d = doc.data();
          _messages.insert(
              0,
              _ChatMsg(
                role: d['role'] as String,
                text: d['text'] as String,
                time: (d['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
              ));
        }
        _historyLoaded = true;
        _showSuggestions =
            _messages.isNotEmpty && _messages.first.role == 'model';
      });

      if (_messages.isEmpty) {
        _sendAutoGreeting();
      }
    } catch (e) {
      setState(() {
        _historyLoaded = true;
      });
    }
  }

  Future<void> _clearHistory() async {
    final snap = await _chatCol.get();
    for (final doc in snap.docs) await doc.reference.delete();
    setState(() {
      _messages.clear();
      _modelIndex = 0;
      _showSuggestions = false;
      _initGemini();
    });
    _sendAutoGreeting();
  }

  Future<void> _sendAutoGreeting() async {
    if (_chat == null) {
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            role: 'model',
            text:
                'AI chat is disabled for this build. Add `--dart-define=GEMINI_API_KEY=...` when building to enable CardioAI.',
            time: DateTime.now(),
            isError: true,
          ),
        );
        _showSuggestions = false;
      });
      return;
    }

    await _callGemini(
      promptOverride: '${_buildContext()}\n\n'
          'Greet the user warmly in one sentence as CardioAI. '
          'Give a 2-3 bullet friendly summary of their current cardiac health. '
          'No long paragraphs. '
          'Highlight the single most noteworthy metric. '
          'End with one short actionable suggestion.',
      saveUserMsg: false,
    );
  }

  Future<void> _sendMessage([String? override]) async {
    final text = override ?? _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();

    setState(() {
      _messages.insert(
          0, _ChatMsg(role: 'user', text: text, time: DateTime.now()));
      _isLoading = true;
      _showSuggestions = false;
    });
    _scrollToTop();
    await _saveMsg('user', text);
    await _callGemini(userText: text);
  }

  Future<void> _callGemini({
    String? userText,
    String? promptOverride,
    bool saveUserMsg = true,
  }) async {
    if (_chat == null) {
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            role: 'model',
            text:
                'AI chat is unavailable because `GEMINI_API_KEY` is not configured for this build.',
            time: DateTime.now(),
            isError: true,
          ),
        );
        _isLoading = false;
        _showSuggestions = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prompt = promptOverride ?? '${_buildContext()}\n\nUser: $userText';
      final response = await _chat!.sendMessage(Content.text(prompt));
      final reply = response.text ?? "I'm sorry, I couldn't process that.";
      setState(() {
        _messages.insert(
            0, _ChatMsg(role: 'model', text: reply, time: DateTime.now()));
        _isLoading = false;
        _showSuggestions = true; //show suggestions after every AI reply
      });
      await _saveMsg('model', reply);
      _scrollToTop();
    } catch (e) {
      final err = e.toString().toLowerCase();
      final isQuota = err.contains('429') ||
          err.contains('quota') ||
          err.contains('limit') ||
          err.contains('503') ||
          err.contains('overloaded');

      if (isQuota && _tryNextModel()) {
        await Future.delayed(const Duration(seconds: 2));
        await _callGemini(
            userText: userText,
            promptOverride: promptOverride,
            saveUserMsg: saveUserMsg);
      } else {
        setState(() {
          _messages.insert(
              0,
              _ChatMsg(
                role: 'model',
                text:
                    '⚠️ All AI models are currently busy. Please try again in a moment.',
                time: DateTime.now(),
                isError: true,
              ));
          _isLoading = false;
          _showSuggestions = true;
        });
      }
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _bg,
          body: Column(children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            if (_isLoading) _buildTypingIndicator(),
            _buildInputBar(),
          ]),
        ),
      );

  // ── Header — clean, compact, no metrics strip ──────────────────
  Widget _buildHeader() => FadeTransition(
        opacity: _headerFade,
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            border: Border(bottom: BorderSide(color: _border, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: _txt, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                _buildAvatarBadge(),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CardioAI',
                        style: TextStyle(
                            color: _white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    _StatusDot(isLoading: _isLoading),
                  ],
                )),
                // Compact score pill — just enough context without clutter
                _ScorePill(score: widget.overallScore),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _confirmClear,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded,
                        color: _sub, size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _buildAvatarBadge() => ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1.06).animate(_pulseAnim),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [_p1, _p2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                  color: const Color.fromARGB(255, 251, 251, 251)
                      .withOpacity(0.45),
                  //                  color: _p2.withOpacity(0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 3)),
            ],
          ),
          child:
              const Center(child: Text('🤍', style: TextStyle(fontSize: 22))),
        ),
      );

  // ── Body ───────────────────────────────────────────────────────
  Widget _buildBody() {
    if (!_historyLoaded) return _buildLoadingShimmer();
    if (_messages.isEmpty && !_isLoading) return _buildEmptyState();

    return ListView.builder(
      reverse: true,
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      itemCount: _messages.length + (_showSuggestions ? 1 : 0),
      itemBuilder: (ctx, i) {
        // index 0 in reversed list = bottom → suggestions sit just below last AI reply
        if (_showSuggestions && i == 0) return _buildSuggestionStrip();
        final idx = _showSuggestions ? i - 1 : i;
        return _buildBubble(_messages[idx], idx);
      },
    );
  }

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(_pulseAnim),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_p1, _p2]),
                  boxShadow: [
                    BoxShadow(
                        color: const Color.fromARGB(255, 251, 251, 251)
                            .withOpacity(0.45),
                        blurRadius: 30,
                        spreadRadius: 4)
                  ],
                ),
                child: const Center(
                    child: Text('🤍', style: TextStyle(fontSize: 36))),
              ),
            ),
            const SizedBox(height: 24),
            const Text('CardioAI is waking up…',
                style: TextStyle(
                    color: _txt, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Analysing your health data',
                style: TextStyle(color: _sub, fontSize: 13)),
          ]),
        ),
      );

  Widget _buildLoadingShimmer() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: List.generate(3, (i) => _ShimmerRow(index: i))),
      );

  // ── Suggestion strip — horizontally scrollable chips ──────────
  Widget _buildSuggestionStrip() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 14 * (1 - v)), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 2),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Label aligned with AI bubble content (past the avatar)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 8),
              child: Row(children: [
                Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: _amber)),
                const SizedBox(width: 6),
                const Text('Ask a follow-up',
                    style: TextStyle(
                        color: _sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
              ]),
            ),
            // Horizontal scroll row
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 40, right: 14),
                itemCount: _kSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (emoji, label) = _kSuggestions[i];
                  return _SuggestionChip(
                    emoji: emoji,
                    label: label,
                    onTap: () => _sendMessage('$emoji $label'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );

  // ── Bubble ─────────────────────────────────────────────────────
  Widget _buildBubble(_ChatMsg msg, int index) {
    final isUser = msg.role == 'user';
    return TweenAnimationBuilder<double>(
      key: ValueKey('${msg.time.millisecondsSinceEpoch}_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + (index % 4) * 40),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(isUser ? 16 * (1 - v) : -16 * (1 - v), 0),
            child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              _SmallAvatar(pulseAnim: _pulseAnim),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              colors: [_p3, _p2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      color: isUser ? null : _card,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: msg.isError
                                  ? _red.withOpacity(0.35)
                                  : _borderL,
                              width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? _p2.withOpacity(0.28)
                              : Colors.black.withOpacity(0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isUser
                        ? Text(msg.text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                height: 1.45))
                        : MarkdownBody(
                            data: msg.text,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                  color: _txt, fontSize: 14.5, height: 1.6),
                              strong: const TextStyle(
                                  color: _white, fontWeight: FontWeight.w700),
                              listBullet: const TextStyle(color: _sub),
                              h3: const TextStyle(
                                  color: _white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                              blockquoteDecoration: BoxDecoration(
                                color: _p1.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border(
                                    left: BorderSide(color: _p1, width: 3)),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('hh:mm a').format(msg.time),
                      style: const TextStyle(color: _muted, fontSize: 10)),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_p1, _p2]),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Typing indicator ───────────────────────────────────────────
  Widget _buildTypingIndicator() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Row(children: [
          _SmallAvatar(pulseAnim: _pulseAnim),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: _borderL),
            ),
            child: _TypingDots(ctrl: _dotCtrl),
          ),
        ]),
      );

  // ── Input bar ──────────────────────────────────────────────────
  Widget _buildInputBar() => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _borderL),
              ),
              child: TextField(
                controller: _controller,
                enabled: AppConfig.hasGeminiApiKey,
                style: const TextStyle(color: _txt, fontSize: 14.5),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ask about your cardiac health…',
                  hintStyle: TextStyle(color: _muted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap:
                _isLoading || !AppConfig.hasGeminiApiKey ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isLoading || !AppConfig.hasGeminiApiKey
                    ? const LinearGradient(colors: [_muted, _muted])
                    : const LinearGradient(
                        colors: [_p3, _p2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                boxShadow: _isLoading || !AppConfig.hasGeminiApiKey
                    ? []
                    : [
                        BoxShadow(
                            color: _p2.withOpacity(0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 4)),
                      ],
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ]),
      );

  // ── Confirm clear ──────────────────────────────────────────────
  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Chat?',
            style: TextStyle(color: _white, fontWeight: FontWeight.bold)),
        content: const Text(
            'This will delete your entire conversation history.',
            style: TextStyle(color: _sub, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear',
                style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) await _clearHistory();
  }
}

// ═════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═════════════════════════════════════════════════════════════════

class _SmallAvatar extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _SmallAvatar({required this.pulseAnim});

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.04).animate(pulseAnim),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [_p1, _p2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                  color: const Color.fromARGB(255, 251, 251, 251)
                      .withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child:
              const Center(child: Text('🤍', style: TextStyle(fontSize: 14))),
        ),
      );
}

class _StatusDot extends StatelessWidget {
  final bool isLoading;
  const _StatusDot({required this.isLoading});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLoading ? _amber : _green,
            boxShadow: [
              BoxShadow(
                  color: (isLoading ? _amber : _green).withOpacity(0.6),
                  blurRadius: 6)
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          isLoading ? 'Analysing…' : 'Online',
          style: TextStyle(
              color: isLoading ? _amber : _green,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      ]);
}

class _ScorePill extends StatelessWidget {
  final int score;
  const _ScorePill({required this.score});

  Color get _color {
    if (score >= 80) return _green;
    if (score >= 60) return _amber;
    return _red;
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.recommend, color: _color, size: 12),
          const SizedBox(width: 4),
          Text('$score/100',
              style: TextStyle(
                  color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SuggestionChip extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _SuggestionChip(
      {required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: _card2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderL),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: _txt, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _TypingDots extends StatelessWidget {
  final AnimationController ctrl;
  const _TypingDots({required this.ctrl});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final t = ctrl.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i / 3.0;
              final phase = ((t - delay) % 1.0 + 1.0) % 1.0;
              final scale = 1.0 + 0.55 * math.sin(phase * math.pi);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _sub.withOpacity(0.4 + 0.4 * (scale - 1.0) / 0.55),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      );
}

class _ShimmerRow extends StatefulWidget {
  final int index;
  const _ShimmerRow({required this.index});
  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRight = widget.index % 2 == 0;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.04 + 0.06 * _anim.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment:
                isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isRight) ...[
                Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(opacity * 1.5))),
                const SizedBox(width: 8),
              ],
              Container(
                width: isRight ? 180 : 220,
                height: 48 + widget.index * 8.0,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// DATA MODEL
// ═════════════════════════════════════════════════════════════════
class _ChatMsg {
  final String role, text;
  final DateTime time;
  final bool isError;
  const _ChatMsg({
    required this.role,
    required this.text,
    required this.time,
    this.isError = false,
  });
}
