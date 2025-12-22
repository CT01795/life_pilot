import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/pages/page_point_record_detail.dart';
import 'package:life_pilot/services/service_point_record.dart';
import 'package:provider/provider.dart';

class PagePointRecord extends StatefulWidget {
  const PagePointRecord({super.key});

  @override
  State<PagePointRecord> createState() => _PagePointRecordState();
}

class _PagePointRecordState extends State<PagePointRecord> {
  late final ControllerPointRecordAccount controller;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return; // 避免重複初始化
    controller = context.read<ControllerPointRecordAccount>();
    _loadAccountsAsync();
    _isInitialized = true;
  }

  Future<void> _loadAccountsAsync() async {
    await controller.loadAccounts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    return Scaffold(
      body: Consumer<ControllerPointRecordAccount>(
        builder: (context, controller, _) {
          final accounts = controller.accounts; // 先取目前資料
          if (accounts.isEmpty) {
            // 資料還沒載入，先顯示 loading
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                color: Colors.grey[50], // 卡片背景淺灰
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagePointRecordDetail(
                          service: context.read<ServicePointRecord>(),
                          accountId: account.id,
                          accountName: account.accountName,
                        ),
                      ),
                    );
                    if (result == true) {
                      await controller.loadAccounts();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 圖片
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(
                                source: ImageSource.gallery);
                            if (pickedFile != null) {
                              await controller.updateAccountImage(
                                  account.id, pickedFile);
                            }
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16), // 圓角大小
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  // 先顯示文字或占位背景
                                  Container(
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: Text(
                                      account.accountName[0],
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                  // 如果有圖片，慢慢載入
                                  if (account.masterGraphUrl != null)
                                    FutureBuilder<Uint8List>(
                                      future: Future.value(account.masterGraphUrl), // 假裝延遲
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.done &&
                                            snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            gaplessPlayback: true,
                                          );
                                        } else {
                                          return const SizedBox.shrink(); // 等圖片到，不會遮住文字
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Gaps.w16,
                        // 文字資訊
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 帳戶名稱
                              Text(
                                account.accountName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF212121), // 深灰
                                ),
                              ),
                              Gaps.h4,
                              // Points
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Points ',
                                      style: TextStyle(
                                          color: Color(0xFF757575),
                                          fontSize: 20), // 中灰
                                    ),
                                    TextSpan(
                                      text: controller.isLoaded
                                        ? formatter.format(account.points)
                                        : '-', // 資料還沒來先顯示 '-'
                                      style: TextStyle(
                                          color: account.points >= 0
                                              ? Color(0xFF388E3C) // 綠色
                                              : Color(0xFFD32F2F), // 紅色
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20),
                                    ),
                                  ],
                                ),
                              ),
                              // Balance
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Balance ',
                                      style: TextStyle(
                                          color: Color(0xFF757575),
                                          fontSize: 20), // 中灰
                                    ),
                                    TextSpan(
                                      text: controller.isLoaded
                                        ? formatter.format(account.balance)
                                        : '-', // 資料還沒來先顯示 '-'
                                      style: TextStyle(
                                          color: account.balance >= 0
                                              ? Color(0xFF388E3C) // 綠色
                                              : Color(0xFFD32F2F), // 紅色
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 刪除按鈕
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.redAccent,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: Text('Delete ${account.accountName}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false), // 不刪除
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true), // 確認刪除
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await controller.deleteAccount(account.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('${account.accountName} deleted'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add, size: 50),
        onPressed: () {
          _showAddDialog(context);
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = context.read<ControllerPointRecordAccount>();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: 'Account'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await controller.createAccount(textController.text);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account already exists')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
