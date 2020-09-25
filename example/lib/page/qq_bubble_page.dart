import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qq_bubble/widget/qq_bubble.dart';

///
/// Created by fgyong on 2020/9/23.
///
class QQBubblePage extends StatefulWidget {
  QQBubblePage({Key key}) : super(key: key);

  @override
  _QQBubblePageState createState() => _QQBubblePageState();
}

class _QQBubblePageState extends State<QQBubblePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('圈圈'),
      ),
      body: _listView,
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            FlatButton(
              onPressed: _clearRedPoints,
              child: Icon(Icons.clear),
            ),
            FlatButton(
              onPressed: () {
                setState(() {
                  _isdeleteList = _isdeleteList.map((e) => false).toList();
                });
              },
              child: Icon(Icons.refresh),
            )
          ],
          mainAxisAlignment: MainAxisAlignment.spaceAround,
        ),
      ),
    );
  }

  void _clearRedPoints() {
    for (var i = 0; i < _isdeleteList.length; ++i) {
      final key = ValueKey(i);
      dragEventBus.fire(Boom(key));
    }
  }

  List<bool> _isdeleteList;
  Widget get _listView => ListView.builder(
        itemBuilder: (context, index) => ListTile(
          title: _redPointWidget(index),
        ),
        itemCount: 20,
      );
  Widget _redPointWidget(int index) {
    Widget widget = QQBubble(
      deleteCallback: () {
        fresh(index);
      },
      radius: 15,
      boomValue: 10,
      boomKey: ValueKey(index),
      backgroundColor: Colors.primaries[index % Colors.primaries.length],
      textSpan: TextSpan(
          text: '$index', style: TextStyle(fontSize: 20, color: Colors.white)),
      maxMultipleDistance: 10,
    );
    return Container(
      child: _isdeleteList[index] ? Text('已删除message') : widget,
      width: 50,
      height: 70,
      alignment: Alignment.center,
      color: Colors.black12,
      // margin: EdgeInsets.all(0),
    );
  }

  void fresh(int index) {
    setState(() {
      _isdeleteList[index] = true;
    });
  }

  @override
  void initState() {
    _isdeleteList = List(20)..fillRange(0, 20, false);
    super.initState();
  }
}
