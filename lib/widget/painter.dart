import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'qq_bubble.dart';

///
/// Created by fgyong on 2020/9/25.
///

enum DragState { move, moveCut, end, endCut }

class QQBubbleCustomPainter extends CustomPainter {
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
  QQBubbleCustomPainter(
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
      if (value > minRadiusMutiple) {
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
    if (value <= minRadiusMutiple) return;
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
          minRadiusMutiple;
    } else {
      return minRadiusMutiple;
    }
  }

  double get dLength => sqrt(offset.dx * offset.dx + offset.dy * offset.dy);

  @override
  bool shouldRepaint(QQBubbleCustomPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.dragState != dragState;
  }
}
