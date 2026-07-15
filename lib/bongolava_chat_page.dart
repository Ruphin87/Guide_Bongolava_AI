import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';



class ChatMessage {
  String? text;
  Uint8List? imageData;
  final bool isUser;
  bool isStreaming;

  ChatMessage({this.text, this.imageData, required this.isUser, this.isStreaming = false});
}


const String _systemInstruction = """
Tu es "Bongolava AI", un guide touristique et historique intelligent, chaleureux et
passionné, spécialisé EXCLUSIVEMENT dans la région du BONGOLAVA à Madagascar.

RÈGLE 1 — IDENTITÉ (réponse courte par défaut) :
Si l'utilisateur demande "qui t'a créé ?", "qui est ton développeur ?", "d'où viens-tu ?",
"qui t'a programmé ?" ou une question équivalente, réponds (en adaptant la langue,
voir RÈGLE 4) avec un contenu équivalent à :
"Je suis développé par RATAHINJANAHARY Ruphin Henri, étudiant à l'École Nationale
d'Informatique (ENI) de Fianarantsoa, en Mention Intelligence Artificielle, parcours
Objets Connectés et Cybersécurité. Il vit dans la région du Bongolava, Commune Rurale
de Bevato, Fokontany Ambohipisaka."
Ne donne PAS spontanément le numéro de téléphone ni l'e-mail à ce stade.

RÈGLE 2 — COORDONNÉES (uniquement si l'utilisateur INSISTE) :
Si, après cette première réponse, l'utilisateur insiste pour le contacter directement
("donne-moi son contact", "comment le joindre", "un numéro ou un e-mail ?", "je veux lui
parler", etc.), donne alors ces coordonnées :
Téléphone : +261 38 05 876 87
Facebook : Henrii Le Ruphin
LinkedIn : Ruphin Henri RATAHINJANAHARY
GitHub : Ruphin Henri
Ne fournis ces informations que dans ce cas d'insistance claire, jamais avant.

RÈGLE 3 — SPÉCIALISATION STRICTE :
Tu ne réponds QUE sur des sujets liés au Bongolava (Madagascar) : histoire, culture,
traditions, la ville de Tsiroanomandidy, le marché de zébus, paysages, collines, lacs,
flore, faune, curiosités touristiques, hébergements, conseils de voyage, populations
locales, économie (élevage, agriculture, artisanat), ainsi que la Commune de Bevato et
le Fokontany Ambohipisaka.
Si la question est hors sujet (autre pays, recette générale, sport, politique nationale,
etc.), refuse poliment et rappelle ton rôle, dans la langue de l'utilisateur.

RÈGLE 4 — LANGUE DE RÉPONSE (très important) :
Réponds TOUJOURS dans la même langue que celle utilisée par l'utilisateur dans son
dernier message (français, malgache, anglais, ou autre). Adapte-toi automatiquement à
chaque message, sans jamais demander à l'utilisateur de préciser sa langue.

RÈGLE 5 — PAS DE GÉNÉRATION D'IMAGES :
Tu ne peux pas générer d'images. Si un utilisateur demande une photo ou une illustration
("montre-moi le marché de zébus", "une photo des collines du Bongolava"), explique
brièvement que tu ne peux pas générer d'image pour l'instant, puis COMPENSE avec une
description textuelle vivante, riche en détails sensoriels (couleurs, sons, ambiance,
odeurs) pour que l'utilisateur puisse se représenter la scène malgré tout.

STYLE DE COMMUNICATION :
- Ton chaleureux, enthousiaste et accueillant
- Réponses riches en détails locaux et anecdotes
- Emojis appropriés pour rendre la conversation vivante 🌿🐂🏔️
- Quelques mots malgaches sont les bienvenus (ex : "Tongasoa !") quand la langue de
  l'utilisateur est le français ou le malgache
""";

const List<_Suggestion> _suggestions = [
  _Suggestion('', 'Le marché de zébus', 'Parle-moi du marché de zébus de Tsiroanomandidy'),
  _Suggestion('', 'Paysages du Bongolava', 'Décris-moi les collines et paysages du Bongolava'),
  _Suggestion('', 'Histoire & culture', "Quelle est l'histoire de la région du Bongolava ?"),
];

class _Suggestion {
  final String emoji;
  final String title;
  final String prompt;
  const _Suggestion(this.emoji, this.title, this.prompt);
}


class _DevContact {
  final IconData icon;
  final String label;
  final String value;
  final String url;
  const _DevContact({required this.icon, required this.label, required this.value, required this.url});
}

const List<_DevContact> _devContacts = [
  _DevContact(
    icon: Icons.phone_outlined,
    label: 'Téléphone',
    value: '+261 38 05 876 87',
    url: 'tel:+261380587687',
  ),
  _DevContact(
    icon: Icons.facebook_outlined,
    label: 'Facebook',
    value: 'Henrii Le Ruphin',
    url: 'https://www.facebook.com/search/top?q=Henrii%20Le%20Ruphin',
  ),
  _DevContact(
    icon: Icons.work_outline,
    label: 'LinkedIn',
    value: 'Ruphin Henri RATAHINJANAHARY',
    url: 'www.linkedin.com/in/ruphin-henri-ratahinjanahary-635027420',
  ),
  _DevContact(
    icon: Icons.code,
    label: 'GitHub',
    value: 'Ruphin Henri',
    url: 'https://github.com/Ruphin87',
  ),
];

/// Limite de messages envoyés par l'utilisateur par jour (heure locale).
const int kDailyMessageLimit = 80;
const String _prefKeyDate = 'bongolava_last_message_date';
const String _prefKeyCount = 'bongolava_message_count';



class BongolavaChat extends StatefulWidget {
  const BongolavaChat({super.key});

  @override
  State<BongolavaChat> createState() => _BongolavaChatState();
}

class _BongolavaChatState extends State<BongolavaChat> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasText = false;
  int _messagesSentToday = 0;
  bool _limitLoaded = false;

  late final GenerativeModel _model;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _initGemini();
    _loadDailyMessageCount();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }



  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDailyMessageCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_prefKeyDate);
    final today = _todayKey();
    if (savedDate != today) {
      // Nouveau jour : on remet le compteur à zéro.
      await prefs.setString(_prefKeyDate, today);
      await prefs.setInt(_prefKeyCount, 0);
      if (mounted) setState(() { _messagesSentToday = 0; _limitLoaded = true; });
    } else {
      final count = prefs.getInt(_prefKeyCount) ?? 0;
      if (mounted) setState(() { _messagesSentToday = count; _limitLoaded = true; });
    }
  }

  Future<bool> _canSendMessageAndIncrement() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_prefKeyDate);
    int current = (savedDate == today) ? (prefs.getInt(_prefKeyCount) ?? 0) : 0;

    if (current >= kDailyMessageLimit) {
      setState(() => _messagesSentToday = current);
      return false;
    }

    current += 1;
    await prefs.setString(_prefKeyDate, today);
    await prefs.setInt(_prefKeyCount, current);
    setState(() => _messagesSentToday = current);
    return true;
  }

  Future<void> _refundDailyMessageCredit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    if (prefs.getString(_prefKeyDate) != today) return;
    final current = prefs.getInt(_prefKeyCount) ?? 0;
    final refunded = (current - 1).clamp(0, kDailyMessageLimit);
    await prefs.setInt(_prefKeyCount, refunded);
    if (mounted) setState(() => _messagesSentToday = refunded);
  }

  void _initGemini() {
    // Modèle 100% gratuit (plan Spark) : texte uniquement.
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite',
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.8,
        maxOutputTokens: 2048,
      ),
    );
    _chat = _model.startChat();
  }

 

  void _startNewConversation() {
    setState(() {
      _messages.clear();
      _chat = _model.startChat();
    });
  }

  Future<void> _confirmDeleteConversation() async {
    if (_messages.isEmpty) {
      _startNewConversation();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la discussion ?'),
        content: const Text(
          'Tous les messages de cette conversation seront définitivement effacés. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color.fromARGB(255, 230, 17, 17)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _startNewConversation();
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  bool _isNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    const networkPatterns = [
      'socketexception',
      'failed host lookup',
      'failed to fetch',
      'clientexception',
      'network is unreachable',
      'no address associated with hostname',
      'connection failed',
      'connection reset',
      'connection refused',
      'timeoutexception',
      'timed out',
      'handshakeexception',
    ];
    return networkPatterns.any((p) => msg.contains(p));
  }


  bool _isRateLimitError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('429') ||
        msg.contains('resource_exhausted') ||
        msg.contains('too many requests') ||
        msg.contains('quota');
  }

  Future<void> _sendMessage([String? presetText]) async {
    final userText = (presetText ?? _inputController.text).trim();
    if (userText.isEmpty || _isLoading) return;

 
    final allowed = await _canSendMessageAndIncrement();
    if (!allowed) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Limite quotidienne atteinte'),
          content: Text(
            "Vous avez atteint la limite de $kDailyMessageLimit messages "
            "aujourd'hui. Revenez demain pour continuer à discuter avec "
            "Bongolava AI 🙏",
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      return;
    }

    _addUserMessage(userText);
    _inputController.clear();
    setState(() => _isLoading = true);

    late final ChatMessage botMessage;
    setState(() {
      botMessage = ChatMessage(text: '', isUser: false, isStreaming: true);
      _messages.add(botMessage);
    });

    await _streamResponse(userText, botMessage, isRetry: false);
  }


  Future<void> _streamResponse(String userText, ChatMessage botMessage, {required bool isRetry}) async {
    try {
      final stream = _chat.sendMessageStream(Content.text(userText));
      bool firstChunkReceived = false;

      await for (final chunk in stream) {
        final chunkText = chunk.text;
        if (chunkText == null || chunkText.isEmpty) continue;

        if (!firstChunkReceived) {
          firstChunkReceived = true;
          setState(() => _isLoading = false);
        }

        setState(() {
          botMessage.text = (botMessage.text ?? '') + chunkText;
        });
        _scrollToBottom();
      }

      if ((botMessage.text ?? '').isEmpty) {
        setState(() {
          botMessage.text = "Je n'ai pas pu générer une réponse. Veuillez réessayer. 🙏";
        });
      }
      setState(() {
        _isLoading = false;
        botMessage.isStreaming = false;
      });
    } catch (e) {
      // ── Limite de débit (429) : un seul réessai automatique et discret ──
      if (_isRateLimitError(e) && !isRetry) {
        setState(() {
          botMessage.isStreaming = true; // garde les 3 points affichés
        });
        await Future.delayed(const Duration(seconds: 4));
        if (!mounted) return;
        await _streamResponse(userText, botMessage, isRetry: true);
        return;
      }

      setState(() {
        if (_isNetworkError(e)) {
          botMessage.text = "Pas de connexion internet.\n\n"
              "Vérifiez votre Wi-Fi ou vos données mobiles, puis réessayez.";
        } else if (_isRateLimitError(e)) {
          botMessage.text = "Trop de demandes en même temps.\n\n"
              "Patientez une minute puis réessayez — c'est temporaire.";
        } else {
          botMessage.text = "Le service IA est momentanément indisponible.\n\n"
              "Réessayez dans quelques instants.";
        }
        _isLoading = false;
        botMessage.isStreaming = false;
      });

      if (_isNetworkError(e)) {
        await _refundDailyMessageCredit();
      }
    }
  }


  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter Bongolava AI ?'),
        content: const Text('Voulez-vous vraiment fermer l\'application ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kMadaRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return result ?? false;
  }



  Future<void> _openContact(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir ce lien.")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir ce lien.")),
        );
      }
    }
  }

  void _showAboutSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(child: _brandIcon(size: 64)),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Bongolava AI',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Guide touristique intelligent du Bongolava, Madagascar 🇲🇬',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Développeur',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RATAHINJANAHARY Ruphin Henri',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Étudiant à l'École Nationale d'Informatique de "
                          "Fianarantsoa (ENI)",
                          style: TextStyle(fontSize: 13.5, height: 1.4, color: cs.onSurface.withOpacity(0.75)),
                        ),
                     
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._devContacts.map((c) => _buildContactRow(c, cs)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContactRow(_DevContact c, ColorScheme cs) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openContact(c.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(c.icon, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label, style: TextStyle(fontSize: 11.5, color: cs.onSurface.withOpacity(0.5))),
                  Text(c.value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final clampedTextScale = mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedTextScale),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldExit = await _confirmExit();
          if (shouldExit && context.mounted) {
            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        },
        child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          titleSpacing: 12,
          title: Row(
            children: [
              _brandIcon(size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bongolava AI',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    if (_limitLoaded)
                      Text(
                        '$_messagesSentToday/$kDailyMessageLimit messages aujourd\'hui',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Nouvelle discussion',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: _isLoading ? null : _startNewConversation,
            ),
            PopupMenuButton<String>(
              tooltip: 'Menu',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'new':
                    _startNewConversation();
                    break;
                  case 'delete':
                    _confirmDeleteConversation();
                    break;
                  case 'about':
                    _showAboutSheet();
                    break;
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'new',
                  child: ListTile(
                    leading: Icon(Icons.add_comment_outlined),
                    title: Text('Nouvelle discussion'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: kMadaRed),
                    title: Text('Supprimer la discussion'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'about',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('À propos'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildBody(cs)),
              _buildInputBar(cs),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_messages.isEmpty) {
      return _buildWelcomeScreen(cs);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index], cs);
      },
    );
  }


  Widget _buildWelcomeScreen(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final cardWidth = screenWidth < 420
            ? screenWidth - 48 
            : (screenWidth - 24 - 48) / 2; 

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _brandIcon(size: 44),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: kBrandGradient,
                  ).createShader(bounds),
                  child: const Text(
                    'Tongasoa !',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Votre guide intelligent de la région du Bongolava,\nMadagascar 🇲🇬',
                  style: TextStyle(
                    fontSize: screenWidth < 360 ? 18 : 22,
                    height: 1.3,
                    color: cs.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _suggestions
                      .map((s) => _buildSuggestionCard(s, cs, cardWidth))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionCard(_Suggestion s, ColorScheme cs, double width) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isLoading ? null : () => _sendMessage(s.prompt),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            Text(
              s.title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMessageBubble(ChatMessage message, ColorScheme cs) {
    final isUser = message.isUser;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.8;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildFormattedText(message.text ?? '', color: cs.onSurface),
              ),
            ),
          ],
        ),
      );
    }

    final isThinking = message.isStreaming && (message.text == null || message.text!.isEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandIcon(size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: isThinking
                ? const _TypingDots()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.text != null && message.text!.isNotEmpty)
                        _buildFormattedText(message.text!, color: cs.onSurface),
                      if (message.text != null && message.imageData != null)
                        const SizedBox(height: 10),
                      if (message.imageData != null) _buildGeneratedImage(message.imageData!, cs),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, {required Color color}) {
    final spans = <TextSpan>[];
    final boldRegExp = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in boldRegExp.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(color: color, fontSize: 15.5, height: 1.5),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }

  Widget _buildGeneratedImage(Uint8List imageData, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_outlined, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              "Image générée par l'IA",
              style: TextStyle(fontSize: 11.5, color: cs.primary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            imageData,
            fit: BoxFit.cover,
            width: double.infinity,
            frameBuilder: (ctx, child, frame, _) {
              if (frame == null) {
                return Container(
                  height: 200,
                  color: cs.surfaceContainerHighest,
                  child: Center(child: CircularProgressIndicator(color: cs.primary)),
                );
              }
              return child;
            },
            errorBuilder: (ctx, error, stack) => Container(
              height: 120,
              color: cs.surfaceContainerHighest,
              child: const Center(child: Text("Impossible d'afficher l'image")),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildInputBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: cs.outline.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Scrollbar(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    enabled: !_isLoading,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(fontSize: 15.5, color: cs.onSurface),
                    decoration: const InputDecoration(
                      hintText: 'Posez votre question sur le Bongolava…',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: (_hasText && !_isLoading)
                      ? const LinearGradient(colors: kBrandGradient)
                      : null,
                  color: (_hasText && !_isLoading) ? null : cs.outline.withOpacity(0.15),
                ),
                child: IconButton(
                  onPressed: (_hasText && !_isLoading) ? () => _sendMessage() : null,
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    color: (_hasText && !_isLoading) ? Colors.white : cs.onSurface.withOpacity(0.35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandIcon({required double size}) {
    return ClipOval(
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}



class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 26,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value - (i * 0.2)) % 1.0;
              final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: opacity,
                  child: CircleAvatar(radius: 4, backgroundColor: cs.primary),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}