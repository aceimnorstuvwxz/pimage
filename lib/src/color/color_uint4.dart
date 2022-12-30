import 'dart:typed_data';

import '../image/palette.dart';
import '../util/color_util.dart';
import 'channel.dart';
import 'channel_iterator.dart';
import 'color.dart';
import 'format.dart';

/// A 4-bit color value.
class ColorUint4 extends Iterable<num> implements Color {
  final int length;
  Uint8List data;

  ColorUint4(this.length)
      : data = Uint8List(length < 3 ? 1 : 2);

  ColorUint4.from(ColorUint4 other)
      : length = other.length
      , data = Uint8List.fromList(other.data);

  ColorUint4.fromList(List<int> color)
      : length = color.length
      , data = Uint8List(color.length < 3 ? 1 : 2) {
    setColor(length > 0 ? color[0] : 0,
        length > 1 ? color[1] : 0,
        length > 2 ? color[2] : 0,
        length > 3 ? color[3] : 0);
  }

  ColorUint4.rgb(int r, int g, int b)
      : length = 3
      , data = Uint8List(2) {
    setColor(r, g, b);
  }

  ColorUint4.rgba(int r, int g, int b, int a)
      : length = 4
      , data = Uint8List(2) {
    setColor(r, g, b, a);
  }

  ColorUint4 clone() => ColorUint4.from(this);

  Format get format => Format.uint4;
  num get maxChannelValue => 15;
  num get maxIndexValue => 15;
  bool get isLdrFormat => true;
  bool get isHdrFormat => false;
  bool get hasPalette => false;
  Palette? get palette => null;

  int _getChannel(int ci) => ci < 0 || ci >= length ? 0
      : ci < 2 ? (data[0] >> (4 - (ci << 2))) & 0xf
      : (data[1] >> (4 - ((ci & 0x1) << 2)) & 0xf);

  void _setChannel(int ci, num value) {
    if (ci >= length) {
      return;
    }
    final vi = value.toInt().clamp(0, 15);
    int i = 0;
    if (ci > 2) {
      ci &= 0x1;
      i = 1;
    }
    if (ci == 0) {
      data[i] = (data[i] & 0xf) | (vi << 4);
    } else if (ci == 1) {
      data[i] = (data[i] & 0xf0) | vi;
    }
  }

  num operator[](int index) => _getChannel(index);
  void operator[]=(int index, num value) => _setChannel(index, value);

  num get index => r;
  void set index(num i) => r = i;

  num get r => _getChannel(0);
  void set r(num v) => _setChannel(0, v);

  num get g => _getChannel(1);
  void set g(num v) => _setChannel(1, v);

  num get b => _getChannel(2);
  void set b(num v) => _setChannel(2, v);

  num get a => _getChannel(3);
  void set a(num v) => _setChannel(3, v);

  num get rNormalized => r / maxChannelValue;
  void set rNormalized(num v) => r = v * maxChannelValue;

  num get gNormalized => g / maxChannelValue;
  void set gNormalized(num v) => g = v * maxChannelValue;

  num get bNormalized => b / maxChannelValue;
  void set bNormalized(num v) => b = v * maxChannelValue;

  num get aNormalized => a / maxChannelValue;
  void set aNormalized(num v) => a = v * maxChannelValue;

  num get luminance => getLuminance(this);
  num get luminanceNormalized => getLuminanceNormalized(this);

  num getChannel(Channel channel) => channel == Channel.luminance ?
      luminance : _getChannel(channel.index);

  num getChannelNormalized(Channel channel) =>
      getChannel(channel) / maxChannelValue;

  void set(Color c) {
    setColor(c.r, c.g, c.b, c.a);
  }

  void setColor(num r, [num g = 0, num b = 0, num a = 0]) {
    final ri = r.toInt().clamp(0, 15) & 0xf;
    final gi = g.toInt().clamp(0, 15) & 0xf;
    final bi = b.toInt().clamp(0, 15) & 0xf;
    final ai = a.toInt().clamp(0, 15) & 0xf;
    data[0] = (ri << 4) | gi;
    data[1] = (bi << 4) | ai;
  }

  ChannelIterator get iterator => ChannelIterator(this);

  bool operator==(Object? other) =>
      other is Color &&
          other.length == length &&
          other.hashCode == hashCode;

  int get hashCode => Object.hashAll(toList());

  Color convert({ Format? format, int? numChannels, num? alpha }) =>
      convertColor(this, format: format, numChannels: numChannels,
          alpha: alpha);
}