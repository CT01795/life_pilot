import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
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
    // 延後到 build 完成再呼叫
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadAccounts();
    });
    _isInitialized = true;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Selector<ControllerPointRecordAccount, List<ModelPointRecordAccount>>(
        selector: (_, c) => c.accounts,
        builder: (context, accounts, _) {
          if (accounts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              return _AccountCard(
                key: ValueKey(accounts[index].id),
                accountId: accounts[index].id, // ✅ 只傳 id
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

class _AccountCard extends StatelessWidget {
  final String accountId;

  const _AccountCard({
    super.key,
    required this.accountId,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ControllerPointRecordAccount, ModelPointRecordAccount>(
      selector: (_, c) => c.getAccountById(accountId),
      shouldRebuild: (prev, next) =>
        prev.points != next.points ||
        prev.balance != next.balance ||
        prev.masterGraphUrl != next.masterGraphUrl,
      builder: (context, account, _) {
        if (account.id == '__dummy__') {
          return const SizedBox.shrink();
        }
        final formatter = NumberFormat('#,###');

        return Card(
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PagePointRecordDetail(
                    service: context.read<ServicePointRecord>(),
                    accountId: account.id,
                    accountName: account.accountName,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== 圖片 =====
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 512,
                        maxHeight: 512,
                        imageQuality: 75,
                      );
                      if (pickedFile != null) {
                        await context
                          .read<ControllerPointRecordAccount>()
                          .updateAccountImage(account.id, pickedFile);
                      }
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
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
                            AccountImage(
                              imageBytes: account.masterGraphUrl,
                              accountName: account.accountName,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Gaps.w16,
                  // ===== 文字 =====
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                text: formatter.format(account.points),
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
                                text: formatter.format(account.balance), // 資料還沒來先顯示 '-'
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

                  // ===== 刪除 =====
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: Colors.redAccent,
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          content:
                              Text('Delete ${account.accountName}?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await context
                          .read<ControllerPointRecordAccount>()
                          .deleteAccount(account.id);
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
  }
}

class AccountImage extends StatelessWidget {
  final Uint8List? imageBytes;
  final String accountName;

  const AccountImage({
    super.key,
    required this.imageBytes,
    required this.accountName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageBytes != null
            ? Image(
                image: MemoryImage(imageBytes!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : Center(
                child: Text(
                  accountName[0],
                  style: const TextStyle(fontSize: 32),
                ),
              ),
      ),
    );
  }
}