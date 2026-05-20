import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class StickyOverlayContainer extends StatefulWidget {
  /// 主体内容（例如聊天气泡、大横幅图等）
  final Widget child;

  /// 需要吸附在边缘的工具栏或其他浮动组件
  final Widget overlay;

  /// 对齐方式，决定了它默认的停靠位置以及它将会向哪个方向吸附
  final Alignment alignment;

  /// 控件内容边缘的四周间距
  final EdgeInsets margin;

  /// 视口的额外留白（防止被 AppBar 遮盖）
  final EdgeInsets viewportPadding;

  const StickyOverlayContainer({
    Key? key,
    required this.child,
    required this.overlay,
    this.alignment = Alignment.bottomLeft,
    this.margin = const EdgeInsets.all(8.0),
    this.viewportPadding = EdgeInsets.zero,
  }) : super(key: key);

  @override
  State<StickyOverlayContainer> createState() => _StickyOverlayContainerState();
}

class _StickyOverlayContainerState extends State<StickyOverlayContainer> {
  ScrollPosition? _scrollPosition;
  RenderBox? _scrollableBox;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 监听最近的滚动容器（ListView / SingleChildScrollView 等）
    final scrollableState = Scrollable.maybeOf(context);
    if (scrollableState != null) {
      if (scrollableState.position != _scrollPosition) {
        _scrollPosition = scrollableState.position;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollableBox =
              scrollableState.context.findRenderObject() as RenderBox?;
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 主体层，决定 Stack 的整体原始大小
        widget.child,

        // 浮层：直接通过 Positioned.fill 占满空间，使用一个极简的 RenderBox 进行所有调度
        Positioned.fill(
          child: _StickyOverlayLayoutWidget(
            scrollPosition: _scrollPosition,
            scrollableBox: _scrollableBox,
            alignment: widget.alignment,
            margin: widget.margin,
            viewportPadding: widget.viewportPadding,
            child: widget.overlay,
          ),
        ),
      ],
    );
  }
}

/// ===========================
/// 核心渲染层：接管对齐、偏移计算及约束
/// ===========================

class _StickyOverlayLayoutWidget extends SingleChildRenderObjectWidget {
  final ScrollPosition? scrollPosition;
  final RenderBox? scrollableBox;
  final Alignment alignment;
  final EdgeInsets margin;
  final EdgeInsets viewportPadding;

  const _StickyOverlayLayoutWidget({
    Key? key,
    required Widget child,
    required this.scrollPosition,
    required this.scrollableBox,
    required this.alignment,
    required this.margin,
    required this.viewportPadding,
  }) : super(key: key, child: child);

  @override
  _RenderStickyOverlayLayout createRenderObject(BuildContext context) {
    return _RenderStickyOverlayLayout(
      scrollPosition: scrollPosition,
      scrollableBox: scrollableBox,
      alignment: alignment,
      margin: margin,
      viewportPadding: viewportPadding,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderStickyOverlayLayout renderObject) {
    renderObject
      ..scrollPosition = scrollPosition
      ..scrollableBox = scrollableBox
      ..alignment = alignment
      ..margin = margin
      ..viewportPadding = viewportPadding;
  }
}

class _RenderStickyOverlayLayout extends RenderShiftedBox {
  ScrollPosition? _scrollPosition;
  RenderBox? _scrollableBox;
  Alignment _alignment;
  EdgeInsets _margin;
  EdgeInsets _viewportPadding;

  _RenderStickyOverlayLayout({
    RenderBox? child,
    ScrollPosition? scrollPosition,
    RenderBox? scrollableBox,
    required Alignment alignment,
    required EdgeInsets margin,
    required EdgeInsets viewportPadding,
  })  : _scrollPosition = scrollPosition,
        _scrollableBox = scrollableBox,
        _alignment = alignment,
        _margin = margin,
        _viewportPadding = viewportPadding,
        super(child);

  set scrollableBox(RenderBox? value) {
    _scrollableBox = value;
  }

  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout(); // alignment 改变需要重新触发基础 Layout 偏移计算
  }

  set margin(EdgeInsets value) {
    if (_margin == value) return;
    _margin = value;
    markNeedsLayout();
  }

  set viewportPadding(EdgeInsets value) {
    if (_viewportPadding == value) return;
    _viewportPadding = value;
    markNeedsPaint(); // 仅影响滚动偏移，重绘即可
  }

  set scrollPosition(ScrollPosition? value) {
    if (_scrollPosition == value) return;
    if (attached) _scrollPosition?.removeListener(markNeedsPaint);
    _scrollPosition = value;
    if (attached) _scrollPosition?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scrollPosition?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scrollPosition?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    // 外层处于 Positioned.fill 中，这里拿到的 constrained 限制正好等同主体 child 的大小
    size = constraints.biggest;

    if (child != null) {
      // 解决 Bug 2 的关键：给予 overlay 无限制的 BoxConstraints()，让它使用真实自由的内部宽度
      // 从而防止因为主体内容较窄而被动压缩导致的异常高度拉伸折行
      child!.layout(const BoxConstraints(), parentUsesSize: true);

      final double childWidth = child!.size.width;
      final double childHeight = child!.size.height;

      // 像 Align 和 Padding 那样，计算出 overlay 的初始落脚座标
      double x = 0.0;
      if (_alignment.x == -1.0) {
        x = _margin.left;
      } else if (_alignment.x == 1.0) {
        x = size.width - childWidth - _margin.right;
      } else {
        double availableX = size.width - _margin.horizontal - childWidth;
        double halfX = availableX / 2;
        x = _margin.left + halfX + (_alignment.x * halfX);
      }

      double y = 0.0;
      if (_alignment.y == -1.0) {
        y = _margin.top;
      } else if (_alignment.y == 1.0) {
        y = size.height - childHeight - _margin.bottom;
      } else {
        double availableY = size.height - _margin.vertical - childHeight;
        double halfY = availableY / 2;
        y = _margin.top + halfY + (_alignment.y * halfY);
      }

      final BoxParentData childParentData = child!.parentData as BoxParentData;
      childParentData.offset = Offset(x, y);
    }
  }

  // 这里的偏移计算去掉了依赖 context 的 LocalToGlobal，因为自己现在直接等同于主体的尺寸框体
  Offset get _shiftOffset {
    if (_scrollPosition == null ||
        _scrollableBox == null ||
        child == null ||
        !_scrollableBox!.attached ||
        !attached) {
      return Offset.zero;
    }

    final offsetInScrollable =
        localToGlobal(Offset.zero, ancestor: _scrollableBox);
    final containerSize = size;
    final scrollSize = _scrollableBox!.size;

    // 限制最大平移，确保吸附内容仅在主体范围内浮动，不会跑到宿主外
    final double maxShiftY =
        (containerSize.height - child!.size.height - _margin.vertical)
            .clamp(0.0, double.infinity);
    final double maxShiftX =
        (containerSize.width - child!.size.width - _margin.horizontal)
            .clamp(0.0, double.infinity);

    double offsetY = 0.0;
    double offsetX = 0.0;

    // ----- Y轴处理 -----
    if (_alignment.y < 0) {
      if (offsetInScrollable.dy < _viewportPadding.top) {
        double hidden = _viewportPadding.top - offsetInScrollable.dy;
        offsetY = hidden.clamp(0.0, maxShiftY);
      }
    } else if (_alignment.y > 0) {
      double containerBottom = offsetInScrollable.dy + containerSize.height;
      double visibleBottom = scrollSize.height - _viewportPadding.bottom;
      if (containerBottom > visibleBottom) {
        double hidden = containerBottom - visibleBottom;
        offsetY = -hidden.clamp(0.0, maxShiftY);
      }
    }

    // ----- X轴处理 -----
    if (_alignment.x < 0) {
      if (offsetInScrollable.dx < _viewportPadding.left) {
        double hidden = _viewportPadding.left - offsetInScrollable.dx;
        offsetX = hidden.clamp(0.0, maxShiftX);
      }
    } else if (_alignment.x > 0) {
      double containerRight = offsetInScrollable.dx + containerSize.width;
      double visibleRight = scrollSize.width - _viewportPadding.right;
      if (containerRight > visibleRight) {
        double hidden = containerRight - visibleRight;
        offsetX = -hidden.clamp(0.0, maxShiftX);
      }
    }

    return Offset(offsetX, offsetY);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final BoxParentData childParentData = child!.parentData as BoxParentData;
      // 最终实际坐标 = 父节点坐标 + 自身天然居中对齐坐标 + 滚动偏移
      final Offset finalOffset = childParentData.offset + _shiftOffset;
      context.paintChild(child!, offset + finalOffset);
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 允许当子节点宽度超大溢出当前区域时的边界击穿（非必须，兼容极端场景）
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child != null) {
      final BoxParentData childParentData = child!.parentData as BoxParentData;
      final Offset finalOffset = childParentData.offset + _shiftOffset;

      // 解决 Bug 1 的核心：将平移及基础定位同步给 Flutter 底层手势域
      return result.addWithPaintOffset(
        offset: finalOffset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return child!.hitTest(result, position: transformed);
        },
      );
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    // 同步给语义树及复杂手势场景（如 Tooltip 之类的子控件寻找定位）
    final BoxParentData childParentData = child.parentData as BoxParentData;
    final Offset finalOffset = childParentData.offset + _shiftOffset;
    transform.translate(finalOffset.dx, finalOffset.dy);
  }
}
