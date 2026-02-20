import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:matrix/matrix.dart';
import 'package:slugify/slugify.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/markdown_context_builder.dart';
import 'package:fluffychat/widgets/mxc_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/matrix.dart';
import 'command_hints.dart';

class InputBar extends StatefulWidget {
  final Room room;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<Uint8List?>? onSubmitImage;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final bool? autofocus;
  final bool readOnly;
  final List<Emoji> suggestionEmojis;

  const InputBar({
    required this.room,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.onSubmitted,
    this.onSubmitImage,
    this.focusNode,
    this.controller,
    required this.decoration,
    this.onChanged,
    this.autofocus,
    this.textInputAction,
    this.readOnly = false,
    required this.suggestionEmojis,
    super.key,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  // Multi-select uchun tanlangan userlar
  final Set<String> _selectedMxids = {};
  // Qaysi suggestion multi-select modeda (@ yoki user search)

  List<Map<String, String?>> getSuggestions(TextEditingValue text) {
    if (text.selection.baseOffset != text.selection.extentOffset || text.selection.baseOffset < 0) {
      return [];
    }
    final searchText = text.text.substring(0, text.selection.baseOffset);
    final ret = <Map<String, String?>>[];
    const maxResults = 30;

    final commandMatch = RegExp(r'^/(\w*)$').firstMatch(searchText);
    if (commandMatch != null) {
      final commandSearch = commandMatch[1]!.toLowerCase();
      for (final command in widget.room.client.commands.keys) {
        if (command.contains(commandSearch)) {
          ret.add({'type': 'command', 'name': command});
        }
        if (ret.length > maxResults) return ret;
      }
    }

    final emojiMatch = RegExp(
      r'(?:\s|^):(?:([\p{L}\p{N}_-]+)~)?([\p{L}\p{N}_-]+)$',
      unicode: true,
    ).firstMatch(searchText);
    if (emojiMatch != null) {
      final packSearch = emojiMatch[1];
      final emoteSearch = emojiMatch[2]!.toLowerCase();
      final emotePacks = widget.room.getImagePacks(ImagePackUsage.emoticon);
      if (packSearch == null || packSearch.isEmpty) {
        for (final pack in emotePacks.entries) {
          for (final emote in pack.value.images.entries) {
            if (emote.key.toLowerCase().contains(emoteSearch)) {
              ret.add({
                'type': 'emote',
                'name': emote.key,
                'pack': pack.key,
                'pack_avatar_url': pack.value.pack.avatarUrl?.toString(),
                'pack_display_name': pack.value.pack.displayName ?? pack.key,
                'mxc': emote.value.url.toString(),
              });
            }
            if (ret.length > maxResults) break;
          }
          if (ret.length > maxResults) break;
        }
      }

      final matchingUnicodeEmojis = widget.suggestionEmojis
          .where((emoji) => emoji.name.toLowerCase().contains(emoteSearch))
          .toList();
      matchingUnicodeEmojis.sort((a, b) {
        final indexA = a.name.indexOf(emoteSearch);
        final indexB = b.name.indexOf(emoteSearch);
        if (indexA == -1 || indexB == -1) {
          if (indexA == indexB) return 0;
          return indexA == -1 ? 1 : 0;
        }
        return indexA.compareTo(indexB);
      });
      for (final emoji in matchingUnicodeEmojis) {
        ret.add({'type': 'emoji', 'emoji': emoji.emoji, 'label': emoji.name, 'current_word': ':$emoteSearch'});
        if (ret.length > maxResults) break;
      }
    }

    final userMatch = RegExp(r'(?:\s|^)@([-\w]*)$').firstMatch(searchText);
    if (userMatch != null) {
      final userSearch = userMatch[1]!.toLowerCase();

      for (final user in widget.room.getParticipants()) {
        // Agar search bo'sh bo'lsa (faqat @ kiritilgan) - barchani ko'rsat
        // Agar search bo'lsa - filter qil
        final matchesSearch =
            userSearch.isEmpty ||
            (user.displayName != null &&
                (user.displayName!.toLowerCase().contains(userSearch) ||
                    slugify(user.displayName!.toLowerCase()).contains(userSearch))) ||
            user.id.split(':')[0].toLowerCase().contains(userSearch);

        if (matchesSearch) {
          ret.add({
            'type': 'user',
            'mxid': user.id,
            'mention': user.mention,
            'displayname': user.displayName,
            'avatar_url': user.avatarUrl?.toString(),
            // Multi-select uchun tanlangan holat
            'selected': _selectedMxids.contains(user.id) ? 'true' : 'false',
          });
        }
        if (ret.length > maxResults) break;
      }
    } else {
    }

    final roomMatch = RegExp(r'(?:\s|^)#([-\w]+)$').firstMatch(searchText);
    if (roomMatch != null) {
      final roomSearch = roomMatch[1]!.toLowerCase();
      for (final r in widget.room.client.rooms) {
        if (r.getState(EventTypes.RoomTombstone) != null) continue;
        final state = r.getState(EventTypes.RoomCanonicalAlias);
        if ((state != null &&
                ((state.content['alias'] is String &&
                        state.content.tryGet<String>('alias')!.split(':')[0].toLowerCase().contains(roomSearch)) ||
                    (state.content['alt_aliases'] is List &&
                        (state.content['alt_aliases'] as List).any(
                          (l) => l is String && l.split(':')[0].toLowerCase().contains(roomSearch),
                        )))) ||
            (r.name.toLowerCase().contains(roomSearch))) {
          ret.add({
            'type': 'room',
            'mxid': (r.canonicalAlias.isNotEmpty) ? r.canonicalAlias : r.id,
            'displayname': r.getLocalizedDisplayname(),
            'avatar_url': r.avatar?.toString(),
          });
        }
        if (ret.length > maxResults) break;
      }
    }

    return ret;
  }

  Widget buildSuggestion(
    BuildContext context,
    Map<String, String?> suggestion,
    void Function(Map<String, String?>) onSelected,
    Client? client,
    double width,
  ) {
    final theme = Theme.of(context);
    const size = 30.0;

    if (suggestion['type'] == 'command') {
      final command = suggestion['name']!;
      final hint = commandHint(L10n.of(context), command);
      return Tooltip(
        message: hint,
        waitDuration: const Duration(days: 1),
        child: ListTile(
          onTap: () => onSelected(suggestion),
          title: Text(commandExample(command), style: const TextStyle(fontFamily: 'RobotoMono')),
          subtitle: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        ),
      );
    }

    if (suggestion['type'] == 'emoji') {
      final label = suggestion['label']!;
      return Tooltip(
        message: label,
        waitDuration: const Duration(days: 1),
        child: ListTile(
          onTap: () => onSelected(suggestion),
          leading: SizedBox.square(
            dimension: size,
            child: Text(suggestion['emoji']!, style: const TextStyle(fontSize: 16)),
          ),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    if (suggestion['type'] == 'emote') {
      return ListTile(
        onTap: () => onSelected(suggestion),
        leading: MxcImage(
          key: ValueKey(suggestion['name']),
          uri: suggestion['mxc'] is String ? Uri.parse(suggestion['mxc'] ?? '') : null,
          width: size,
          height: size,
          isThumbnail: false,
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(suggestion['name']!),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: suggestion['pack_avatar_url'] != null ? 0.8 : 0.5,
                  child: suggestion['pack_avatar_url'] != null
                      ? Avatar(
                          mxContent: Uri.tryParse(suggestion.tryGet<String>('pack_avatar_url') ?? ''),
                          name: suggestion.tryGet<String>('pack_display_name'),
                          size: size * 0.9,
                          client: client,
                        )
                      : Text(suggestion['pack_display_name']!),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (suggestion['type'] == 'user') {
      final mxid = suggestion['mxid']!;
      final url = Uri.parse(suggestion['avatar_url'] ?? '');

      return StatefulBuilder(
        builder: (context, setTileState) {
          return ListTile(
            onTap: () {
              onSelected(suggestion);
            },
            leading: Avatar(
              mxContent: url,
              name: suggestion.tryGet<String>('displayname') ?? suggestion.tryGet<String>('mxid'),
              size: size,
              client: client,
            ),
            title: Text(suggestion['displayname'] ?? suggestion['mxid']!),
            subtitle: Text(mxid, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          );
        },
      );
    }

    if (suggestion['type'] == 'room') {
      final url = Uri.parse(suggestion['avatar_url'] ?? '');
      return ListTile(
        onTap: () => onSelected(suggestion),
        leading: Avatar(
          mxContent: url,
          name: suggestion.tryGet<String>('displayname') ?? suggestion.tryGet<String>('mxid'),
          size: size,
          client: client,
        ),
        title: Text(suggestion['displayname'] ?? suggestion['mxid']!),
      );
    }

    return const SizedBox.shrink();
  }

  String insertSuggestion(Map<String, String?> suggestion) {
    final controller = widget.controller!;
    final replaceText = controller.text.substring(0, controller.selection.baseOffset);
    var startText = '';
    final afterText = replaceText == controller.text
        ? ''
        : controller.text.substring(controller.selection.baseOffset + 1);

    if (suggestion['type'] == 'command') {
      final insertText = '${suggestion['name']!} ';
      startText = replaceText.replaceAllMapped(RegExp(r'^(/\w*)$'), (Match m) => '/$insertText');
    }

    if (suggestion['type'] == 'emoji') {
      final insertText = '${suggestion['emoji']!} ';
      startText = replaceText.replaceAllMapped(suggestion['current_word']!, (Match m) => insertText);
    }

    if (suggestion['type'] == 'emote') {
      var isUnique = true;
      final insertEmote = suggestion['name'];
      final insertPack = suggestion['pack'];
      final emotePacks = widget.room.getImagePacks(ImagePackUsage.emoticon);
      for (final pack in emotePacks.entries) {
        if (pack.key == insertPack) continue;
        for (final emote in pack.value.images.entries) {
          if (emote.key == insertEmote) {
            isUnique = false;
            break;
          }
        }
        if (!isUnique) break;
      }
      final insertText = ':${isUnique ? '' : '${insertPack!}~'}$insertEmote: ';
      startText = replaceText.replaceAllMapped(
        RegExp(r'(\s|^)(:(?:[-\w]+~)?[-\w]+)$'),
        (Match m) => '${m[1]}$insertText',
      );
    }

    if (suggestion['type'] == 'user') {
      // Multi-select: agar bir nechta tanlangan bo'lsa, barchani qo'shamiz
      if (_selectedMxids.isNotEmpty) {
        // Barcha tanlangan userlarni mention sifatida qo'shamiz
        final mentions = _selectedMxids
            .map((mxid) {
              final user = widget.room.getParticipants().firstWhere(
                (u) => u.id == mxid,
                orElse: () => throw Exception(),
              );
              return user.mention;
            })
            .join(' ');

        // @ pattern ni topib o'rniga qo'yamiz
        startText = replaceText.replaceAllMapped(RegExp(r'(\s|^)(@[-\w]*)$'), (Match m) => '${m[1]}$mentions ');

        // Selection ni tozalaymiz
        _selectedMxids.clear();
      } else {
        // Oddiy single select
        final insertText = '${suggestion['mention']!} ';
        startText = replaceText.replaceAllMapped(RegExp(r'(\s|^)(@[-\w]*)$'), (Match m) => '${m[1]}$insertText');
      }
    }

    if (suggestion['type'] == 'room') {
      final insertText = '${suggestion['mxid']!} ';
      startText = replaceText.replaceAllMapped(RegExp(r'(\s|^)(#[-\w]+)$'), (Match m) => '${m[1]}$insertText');
    }

    return startText + afterText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Autocomplete<Map<String, String?>>(
      focusNode: widget.focusNode,
      textEditingController: widget.controller,
      optionsBuilder: getSuggestions,
      fieldViewBuilder: (context, controller, focusNode, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: widget.readOnly,
        contextMenuBuilder: (c, e) => markdownContextBuilder(c, e, controller),
        contentInsertionConfiguration: ContentInsertionConfiguration(
          onContentInserted: (KeyboardInsertedContent content) {
            final data = content.data;
            if (data == null) return;
            final file = MatrixFile(mimeType: content.mimeType, bytes: data, name: content.uri.split('/').last);
            widget.room.sendFileEvent(file, shrinkImageMaxDimension: 1600);
          },
        ),
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType!,
        textInputAction: widget.textInputAction,
        autofocus: widget.autofocus!,
        inputFormatters: [LengthLimitingTextInputFormatter((maxPDUSize / 3).floor())],
        onSubmitted: (text) => widget.onSubmitted!(text),
        maxLength: AppSettings.textMessageMaxLength.value,
        decoration: widget.decoration,
        onChanged: (text) => widget.onChanged!(text),
        textCapitalization: TextCapitalization.sentences,
      ),
      optionsViewBuilder: (c, onSelected, s) {
        final suggestions = s.toList();
        final maxWidth = MediaQuery.of(context).size.width > 300 ? 300.0 : MediaQuery.of(context).size.width * .7;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .3,
            maxWidth: maxWidth,
            minWidth: 300,
          ),
          child: Material(
            elevation: theme.appBarTheme.scrolledUnderElevation ?? 4,
            shadowColor: theme.appBarTheme.shadowColor,
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
            clipBehavior: Clip.hardEdge,
            child: Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, i) =>
                    buildSuggestion(c, suggestions[i], onSelected, Matrix.of(context).client, maxWidth),
              ),
            ),
          ),
        );
      },
      displayStringForOption: insertSuggestion,
      optionsViewOpenDirection: OptionsViewOpenDirection.up,
    );
  }
}
