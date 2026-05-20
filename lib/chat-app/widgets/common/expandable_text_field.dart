import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';

/// 一个带有焦点感知操作按钮的多行输入框组件。
///
/// 当输入框获得焦点时，会以动画形式在右下角显示“全屏输入”以及其他自定义操作按钮。
class ExpandableTextField extends StatefulWidget {
  /// 文本控制器
  final TextEditingController controller;

  /// 输入框的装饰器，同 TextField.decoration
  final InputDecoration? decoration;

  /// 焦点控制器。如果外部传入，组件将使用外部的；否则，内部自己管理。
  final FocusNode? focusNode;

  /// “全屏输入”按钮的点击回调
  final VoidCallback? onFullScreenTap;

  /// 需要在“全屏输入”按钮右侧额外添加的操作按钮列表
  final List<Widget>? extraActions;

  /// 其他 TextField 支持的参数
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;

  final TextStyle? style;

  const ExpandableTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.focusNode,
    this.onFullScreenTap,
    this.extraActions,
    this.keyboardType = TextInputType.multiline,
    this.minLines = 2,
    // 默认为 null 以实现自适应高度的多行输入
    this.maxLines = 4,
    this.autofocus = false,
    this.style,
  });

  @override
  State<ExpandableTextField> createState() => _ExpandableTextFieldState();
}

class _ExpandableTextFieldState extends State<ExpandableTextField>
    with SingleTickerProviderStateMixin {
  // 内部或外部的焦点控制器
  late final FocusNode _focusNode;
  // 动画控制器，用于控制按钮的显示和隐藏动画
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  // 标记是否由本组件内部创建 FocusNode
  bool _isInternalFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // 使用 CurvedAnimation 让动画曲线更自然
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );

    // 判断是使用外部传入的 FocusNode 还是内部创建一个
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }

    // 添加焦点监听
    _focusNode.addListener(_onFocusChange);

    // 检查初始焦点状态
    _isFocused = _focusNode.hasFocus;
    if (_isFocused) {
      _animationController.value = 1.0; // 如果初始就有焦点，直接显示
    }
  }

  void _onFocusChange() {
    // 只有当组件还挂载在树上时才更新状态
    if (mounted) {
      if (_focusNode.hasFocus) {
        // 获得焦点，正向播放动画
        _animationController.forward();
      } else {
        // 失去焦点，反向播放动画
        _animationController.reverse();
      }
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ExpandableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部传入的 focusNode 发生变化时，需要更新监听
    if (widget.focusNode != oldWidget.focusNode) {
      // 移除旧的监听
      oldWidget.focusNode?.removeListener(_onFocusChange);
      // 如果之前是内部的，需要销毁
      if (_isInternalFocusNode) {
        _focusNode.dispose();
      }

      // 设置新的 FocusNode
      if (widget.focusNode == null) {
        _focusNode = FocusNode();
        _isInternalFocusNode = true;
      } else {
        _focusNode = widget.focusNode!;
        _isInternalFocusNode = false;
      }
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    // 移除监听
    _focusNode.removeListener(_onFocusChange);
    // 如果 FocusNode 是在组件内部创建的，则需要手动销毁
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
    // 销毁动画控制器
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 输入框主体
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: widget.decoration,
          keyboardType: widget.keyboardType,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          autofocus: widget.autofocus,
          style: widget.style,
        ),
        // 带动画的操作按钮区域
        // SizeTransition 和 FadeTransition 结合，实现平滑的尺寸和透明度变化
        SizeTransition(
          sizeFactor: _animation,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: _animation,
            child: Padding(
              // 微调内边距，使其看起来更舒适
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // “全屏输入”按钮

                  buildIconTextButton(
                    context,
                    text: '全屏输入',
                    icon: Icons.fullscreen,
                    onPressed: () {
                      customNavigate(
                          _FullscreenEditorPage(controller: widget.controller),
                          context: context);
                    },
                  ),

                  // 额外的自定义操作按钮
                  if (widget.extraActions != null) ...widget.extraActions!,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 内部封装一个样式统一且更美观紧凑的文本+图标按钮
Widget buildIconTextButton(BuildContext context,
    {required String text, required IconData icon, VoidCallback? onPressed}) {
  return TextButton.icon(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.transparent,
    ),
    icon: Icon(
      icon,
      color: Theme.of(context).colorScheme.primary,
      size: 18,
    ),
    label: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
    onPressed: onPressed,
  );
}

/// 全屏输入页面
class _FullscreenEditorPage extends StatelessWidget {
  final TextEditingController controller;

  const _FullscreenEditorPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全屏编辑'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '在这里输入内容...',
          ),
          keyboardType: TextInputType.multiline,
        ),
      ),
    );
  }
}
