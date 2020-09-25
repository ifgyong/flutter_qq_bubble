import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qq_bubble/flutter_qq_bubble.dart';
import 'package:flutter_qq_bubble/widget/drag_direction_gestureRecognizer.dart';
import 'painter.dart';

///
/// Created by fgyong on 2020/9/23.
///

class QQBubble extends StatefulWidget {
  /// 球之间断开连接的最大距离，基数是球的半径[radius],默认是[五倍]半径
  final double maxMultipleDistance;

  /// 拖拽删除回调
  final GestureTapCallback deleteCallback;

  /// 球半径，默认是[10]
  final double radius;

  /// 中间显示文本
  final InlineSpan textSpan;

  /// 爆炸倍数基于[radius],默认5倍,范围[1,100]
  final double boomValue;

  /// 使用eventbus销毁的key
  final ValueKey boomKey;

  /// 背景颜色
  final Color backgroundColor;
  QQBubble(
      {Key key,
      this.maxMultipleDistance = 5,
      this.radius = 10,
      this.deleteCallback,
      this.textSpan,
      this.backgroundColor,
      this.boomValue = 5,
      this.boomKey})
      : assert(boomValue >= 1 && boomValue <= 100);

  @override
  State<StatefulWidget> createState() => _QQBubbleState();
}

double minRadiusMutiple = 0.33;
final EventBus qqEventBus = EventBus();

class _QQBubbleState extends State<QQBubble>
    with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  Offset _offsetEnd = Offset.zero;

  Offset _myFirstOffset = Offset.zero;
  DragState _dragState;
  bool _isFinishDrag;

  bool _playGIfEnd = false, _needPlayGIf = false;
  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedBuilder(
      animation: _animationController,
      key: ValueKey(0),
      child: CustomPaint(
        painter: QQBubbleCustomPainter(
            offset: _offset,
            radius: widget.radius,
            dragState: _dragState,
            textSpan: widget.textSpan,
            bgColor: widget.backgroundColor,
            maxMultipleDistance: widget.maxMultipleDistance),

        // size: Size(radius, radius),
      ),
      builder: (context, child) {
        double radius = widget.radius;
        if (_dragState == DragState.end) {
          _offset = _offset * _offsetAnimation.value;
        }
        Matrix4 matrix4 = Matrix4.identity();
        if (_translateAnimation.value != 0) {
          matrix4.translate(sinz * sin(_translateAnimation.value) * radius * 1,
              cosz * sin(_translateAnimation.value) * radius * 1, 0);
        }
        return Transform(
          child: CustomPaint(
            painter: QQBubbleCustomPainter(
                offset: _offset,
                radius: radius,
                dragState: _dragState,
                textSpan: widget.textSpan,
                bgColor: widget.backgroundColor,
                maxMultipleDistance: widget.maxMultipleDistance),
            // size: Size(radius, radius),
          ),
          alignment: Alignment.center,
          transform: matrix4,
        );
      },
    );

    return _playGIfEnd == false && _needPlayGIf == true
        ? _gifWidget()
        : RawGestureDetector(
            gestures: _contentGestures,
            child: Container(
              child: child,
              width: widget.radius * 2,
              height: widget.radius * 2,
            ),
            behavior: HitTestBehavior.deferToChild,
          );
  }

  Map<Type, GestureRecognizerFactory> _contentGestures;

  // ignore: cancel_subscriptions
  StreamSubscription _subscription;
  void initGestures() {
    _contentGestures = {
      DirectionGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<DirectionGestureRecognizer>(
              () => DirectionGestureRecognizer(DirectionGestureRecognizer.all),
              (instance) {
        instance.onDown = (v) {
          _touchDown(v.globalPosition);
        };
        instance.onStart = (v) {
          _touchDown(v.globalPosition);
        };
        instance.onUpdate = (v) {
          _touchMove(v.globalPosition);
        };
        instance.onCancel = _onPanCancel;
        instance.onEnd = (v) {
          _onPanCancel();
        };
      }),
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(), (instance) {
        instance.onTap = _onTap;
      })
    };
  }

  Widget _gifWidget() => Container(
        child: Image.asset(
          'assets/qq.gif',
          color: widget.backgroundColor,
          colorBlendMode: BlendMode.srcIn,
          width: widget.radius * widget.boomValue,
          height: widget.radius * widget.boomValue,
        ),
        transform: Matrix4.identity()..translate(_offset.dx, _offset.dy, 0),
      );
  void setupData() {
    _offset = Offset.zero;
  }

  /// 直接播放 销毁动画
  void playGIfToEnd() {
    if (mounted)
      setState(() {
        _playGIfEnd = false;
        _needPlayGIf = true;
      });
    _deleteBoomAndRunCallback();
  }

  void _touchMove(Offset v) {
    if (mounted)
      setState(() {
        if (value(_offset) <= minRadiusMutiple) {
          _dragState = DragState.moveCut;
          _isFinishDrag = true;
        } else if (_isFinishDrag == false) {
          _dragState = DragState.move;
        }

        _offset = Offset(v.dx - _myFirstOffset.dx, v.dy - _myFirstOffset.dy);
      });
  }

  void _touchDown(Offset offset) {
    _myFirstOffset = offset;
    _dragState = DragState.move;
  }

  Future<void> _onPanCancel() {
    _offsetEnd = _offset;
    if (mounted)
      setState(() {
        if (_dragState == DragState.moveCut) {
          _dragState = DragState.endCut;
        } else {
          _dragState = DragState.end;
        }
      });
    if (_dragState == DragState.endCut) {
      /// 不需要删除动画
      if (value(_offsetEnd) > minRadiusMutiple) {
        _offset = Offset.zero;
        _needPlayGIf = false;
      } else {
        _playGIfEnd = false;
        _needPlayGIf = true;

        if (mounted)

          /// 需要删除动画
          setState(() {});

        _deleteBoomAndRunCallback();
      }
    } else if (_dragState == DragState.end) {
      if (value(_offsetEnd) > minRadiusMutiple) {
        _isFinishDrag = false;
        _animationController..reverse(from: 1.0);
      }
    }
  }

  void _deleteBoomAndRunCallback() {
    Future.delayed(Duration(milliseconds: 500)).then((value) {
      if (mounted)
        setState(() {
          _playGIfEnd = true;
          _offset = Offset.zero;
        });
      if (widget.deleteCallback != null) {
        widget.deleteCallback();
      }
    });
  }

  void _onTap() {
    _playGIfEnd = false;
    _needPlayGIf = true;
    if (mounted)

      /// 需要删除动画
      setState(() {});

    Future.delayed(Duration(milliseconds: 500)).then((value) {
      if (mounted)
        setState(() {
          _playGIfEnd = true;
          _offset = Offset.zero;
        });
      if (widget.deleteCallback != null) {
        widget.deleteCallback();
      }
    });
  }

  /// 根据距离计算半径比例
  double value(Offset offset) {
    var ret = sqrt(offset.dx * offset.dx + offset.dy * offset.dy);
    ret /= widget.radius;
    if (ret < 2.0)
      return 1.0;
    else if (ret >= 2.0 && ret <= widget.maxMultipleDistance) {
      return (widget.maxMultipleDistance - 2 - (ret - 2.0)) /
              (widget.maxMultipleDistance - 2) *
              0.67 +
          minRadiusMutiple;
    } else {
      return minRadiusMutiple;
    }
  }

  AnimationController _animationController;
  Animation<double> _translateAnimation;
  Animation<double> _offsetAnimation;

  @override
  void initState() {
    _dragState = DragState.move;
    _subscription = qqEventBus.on<Boom>().listen((event) {
      if (event.key.value == widget.boomKey.value) {
        playGIfToEnd();
      }
    });
    initGestures();
    _animationController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300),
        lowerBound: 0.0,
        upperBound: 1.0)
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && _isFinishDrag == true) {}
      });

    _translateAnimation = Tween<double>(begin: .0, end: pi * 2).animate(
        CurvedAnimation(
            parent: _animationController,
            curve: Curves.linear,
            reverseCurve: Interval(0.0, 0.4, curve: Curves.linear)));

    _offsetAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _animationController,
            curve: Curves.bounceOut,
            reverseCurve: Interval(0.4, 1.0, curve: Curves.easeInCubic)));

    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subscription.cancel();
    super.dispose();
  }

  double get dLength =>
      sqrt(_offsetEnd.dx * _offsetEnd.dx + _offsetEnd.dy * _offsetEnd.dy);

  /// 角度
  double get sinz {
    var z = dLength;
    if (z == 0) return double.infinity;
    final sinz = _offsetEnd.dx / z; // asin(offset.dy / z);
    return sinz;
  }

  /// 角度
  double get cosz {
    var z = dLength;
    if (z == 0) return double.infinity;

    final cz = _offsetEnd.dy / z; // asin(offset.dy / z);
    return cz;
  }
}

/// 销毁 红点
class Boom {
  final ValueKey key;

  Boom(this.key);
}
