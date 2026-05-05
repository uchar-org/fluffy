import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluffychat/widgets/app_lock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

Future<List<XFile>> selectFiles(
  BuildContext context, {
  String? title,
  FileType type = FileType.any,
  bool allowMultiple = false,
}) async {
  final result = await AppLock.of(context).pauseWhile(
    FilePicker.pickFiles(
      compressionQuality: 0,
      allowMultiple: allowMultiple,
      type: type,
      withData: kIsWeb,
    ),
  );
  return result?.xFiles ?? [];
}
