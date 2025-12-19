import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/pages/page_point_record_detail.dart';
import 'package:life_pilot/services/service_point_record.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

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
    controller.loadAccounts();
    _isInitialized = true;
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
        return ListView.builder(
          itemCount: controller.accounts.length,
          itemBuilder: (context, index) {
            final account = controller.accounts[index];
            return Card(
                color: Colors.grey[50], // 卡片背景淺灰
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagePointRecordDetail(
                          service: context.read<ServicePointRecord>(),
                          accountId: account.id,
                        ),
                      ),
                    );
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
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            child: account.masterGraphUrl != null
                                ? ClipOval(
                                    child: Image.memory(
                                      account.masterGraphUrl!,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(
                                    account.accountName[0],
                                    style: const TextStyle(fontSize: 24),
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
                                  fontSize: 18,
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
                                      style: TextStyle(color: Color(0xFF757575)), // 中灰
                                    ),
                                    TextSpan(
                                      text: formatter.format(account.points),
                                      style: TextStyle(
                                        color: account.points >= 0
                                            ? Color(0xFF388E3C) // 綠色
                                            : Color(0xFFD32F2F), // 紅色
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      style: TextStyle(color: Color(0xFF757575)), // 中灰
                                    ),
                                    TextSpan(
                                      text: formatter.format(account.balance),
                                      style: TextStyle(
                                        color: account.balance >= 0
                                            ? Color(0xFF388E3C) // 綠色
                                            : Color(0xFFD32F2F), // 紅色
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                    onPressed: () => Navigator.pop(context, false), // 不刪除
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    onPressed: () => Navigator.pop(context, true), // 確認刪除
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await controller.deleteAccount(account.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${account.accountName} deleted'),
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
