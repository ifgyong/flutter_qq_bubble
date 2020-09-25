import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

enum DragState { move, moveCut, end, endCut }
double _minRadiusMutiple = 0.33;
final EventBus dragEventBus = EventBus();

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
        painter: _CustomPainter(
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
            painter: _CustomPainter(
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
        if (value(_offset) <= _minRadiusMutiple) {
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
      if (value(_offsetEnd) > _minRadiusMutiple) {
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
      if (value(_offsetEnd) > _minRadiusMutiple) {
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
          _minRadiusMutiple;
    } else {
      return _minRadiusMutiple;
    }
  }

  AnimationController _animationController;
  Animation<double> _translateAnimation;
  Animation<double> _offsetAnimation;

  @override
  void initState() {
    _dragState = DragState.move;
    _subscription = dragEventBus.on<Boom>().listen((event) {
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

class _CustomPainter extends CustomPainter {
  Offset offset;
  Path _path;
  Paint _paint;
  TextPainter _textPainter;
  final DragState dragState;
  final TextSpan textSpan;

  final Color bgColor;
  bool _outBounds;

  /// 球之间断开连接的最大距离，基数是球的半径[radius]
  final double maxMultipleDistance;

  double radius;
  _CustomPainter(
      {this.offset = Offset.zero,
      this.radius = 20,
      this.dragState = DragState.move,
      this.maxMultipleDistance = 5.0,
      this.textSpan,
      this.bgColor = Colors.red})
      : assert(maxMultipleDistance > 2.0);

  @override
  void paint(Canvas canvas, Size size) {
    _path ??= Path();
    _paint ??= Paint()
      ..strokeWidth = 5.0
      ..style = PaintingStyle.fill
      ..color = bgColor ?? Colors.red;
    _textPainter ??= TextPainter(
        text: textSpan == null
            ? TextSpan(
                text: '99+',
                style: TextStyle(fontSize: radius / 1.5, color: Colors.white))
            : textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1);

    Offset _c1 = Offset(size.width / 2, size.height / 2);
    Offset _c2 =
        Offset(size.width / 2 + offset.dx, size.height / 2 + offset.dy);
    Rect nextRect = Rect.fromCircle(center: _c2, radius: radius);
    if (dragState == DragState.end || dragState == DragState.endCut) {
      if (_outBounds == true) {
        _path.addArc(nextRect, 0, pi * 2);
      } else {
        _path.addArc(
            Rect.fromCircle(center: _c1, radius: radius * value), 0, pi * 2);
        if (offset.dx != 0 && offset.dy != 0) {
          _path.addArc(nextRect, 0, pi * 2);
        }
      }
      canvas.drawPath(_path, _paint);
      if (dragState == DragState.end) {
        drawBezier(c1: _c1, c2: _c2, canvas: canvas);
      }
    } else if (dragState == DragState.move) {
      if (value > _minRadiusMutiple) {
        _outBounds = false;
        _path.addArc(
            Rect.fromCircle(center: _c1, radius: radius * value), 0, pi * 2);
      } else {
        _outBounds = true;
      }
      _path.addArc(nextRect, 0, pi * 2);
      canvas.drawPath(_path, _paint);

      /// 当两个圆心距离大于radius则开始绘画bezier
      if (dLength > radius) {
        drawBezier(c1: _c1, c2: _c2, canvas: canvas);
      }
    } else if (dragState == DragState.moveCut) {
      _path.addArc(nextRect, 0, pi * 2);
      canvas.drawPath(_path, _paint);
    }

    /// 绘画textpainter
    _textPainter.layout();
    _textPainter.paint(
        canvas,
        Offset(
            _c2.dx - _textPainter.width / 2, _c2.dy - _textPainter.height / 2));
  }

  void drawBezier({Offset c1, Offset c2, Canvas canvas}) {
    if (value <= _minRadiusMutiple) return;
    double centerCircleY = c1.dy;
    double dragCircleY = c2.dy;
    double centerCircleX = c1.dx;
    double dragCircleX = c2.dx,
        dragRadius = radius,
        centerRadius = radius * value;

    double controlX = (c1.dx + c2.dx) / 2;
    double controlY = (c2.dy + c1.dy) / 2;
    double d = sqrt(offset.dx * offset.dx + offset.dy * offset.dy);
    double sin = (centerCircleY - dragCircleY) / d;
    double cos = (centerCircleX - dragCircleX) / d;
    double dragCircleStartX = dragCircleX - dragRadius * sin;
    double dragCircleStartY = dragCircleY + dragRadius * cos;
    double centerCircleEndX = centerCircleX - centerRadius * sin;
    double centerCircleEndY = centerCircleY + centerRadius * cos;
    double centerCircleStartX = centerCircleX + centerRadius * sin;
    double centerCircleStartY = centerCircleY - centerRadius * cos;
    double dragCircleEndX = dragCircleX + dragRadius * sin;
    double dragCircleEndY = dragCircleY - dragRadius * cos;

    _path.reset();
    _path.moveTo(centerCircleStartX, centerCircleStartY);

    _path.quadraticBezierTo(controlX, controlY, dragCircleEndX, dragCircleEndY);
    _path.lineTo(dragCircleStartX, dragCircleStartY);
    _path.quadraticBezierTo(
        controlX, controlY, centerCircleEndX, centerCircleEndY);
    _path.close();
    canvas.drawPath(_path, _paint);
  }

  /// 角度
  double get sinz {
    var z = dLength;
    final sinz = offset.dx / z; // asin(offset.dy / z);
    return sinz;
  }

  /// 角度
  double get cosz {
    var z = dLength;
    final cz = offset.dy / z; // asin(offset.dy / z);
    return cz;
  }

  /// 根据距离计算半径比例
  double get value {
    double ret = dLength;
    ret /= radius;
    if (ret < 2.0)
      return 1.0;
    else if (ret >= 2.0 && ret <= this.maxMultipleDistance) {
      return (maxMultipleDistance - 2 - (ret - 2.0)) /
              (maxMultipleDistance - 2) *
              0.67 +
          _minRadiusMutiple;
    } else {
      return _minRadiusMutiple;
    }
  }

  double get dLength => sqrt(offset.dx * offset.dx + offset.dy * offset.dy);

  @override
  bool shouldRepaint(_CustomPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.dragState != dragState;
  }
}

/// 销毁 红点
class Boom {
  final ValueKey key;

  Boom(this.key);
}

enum _DragState {
  ready,
  possible,
  accepted,
}

abstract class _DragGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Initialize the object.
  _DragGestureRecognizer({Object debugOwner}) : super(debugOwner: debugOwner);

  /// A pointer has contacted the screen and might begin to move.
  ///
  /// The position of the pointer is provided in the callback's `details`
  /// argument, which is a [DragDownDetails] object.
  GestureDragDownCallback onDown;

  /// A pointer has contacted the screen and has begun to move.
  ///
  /// The position of the pointer is provided in the callback's `details`
  /// argument, which is a [DragStartDetails] object.
  GestureDragStartCallback onStart;

  /// A pointer that is in contact with the screen and moving has moved again.
  ///
  /// The distance travelled by the pointer since the last update is provided in
  /// the callback's `details` argument, which is a [DragUpdateDetails] object.
  GestureDragUpdateCallback onUpdate;

  /// A pointer that was previously in contact with the screen and moving is no
  /// longer in contact with the screen and was moving at a specific velocity
  /// when it stopped contacting the screen.
  ///
  /// The velocity is provided in the callback's `details` argument, which is a
  /// [DragEndDetails] object.
  GestureDragEndCallback onEnd;

  /// The pointer that previously triggered [onDown] did not complete.
  GestureDragCancelCallback onCancel;

  /// The minimum distance an input pointer drag must have moved to
  /// to be considered a fling gesture.
  ///
  /// This value is typically compared with the distance traveled along the
  /// scrolling axis. If null then [kTouchSlop] is used.
  double minFlingDistance;

  /// The minimum velocity for an input pointer drag to be considered fling.
  ///
  /// This value is typically compared with the magnitude of fling gesture's
  /// velocity along the scrolling axis. If null then [kMinFlingVelocity]
  /// is used.
  double minFlingVelocity;

  /// Fling velocity magnitudes will be clamped to this value.
  ///
  /// If null then [kMaxFlingVelocity] is used.
  double maxFlingVelocity;

  _DragState _state = _DragState.ready;
  Offset _initialPosition;
  Offset _pendingDragOffset;
  Duration _lastPendingEventTimestamp;

  bool _isFlingGesture(VelocityEstimate estimate);

  Offset _getDeltaForDetails(Offset delta);

  double _getPrimaryValueFromOffset(Offset value);

  bool get _hasSufficientPendingDragDeltaToAccept;

  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};

  @override
  void addPointer(PointerEvent event) {
    startTrackingPointer(event.pointer);
    _velocityTrackers[event.pointer] = VelocityTracker();
    if (_state == _DragState.ready) {
      _state = _DragState.possible;
      _initialPosition = event.position;
      _pendingDragOffset = Offset.zero;
      _lastPendingEventTimestamp = event.timeStamp;
      if (onDown != null)
        invokeCallback<void>('onDown',
            () => onDown(DragDownDetails(globalPosition: _initialPosition)));
    } else if (_state == _DragState.accepted) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _DragState.ready);
    if (!event.synthesized &&
        (event is PointerDownEvent || event is PointerMoveEvent)) {
      final VelocityTracker tracker = _velocityTrackers[event.pointer];
      assert(tracker != null);
      tracker.addPosition(event.timeStamp, event.position);
    }

    if (event is PointerMoveEvent) {
      final Offset delta = event.delta;
      if (_state == _DragState.accepted) {
        if (onUpdate != null) {
          invokeCallback<void>(
              'onUpdate',
              () => onUpdate(DragUpdateDetails(
                    sourceTimeStamp: event.timeStamp,
                    delta: _getDeltaForDetails(delta),
                    primaryDelta: _getPrimaryValueFromOffset(delta),
                    globalPosition: event.position,
                  )));
        }
      } else {
        _pendingDragOffset += delta;
        _lastPendingEventTimestamp = event.timeStamp;
        if (_hasSufficientPendingDragDeltaToAccept)
          resolve(GestureDisposition.accepted);
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {
    if (_state != _DragState.accepted) {
      _state = _DragState.accepted;
      final Offset delta = _pendingDragOffset;
      final Duration timestamp = _lastPendingEventTimestamp;
      _pendingDragOffset = Offset.zero;
      _lastPendingEventTimestamp = null;
      if (onStart != null) {
        invokeCallback<void>(
            'onStart',
            () => onStart(DragStartDetails(
                  sourceTimeStamp: timestamp,
                  globalPosition: _initialPosition,
                )));
      }
      if (delta != Offset.zero && onUpdate != null) {
        final Offset deltaForDetails = _getDeltaForDetails(delta);
        invokeCallback<void>(
            'onUpdate',
            () => onUpdate(DragUpdateDetails(
                  sourceTimeStamp: timestamp,
                  delta: deltaForDetails,
                  primaryDelta: _getPrimaryValueFromOffset(delta),
                  globalPosition: _initialPosition + deltaForDetails,
                )));
      }
    }
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (_state == _DragState.possible) {
      resolve(GestureDisposition.rejected);
      _state = _DragState.ready;
      if (onCancel != null) invokeCallback<void>('onCancel', onCancel);
      return;
    }
    final bool wasAccepted = _state == _DragState.accepted;
    _state = _DragState.ready;
    if (wasAccepted && onEnd != null) {
      final VelocityTracker tracker = _velocityTrackers[pointer];
      assert(tracker != null);

      final VelocityEstimate estimate = tracker.getVelocityEstimate();
      if (estimate != null && _isFlingGesture(estimate)) {
        final Velocity velocity =
            Velocity(pixelsPerSecond: estimate.pixelsPerSecond).clampMagnitude(
                minFlingVelocity ?? kMinFlingVelocity,
                maxFlingVelocity ?? kMaxFlingVelocity);
        invokeCallback<void>(
            'onEnd',
            () => onEnd(DragEndDetails(
                  velocity: velocity,
                  primaryVelocity:
                      _getPrimaryValueFromOffset(velocity.pixelsPerSecond),
                )), debugReport: () {
          return '$estimate; fling at $velocity.';
        });
      } else {
        invokeCallback<void>(
            'onEnd',
            () => onEnd(DragEndDetails(
                  velocity: Velocity.zero,
                  primaryVelocity: 0.0,
                )), debugReport: () {
          if (estimate == null) return 'Could not estimate velocity.';
          return '$estimate; judged to not be a fling.';
        });
      }
    }
    _velocityTrackers.clear();
  }

  @override
  void dispose() {
    _velocityTrackers.clear();
    super.dispose();
  }
}

typedef ChangeGestureDirection = int Function();

class DirectionGestureRecognizer extends _DragGestureRecognizer {
  int direction;

  ChangeGestureDirection changeGestureDirection;

  static int left = 1 << 1;
  static int right = 1 << 2;
  static int up = 1 << 3;
  static int down = 1 << 4;
  static int all = left | right | up | down;

  DirectionGestureRecognizer(this.direction, {Object debugOwner})
      : super(debugOwner: debugOwner);

  @override
  bool _isFlingGesture(VelocityEstimate estimate) {
    if (changeGestureDirection != null) {
      direction = changeGestureDirection();
    }
    final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    final double minDistance = minFlingDistance ?? kTouchSlop;
    if (_hasAll) {
      return estimate.pixelsPerSecond.distanceSquared > minVelocity &&
          estimate.offset.distanceSquared > minDistance;
    } else {
      bool result = false;
      if (_hasVertical) {
        result |= estimate.pixelsPerSecond.dy.abs() > minVelocity &&
            estimate.offset.dy.abs() > minDistance;
      }
      if (_hasHorizontal) {
        result |= estimate.pixelsPerSecond.dx.abs() > minVelocity &&
            estimate.offset.dx.abs() > minDistance;
      }
      return result;
    }
  }

  bool get _hasLeft => _has(DirectionGestureRecognizer.left);

  bool get _hasRight => _has(DirectionGestureRecognizer.right);

  bool get _hasUp => _has(DirectionGestureRecognizer.up);

  bool get _hasDown => _has(DirectionGestureRecognizer.down);
  bool get _hasHorizontal => _hasLeft || _hasRight;
  bool get _hasVertical => _hasUp || _hasDown;

  bool get _hasAll => _hasLeft && _hasRight && _hasUp && _hasDown;

  bool _has(int flag) {
    return (direction & flag) != 0;
  }

  @override
  bool get _hasSufficientPendingDragDeltaToAccept {
    if (changeGestureDirection != null) {
      direction = changeGestureDirection();
    }
    // if (_hasAll) {
    //   return _pendingDragOffset.distance > kPanSlop;
    // }
    bool result = false;
    if (_hasUp) {
      result |= _pendingDragOffset.dy < -kTouchSlop;
    }
    if (_hasDown) {
      result |= _pendingDragOffset.dy > kTouchSlop;
    }
    if (_hasLeft) {
      result |= _pendingDragOffset.dx < -kTouchSlop;
    }
    if (_hasRight) {
      result |= _pendingDragOffset.dx > kTouchSlop;
    }
    return result;
  }

  @override
  Offset _getDeltaForDetails(Offset delta) {
    if (_hasAll || (_hasVertical && _hasHorizontal)) {
      return delta;
    }

    double dx = delta.dx;
    double dy = delta.dy;

    if (_hasVertical) {
      dx = 0;
    }
    if (_hasHorizontal) {
      dy = 0;
    }
    Offset offset = Offset(dx, dy);
    return offset;
  }

  @override
  double _getPrimaryValueFromOffset(Offset value) {
    return null;
  }

  @override
  String get debugDescription => 'orientation_' + direction.toString();
}

class IgnorePanGestureRecognizer extends _DragGestureRecognizer {
  final int ignoreDirection;

  static int left = 1;
  static int right = 2;
  static int up = 3;
  static int down = 4;

  IgnorePanGestureRecognizer(this.ignoreDirection, {Object debugOwner})
      : super(debugOwner: debugOwner);

  @override
  bool _isFlingGesture(VelocityEstimate estimate) {
    final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    final double minDistance = minFlingDistance ?? kTouchSlop;
    return estimate.pixelsPerSecond.distanceSquared >
            minVelocity * minVelocity &&
        estimate.offset.distanceSquared > minDistance * minDistance;
  }

  @override
  bool get _hasSufficientPendingDragDeltaToAccept {
    bool ignore = false;
    if (ignoreDirection == left) {
      ignore = _pendingDragOffset.dx <= -kTouchSlop;
    } else if (ignoreDirection == right) {
      ignore = _pendingDragOffset.dx >= kTouchSlop;
    } else if (ignoreDirection == up) {
      ignore = _pendingDragOffset.dy <= -kTouchSlop;
    } else if (ignoreDirection == down) {
      ignore = _pendingDragOffset.dy >= kTouchSlop;
    }
    return !ignore && _pendingDragOffset.distance > kPanSlop;
  }

  @override
  Offset _getDeltaForDetails(Offset delta) => delta;

  @override
  double _getPrimaryValueFromOffset(Offset value) => null;

  @override
  String get debugDescription => 'pan';
}

class DragDirectionGestureRecognizer extends _DragGestureRecognizer {
  int direction;
  //接受中途变动
  ChangeGestureDirection changeGestureDirection;
  //不同方向
  static int left = 1 << 1;
  static int right = 1 << 2;
  static int up = 1 << 3;
  static int down = 1 << 4;
  static int all = left | right | up | down;

  DragDirectionGestureRecognizer(this.direction, {Object debugOwner})
      : super(debugOwner: debugOwner);

  @override
  bool _isFlingGesture(VelocityEstimate estimate) {
    if (changeGestureDirection != null) {
      direction = changeGestureDirection();
    }
    final double minVelocity = kMinFlingVelocity ?? kMinFlingVelocity;
    final double minDistance = minFlingDistance ?? kTouchSlop;
    if (_hasAll) {
      return estimate.pixelsPerSecond.distanceSquared > minVelocity &&
          estimate.offset.distanceSquared > minDistance;
    } else {
      bool result = false;
      if (_hasVertical) {
        result |= estimate.pixelsPerSecond.dy.abs() > minVelocity &&
            estimate.offset.dy.abs() > minDistance;
      }
      if (_hasHorizontal) {
        result |= estimate.pixelsPerSecond.dx.abs() > minVelocity &&
            estimate.offset.dx.abs() > minDistance;
      }
      return result;
    }
  }

  bool get _hasLeft => _has(DirectionGestureRecognizer.left);

  bool get _hasRight => _has(DirectionGestureRecognizer.right);

  bool get _hasUp => _has(DirectionGestureRecognizer.up);

  bool get _hasDown => _has(DirectionGestureRecognizer.down);
  bool get _hasHorizontal => _hasLeft || _hasRight;
  bool get _hasVertical => _hasUp || _hasDown;

  bool get _hasAll => _hasLeft && _hasRight && _hasUp && _hasDown;

  bool _has(int flag) {
    return (direction & flag) != 0;
  }

  @override
  bool get _hasSufficientPendingDragDeltaToAccept {
    if (changeGestureDirection != null) {
      direction = changeGestureDirection();
    }

    bool result = false;
    if (_hasUp) {
      result |= _pendingDragOffset.dy < -kTouchSlop;
    }
    if (_hasDown) {
      result |= _pendingDragOffset.dy > kTouchSlop;
    }
    if (_hasLeft) {
      result |= _pendingDragOffset.dx < -kTouchSlop;
    }
    if (_hasRight) {
      result |= _pendingDragOffset.dx > kTouchSlop;
    }
    return result;
  }

  @override
  Offset _getDeltaForDetails(Offset delta) {
    if (_hasAll || (_hasVertical && _hasHorizontal)) {
      return delta;
    }

    double dx = delta.dx;
    double dy = delta.dy;

    if (_hasVertical) {
      dx = 0;
    }
    if (_hasHorizontal) {
      dy = 0;
    }
    Offset offset = Offset(dx, dy);
    return offset;
  }

  @override
  double _getPrimaryValueFromOffset(Offset value) {
    return null;
  }

  @override
  String get debugDescription => 'orientation_' + direction.toString();
}
