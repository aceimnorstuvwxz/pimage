import '../color/color.dart';
import '../color/color_uint8.dart';
import '../image/image.dart';
import '../image/palette_uint8.dart';
import 'quantizer.dart';

class _RGB {
  final int r;
  final int g;
  final int b;

  _RGB({required this.r, required this.g, required this.b});
}

// Color quantization using octree,
// from https://rosettacode.org/wiki/Color_quantization/C
class OctreeQuantizer extends Quantizer {
  @override
  late PaletteUint8 palette;
  final _OctreeNode _root;
  late int transIndex;
  final List<_RGB> rgbPaletteColors = [];

  OctreeQuantizer(Image image, {int numberOfColors = 256})
      : _root = _OctreeNode(0, 0, null) {
    final heap = _HeapNode();
    for (final p in image) {
      if (p.a > 0) {
        final r = p.r as int;
        final g = p.g as int;
        final b = p.b as int;
        _heapAdd(heap, _nodeInsert(_root, r, g, b));
      }
    }

    final nc = numberOfColors; //原来的+1去掉，因为我们最后一个要用来放透明颜色
    while (heap.n > nc) {
      _heapAdd(heap, _nodeFold(_popHeap(heap)!)!);
    }

    for (var i = 1; i < heap.n; i++) {
      final got = heap.buf[i]!;
      final c = got.count;
      got
        ..r = (got.r / c).round()
        ..g = (got.g / c).round()
        ..b = (got.b / c).round();
    }

    final nodes = <_OctreeNode>[];
    _getNodes(nodes, _root);

    // palette = PaletteUint8(nodes.length, 3);
    palette =
        PaletteUint8(nodes.length + 1, 4); //g787 原来最后结果是3通道，改成4通道，增加alpha通道
    //+1是为了给最后一个透明颜色留位置
    final l = nodes.length;
    for (var i = 0; i < l; i++) {
      final n = nodes[i]..paletteIndex = i;
      palette.setRgba(i, n.r, n.g, n.b, 255);

      rgbPaletteColors.add(_RGB(r: n.r, g: n.g, b: n.b));
    }
    //g787 最后一个颜色，始终全部透明！
    // ignore: cascade_invocations
    palette.setAlpha(l, 0); //设置最后一个颜色为透明
    transIndex = l; //透明颜色的index
    // print("-------transIndex=$transIndex");
  }

  @override
  int getColorIndex(Color c) {
    //g787问题
    if (c.a < 30) {
      // print("----transIndex=$transIndex");
      return transIndex;
    }
    return getColorIndexRgb(c.r.toInt(), c.g.toInt(), c.b.toInt());
  }

  @override
  int getColorIndexRgb(int r, int g, int b) {
    _OctreeNode? root = _root;
    for (var bit = 1 << 7; bit != 0; bit >>= 1) {
      final i = ((g & bit) != 0 ? 1 : 0) * 4 +
          ((r & bit) != 0 ? 1 : 0) * 2 +
          ((b & bit) != 0 ? 1 : 0);
      if (root!.children[i] == null) {
        break;
      }
      root = root.children[i];
    }
    if (root == null) {
      // print("----->nil node=$r $g $b");
    } else if (root.paletteIndex == 0) {
      // print("----->0 index=$r $g $b");
      //为什么有些位置，会错误地归到0（有些是本来就是0的）
      //暴力办法纠正
      return _indexSearch(r, g, b);
    }
    return root?.paletteIndex ?? 0;
  }

  int _abs(int a) => a < 0 ? -a : a;

  int _indexSearch(int r, int g, int b) {
    int d = 999999;
    int retI = 0;
    for (var i = 0; i < rgbPaletteColors.length; i++) {
      final cc = rgbPaletteColors[i];
      final nd = _abs(cc.r - r) + _abs(cc.g - g) + _abs(cc.b - b);
      if (nd < d) {
        d = nd;
        retI = i;
      }
    }
    return retI;
  }

  void _getNodes(List<_OctreeNode> nodes, _OctreeNode node) {
    if (node.childCount == 0) {
      nodes.add(node);
      return;
    }
    for (var node in node.children) {
      if (node != null) {
        _getNodes(nodes, node);
      }
    }
  }

  /// Find the index of the closest color to [c] in the colorMap.
  @override
  Color getQuantizedColor(Color c) {
    var r = c.r as int;
    var g = c.g as int;
    var b = c.b as int;
    _OctreeNode? root = _root;

    for (var bit = 1 << 7; bit != 0; bit >>= 1) {
      final i = ((g & bit) != 0 ? 1 : 0) * 4 +
          ((r & bit) != 0 ? 1 : 0) * 2 +
          ((b & bit) != 0 ? 1 : 0);
      if (root!.children[i] == null) {
        break;
      }
      root = root.children[i];
    }

    r = root!.r;
    g = root.g;
    b = root.b;
    return ColorRgb8(r, g, b);
  }

  int _compareNode(_OctreeNode a, _OctreeNode b) {
    if (a.childCount < b.childCount) {
      return -1;
    }
    if (a.childCount > b.childCount) {
      return 1;
    }

    final ac = a.count >> a.depth;
    final bc = b.count >> b.depth;
    return (ac < bc)
        ? -1
        : (ac > bc)
            ? 1
            : 0;
  }

  _OctreeNode _nodeInsert(_OctreeNode root, int r, int g, int b) {
    var depth = 0;
    for (var bit = 1 << 7; ++depth < 8; bit >>= 1) {
      final i = ((g & bit) != 0 ? 1 : 0) * 4 +
          ((r & bit) != 0 ? 1 : 0) * 2 +
          ((b & bit) != 0 ? 1 : 0);
      if (root.children[i] == null) {
        root.children[i] = _OctreeNode(i, depth, root);
      }

      root = root.children[i]!;
    }

    root
      ..r += r
      ..g += g
      ..b += b;
    root.count++;
    return root;
  }

  _OctreeNode? _nodeFold(_OctreeNode p) {
    if (p.childCount > 0) {
      return null;
    }
    final q = p.parent!
      ..count += p.count
      ..r += p.r
      ..g += p.g
      ..b += p.b;
    q.childCount--;
    q.children[p.childIndex] = null;
    return q;
  }

  static const _inHeap = 1;

  _OctreeNode? _popHeap(_HeapNode h) {
    if (h.n <= 1) {
      return null;
    }

    final ret = h.buf[1];
    h.buf[1] = h.buf.removeLast();
    h.buf[1]!.heapIndex = 1;
    _downHeap(h, h.buf[1]!);

    return ret;
  }

  void _heapAdd(_HeapNode h, _OctreeNode p) {
    if ((p.flags & _inHeap) != 0) {
      _downHeap(h, p);
      _upHeap(h, p);
      return;
    }

    p
      ..flags |= _inHeap
      ..heapIndex = h.n;
    h.buf.add(p);
    _upHeap(h, p);
  }

  void _downHeap(_HeapNode h, _OctreeNode p) {
    var n = p.heapIndex;
    while (true) {
      var m = n * 2;
      if (m >= h.n) {
        break;
      }
      if ((m + 1) < h.n && _compareNode(h.buf[m]!, h.buf[m + 1]!) > 0) {
        m++;
      }

      if (_compareNode(p, h.buf[m]!) <= 0) {
        break;
      }

      h.buf[n] = h.buf[m];
      h.buf[n]!.heapIndex = n;
      n = m;
    }

    h.buf[n] = p;
    p.heapIndex = n;
  }

  void _upHeap(_HeapNode h, _OctreeNode p) {
    var n = p.heapIndex;
    _OctreeNode? prev;

    while (n > 1) {
      prev = h.buf[n ~/ 2];
      if (_compareNode(p, prev!) >= 0) {
        break;
      }

      h.buf[n] = prev;
      prev.heapIndex = n;
      n ~/= 2;
    }
    h.buf[n] = p;
    p.heapIndex = n;
  }
}

class _OctreeNode {
  // sum of all colors represented by this node.
  int r = 0;
  int g = 0;
  int b = 0;
  int count = 0;
  int heapIndex = 0;
  int paletteIndex = 0;
  List<_OctreeNode?> children = List<_OctreeNode?>.filled(8, null);
  _OctreeNode? parent;
  int childCount = 0;
  int childIndex = 0;
  int flags = 0;
  int depth = 0;

  _OctreeNode(this.childIndex, this.depth, this.parent) {
    if (parent != null) {
      parent!.childCount++;
    }
  }
}

class _HeapNode {
  List<_OctreeNode?> buf = [null];
  int get n => buf.length;
}
