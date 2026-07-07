// ============================================================
//  bongolava_chat_page.dart
//  Page principale du chat IA - Guide touristique du Bongolava
//  Interface modernisée (inspiration Gemini)
//  Auteur : RATAHINJANAHARY Ruphin Henri (ENI Fianarantsoa)
//  Spécialité : Intelligence Artificielle / Objets Connectés & Cybersécurité
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'main.dart';

// ──────────────────────────────────────────────────────────────
//  MODÈLE DE MESSAGE
// ──────────────────────────────────────────────────────────────

class ChatMessage {
  final String? text;
  final Uint8List? imageData;
  final bool isUser;

  const ChatMessage({this.text, this.imageData, required this.isUser});
}

// ──────────────────────────────────────────────────────────────
//  INSTRUCTION SYSTÈME DE L'IA (systemInstruction)
// ──────────────────────────────────────────────────────────────
//
// 1. Identité exacte à donner si on demande le créateur
// 2. Coordonnées données UNIQUEMENT en cas d'insistance
// 3. Spécialisation exclusive sur le Bongolava
// 4. Réponse toujours dans la langue de l'utilisateur
// 5. Génération d'images
//
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
E-mail : ruphinhenriratahinjanahary@gmail.com
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

/// Suggestions affichées sur l'écran d'accueil (façon "prompts" Gemini)
const List<_Suggestion> _suggestions = [
  _Suggestion('🐂', 'Le marché de zébus', 'Parle-moi du marché de zébus de Tsiroanomandidy'),
  _Suggestion('🏔️', 'Paysages du Bongolava', 'Décris-moi les collines et paysages du Bongolava'),
  _Suggestion('🏛️', 'Histoire & culture', "Quelle est l'histoire de la région du Bongolava ?"),
  _Suggestion('📍', 'Bevato & Ambohipisaka', 'Parle-moi de la commune de Bevato'),
];

class _Suggestion {
  final String emoji;
  final String title;
  final String prompt;
  const _Suggestion(this.emoji, this.title, this.prompt);
}

// ──────────────────────────────────────────────────────────────
//  PAGE PRINCIPALE DU CHAT
// ──────────────────────────────────────────────────────────────

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

  late final GenerativeModel _model;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _initGemini();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  void _initGemini() {
    // Modèle 100% gratuit (plan Spark) : texte uniquement.
    // Les modèles Gemini capables de générer des images nécessitent le plan
    // payant Blaze — on reste donc sur un modèle texte pour rester gratuit.
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.8,
        maxOutputTokens: 2048,
      ),
    );
    _chat = _model.startChat();
    // Pas de message de bienvenue en dur : on affiche un écran d'accueil
    // façon Gemini tant qu'il n'y a pas encore de message (voir _buildBody).
  }

  // ── Gestion des messages ──────────────────────────────────────

  void _addBotMessage({String? text, Uint8List? imageData}) {
    setState(() {
      _messages.add(ChatMessage(text: text, imageData: imageData, isUser: false));
    });
    _scrollToBottom();
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

  Future<void> _sendMessage([String? presetText]) async {
    final userText = (presetText ?? _inputController.text).trim();
    if (userText.isEmpty || _isLoading) return;

    _addUserMessage(userText);
    _inputController.clear();
    setState(() => _isLoading = true);

    try {
      final response = await _chat.sendMessage(Content.text(userText));

      String? responseText;
      Uint8List? responseImage;

      if (response.candidates.isNotEmpty) {
        final candidate = response.candidates.first;
        for (final part in candidate.content.parts) {
          if (part is TextPart) {
            responseText = (responseText ?? '') + part.text;
          } else if (part is InlineDataPart) {
            responseImage = part.bytes;
          }
        }
      }

      if (responseText != null || responseImage != null) {
        _addBotMessage(text: responseText, imageData: responseImage);
      } else {
        _addBotMessage(text: "Je n'ai pas pu générer une réponse. Veuillez réessayer. 🙏");
      }
    } catch (e) {
      _addBotMessage(
        text: "⚠️ Une erreur est survenue : ${e.toString()}\n\n"
              "Vérifiez votre connexion internet ou réessayez plus tard.",
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Construction de l'interface ────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            _brandIcon(size: 32),
            const SizedBox(width: 10),
            const Text(
              'Bongolava AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _messages.clear();
                      _chat = _model.startChat();
                    }),
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
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_messages.isEmpty) {
      return _buildWelcomeScreen(cs);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == _messages.length) {
          return _buildTypingIndicator(cs);
        }
        return _buildMessageBubble(_messages[index], cs);
      },
    );
  }

  // ── Écran d'accueil (façon Gemini) ─────────────────────────────

  Widget _buildWelcomeScreen(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                    fontSize: 22,
                    height: 1.3,
                    color: cs.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _suggestions.map((s) => _buildSuggestionCard(s, cs)).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionCard(_Suggestion s, ColorScheme cs) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isLoading ? null : () => _sendMessage(s.prompt),
      child: Container(
        width: 190,
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

  // ── Bulles de message ──────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage message, ColorScheme cs) {
    final isUser = message.isUser;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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

    // Message IA : pas de bulle, façon Gemini — icône + texte plein largeur
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandIcon(size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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

    return RichText(
      text: TextSpan(
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
              'Image générée par l\'IA',
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
              child: const Center(child: Text('⚠️ Impossible d\'afficher l\'image')),
            ),
          ),
        ),
      ],
    );
  }

  /// Indicateur "en train d'écrire" à 3 points animés (façon Gemini)
  Widget _buildTypingIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandIcon(size: 26),
          const SizedBox(width: 12),
          const _TypingDots(),
        ],
      ),
    );
  }

  // ── Barre de saisie ─────────────────────────────────────────────

  Widget _buildInputBar(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12,
      ),
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
          children: [
            Expanded(
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
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedContainer(
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
          ],
        ),
      ),
    );
  }

  /// Icône de la marque : pastille avec dégradé vert → rouge (Madagascar)
  Widget _brandIcon({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: kBrandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          '🇲🇬',
          style: TextStyle(fontSize: size * 0.5),
        ),
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

// ──────────────────────────────────────────────────────────────
//  Indicateur "3 points" animé
// ──────────────────────────────────────────────────────────────

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