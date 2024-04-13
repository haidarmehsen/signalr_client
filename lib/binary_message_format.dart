import 'dart:typed_data';
import 'dart:math';

class BinaryMessageFormat {
  // Properties

  static const recordSeparatorCode = 0x1e;
  static String recordSeparator =
      String.fromCharCode(BinaryMessageFormat.recordSeparatorCode);

  static Uint8List write(Uint8List output) {
    var size = output.length;

    final lenBuffer = [];
    do {
      var sizePart = size & 0x7f;
      size = size >> 7;
      if (size > 0) {
        sizePart |= 0x80;
      }
      lenBuffer.add(sizePart);
    } while (size > 0);

    size = output.length;

    final buf = Uint8List(lenBuffer.length + size);
    final dat = ByteData.view(buf.buffer, buf.offsetInBytes);
    var offset = 0;
    final builder = BytesBuilder(copy: false);

    for (var element in lenBuffer) {
      dat.setUint8(offset, element);
      offset++;
    }
    for (var element in output) {
      dat.setUint8(offset, element);
      offset++;
    }
    builder.add(Uint8List.view(
      buf.buffer,
      buf.offsetInBytes,
      offset,
    ));
    final x = builder.takeBytes();
    return x;
  }

  static List<Uint8List> parse(Uint8List input) {
    final List<Uint8List> result = [];
    final uInt8Array = input;
    const maxLengthPrefixSize = 5;
    const numBitsToShift = [0, 7, 14, 21, 28];

    for (var offset = 0; offset < input.length;) {
      var numBytes = 0;
      var size = 0;
      int byteRead;
      do {
        byteRead = uInt8Array[offset + numBytes];
        size = size | ((byteRead & 0x7f) << (numBitsToShift[numBytes]));
        numBytes++;
      } while (numBytes < min(maxLengthPrefixSize, input.length - offset) &&
          (byteRead & 0x80) != 0);

      if ((byteRead & 0x80) != 0 && numBytes < maxLengthPrefixSize) {
        throw Exception("Cannot read message size.");
      }

      if (numBytes == maxLengthPrefixSize && byteRead > 7) {
        throw Exception("Messages bigger than 2GB are not supported.");
      }

      if (uInt8Array.length >= (offset + numBytes + size)) {
        result.add(
            uInt8Array.sublist(offset + numBytes, offset + numBytes + size));
      } else {
        throw Exception("Incomplete message.");
      }

      offset = offset + numBytes + size;
    }

    return result;
  }
}
