import 'dart:typed_data';

import 'package:excel/excel.dart';

Uint8List workbookBytes({
  String sheetName = 'Data',
  int headerRow = 1,
  required List<String> headers,
  required List<List<Object?>> rows,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null) excel.rename(defaultSheet, sheetName);
  final sheet = excel[sheetName];
  for (var column = 0; column < headers.length; column++) {
    sheet
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: headerRow - 1,
          ),
        )
        .value = TextCellValue(
      headers[column],
    );
  }
  for (var row = 0; row < rows.length; row++) {
    for (var column = 0; column < rows[row].length; column++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: headerRow + row,
            ),
          )
          .value = cellValue(
        rows[row][column],
      );
    }
  }
  return Uint8List.fromList(excel.save()!);
}

CellValue? cellValue(Object? value) => switch (value) {
  null => null,
  int() => IntCellValue(value),
  double() => DoubleCellValue(value),
  bool() => BoolCellValue(value),
  DateTime() => DateTimeCellValue.fromDateTime(value),
  FormulaValue() => FormulaCellValue(value.formula),
  _ => TextCellValue(value.toString()),
};

class FormulaValue {
  const FormulaValue(this.formula);
  final String formula;
}
