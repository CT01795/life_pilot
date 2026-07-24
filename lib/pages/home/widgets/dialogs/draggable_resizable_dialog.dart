import 'package:flutter/material.dart';

class DraggableResizableDialog extends StatefulWidget {
  final String title;
  final Widget child;

  const DraggableResizableDialog({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  State<DraggableResizableDialog> createState() =>
      _DraggableResizableDialogState();
}

class _DraggableResizableDialogState
    extends State<DraggableResizableDialog> {
  double? width;
  double? height;
  double? top;
  double? left;

  bool initialized = false;

  bool isMaximized = false;

  // 記錄最大化前的位置尺寸
  double? oldWidth;
  double? oldHeight;
  double? oldTop;
  double? oldLeft;

  void toggleMaximize(Size screenSize) {
    setState(() {
      if (isMaximized) {
        // 還原
        width = oldWidth;
        height = oldHeight;
        top = oldTop;
        left = oldLeft;
        isMaximized = false;
      } else {
        // 保存目前狀態
        oldWidth = width;
        oldHeight = height;
        oldTop = top;
        oldLeft = left;
        // 最大化
        width = screenSize.width;
        height = screenSize.height;
        top = 0;
        left = 0;
        isMaximized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    if (!initialized) {
      width = screenSize.width * 0.66;
      height = screenSize.height * 0.8;
      top = 50;
      left = screenSize.width * 0.33;

      initialized = true;
    }
    return Stack(
      children: [
        // 背景透明區，點擊關閉
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Container(
            color: Colors.black.withValues(alpha: 0.02),
          ),
        ),

        // 可拖動視窗
        Positioned(
          top: top!,
          left: left!,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow:[
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                )
              ],
            ),
            child: Column(
              children: [
                // Header
                MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        top = top! + details.delta.dy;
                        left = left! + details.delta.dx;

                        // 防止拖出畫面
                        if (top! < 0) {
                          top = 0;
                        }

                        if (left! < 0) {
                          left = 0;
                        }

                        if (height! < screenSize.height) {
                          if (top! + height! > screenSize.height) {
                            top = screenSize.height - height!;
                          }
                        }

                        if (width! < screenSize.width) {
                          if (left! + width! > screenSize.width) {
                            left = screenSize.width - width!;
                          }
                        }
                      });
                    },

                    child: Container(
                      height:40,
                      padding:
                      const EdgeInsets.symmetric(horizontal:8),
                      decoration: const BoxDecoration(
                        color:Colors.blue,
                        borderRadius:
                        BorderRadius.vertical(
                          top:Radius.circular(12),
                        ),
                      ),
                      child:Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children:[
                          Text(
                            widget.title,
                            style:const TextStyle(
                              color:Colors.white,
                              fontWeight:FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children:[
                              IconButton(
                                icon: Icon(
                                  isMaximized
                                      ? Icons.close_fullscreen
                                      : Icons.fullscreen,
                                  color: Colors.white,
                                ),
                                onPressed: (){
                                  toggleMaximize(screenSize);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: (){
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Body
                Expanded(
                  child:Stack(
                    children:[
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRect(
                          child: widget.child,
                        ),
                      ),
                      // resize handle
                      Positioned(
                        right:8,
                        bottom:8,
                        child:GestureDetector(
                          onPanUpdate:(details){
                            setState((){
                              width = width! + details.delta.dx;
                              height = height! + details.delta.dy;
                              // 最小尺寸
                              if(width! < 350){
                                width = 350;
                              }
                              if(height! < 250){
                                height = 250;
                              }
                              // 最大尺寸
                              if(width! > screenSize.width){
                                width = screenSize.width;
                              }
                              if(height! > screenSize.height){
                                height = screenSize.height;
                              }
                            });
                          },
                          child:Container(
                            width:30,
                            height:30,
                            decoration:BoxDecoration(
                              color:Colors.blue,
                              borderRadius:
                              BorderRadius.circular(4),
                            ),
                            child:
                            const Icon(
                              Icons.drag_handle,
                              size:16,
                              color:Colors.white,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}