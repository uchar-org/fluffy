String stripMxReply(String html) {
  final endTag = '</mx-reply>';
  final index = html.indexOf(endTag);
  if (index == -1) return html;
  return html.substring(index + endTag.length).trim();
}
