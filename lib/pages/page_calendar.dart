import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/controller_calendar_view.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/widget/utils_calendar_widgets.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:provider/provider.dart';

class PageCalendar extends StatelessWidget {
  const PageCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ControllerCalendarView>(
          create: (_) => ControllerCalendarView(),
        ),
        ChangeNotifierProvider<ControllerEvent>(
          create: (_) => ControllerEvent(tableName: constTableCalendarEvents, toTableName: constTableMemoryTrace),
        ),
      ],
      child: CalendarInitializer(loc: loc),
    );
  }
}

class CalendarInitializer extends StatefulWidget {
  final AppLocalizations loc;
  const CalendarInitializer({required this.loc, super.key});

  @override
  State<CalendarInitializer> createState() => _CalendarInitializerState();
}

class _CalendarInitializerState extends State<CalendarInitializer> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = Future(() async {
      final controller = context.read<ControllerCalendarView>();
      await controller.init(widget.loc);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return const CalendarView(key: ValueKey('calendar_view'));
        },
      ),
    );
  }
}

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late PageController pageController;
  late ControllerCalendarView controllerView;

  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    controllerView = context.read<ControllerCalendarView>();
    final initialPage = controllerView.data.pageIndex;
    pageController = PageController(initialPage: initialPage);
    // 監聽 controller 的變動，若 pageIndex 改變則跳頁
    controllerView.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!_mounted) return;
    final newPage = controllerView.data.pageIndex;
    if (pageController.hasClients &&
        pageController.page?.round() != newPage) {
      pageController.animateToPage(
        newPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _mounted = false;
    controllerView.removeListener(_onControllerChanged);
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final monthFormat = DateFormat('y / M');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 移除底色
        centerTitle: true,
        title: Consumer<ControllerCalendarView>(
          builder: (context, viewController, _) {
            final month = viewController.data.currentMonth;
            final isCurrentMonth = DateTimeCompare.isCurrentMonth(month);
            return CalendarAppBar(
              monthLabel: monthFormat.format(month),
              monthColor: isCurrentMonth ? Colors.blueAccent : Colors.black,
              buttonSize: MediaQuery.of(context).size.shortestSide * 0.1,
              onPrevious: viewController.goToPreviousMonth,
              onNext: viewController.goToNextMonth,
              onToday: viewController.goToToday,
              onAddEvent: () => viewController.addEvent(context),
              onMonthTap: () => _showMonthPicker(context, viewController),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          CalendarBody(
              pageController: pageController,
              loc: loc,),
          Consumer<ControllerCalendarView>(
            builder: (_, viewController, __) {
              if (!viewController.data.isLoading) return const SizedBox.shrink();
              return const Positioned.fill(
                child: ColoredBox(
                  color: Color.fromARGB(153, 255, 255, 255),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthPicker(
      BuildContext context, ControllerCalendarView viewController) async {
    await showMonthYearPicker(
      context: context,
      initialDate: viewController.data.currentMonth,
      onChanged: (newDate) async {
        await viewController.jumpToMonth(newDate);
      },
    );
  }
}
