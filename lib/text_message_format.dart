class TextMessageFormat {
  // Properties

  static const recordSeparatorCode = 0x1e;
  static String recordSeparator =
      String.fromCharCode(TextMessageFormat.recordSeparatorCode);

  static String write(String output) {
    return "$output${TextMessageFormat.recordSeparator}";
  }

  static List<String> parse(String input) {
    if (input[input.length - 1] != TextMessageFormat.recordSeparator) {
      throw Exception("Message is incomplete.");
    }

    var messages = input.split(TextMessageFormat.recordSeparator);

    messages.removeLast();
    return messages;
  }
}
