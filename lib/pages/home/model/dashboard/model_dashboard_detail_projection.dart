class ModelDashboardDetailProjection {
  final List<Map<String, dynamic>> previewRows;
  final num todayTotal;

  ModelDashboardDetailProjection(
    List<Map<String, dynamic>> rows,
    this.todayTotal,
  ) : previewRows = List.unmodifiable(rows);
}
