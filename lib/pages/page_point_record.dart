import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
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
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: account.masterGraphUrl != null
                      ? NetworkImage(account.masterGraphUrl!)
                      : null,
                  child: account.masterGraphUrl == null
                      ? Text(account.accountName[0])
                      : null,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await controller.deleteAccount(account.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${account.accountName} deleted')),
                    );
                  },
                ),
                title: Text(account.accountName),
                subtitle: Text(
                  'Points ${formatter.format(account.points)}｜Balance ${formatter.format(account.balance)}',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PagePointRecordDetail(
                          service: context.read<ServicePointRecord>(),
                          accountId: account.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
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
        title: const Text('New'),
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
