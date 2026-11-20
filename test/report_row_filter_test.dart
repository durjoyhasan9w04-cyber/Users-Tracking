import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/services/report_row_filter.dart';
void main(){
 test('filters report preview by transaction type',(){
  final rows=<Map<String,Object?>>[
   {'type':'DP','user_name':'Alice','phone':'0171','reason':'','notes':'morning','transaction_date':'2026-11-01'},
   {'type':'Quiz Bonus','user_name':'Bob','phone':'0182','reason':'Special','notes':'quiz','transaction_date':'2026-11-02'},
  ];
  expect(ReportRowFilter.apply(rows,typeFilter:'Quiz Bonus').single['user_name'],'Bob');
 });
 test('searches report preview case-insensitively across phone and notes',(){
  final rows=<Map<String,Object?>>[
   {'type':'DP','user_name':'Alice','phone':'0171','reason':'','notes':'Morning top up','transaction_date':'2026-11-01'},
   {'type':'Bonus','user_name':'Bob','phone':'0182','reason':'Special','notes':'Quiz reward','transaction_date':'2026-11-02'},
  ];
  expect(ReportRowFilter.apply(rows,search:'0182').single['user_name'],'Bob');
  expect(ReportRowFilter.apply(rows,search:'MORNING').single['user_name'],'Alice');
 });
 test('returns all rows for an empty search and All type',(){
  final rows=<Map<String,Object?>>[{'type':'DP'},{'type':'Bonus'}];
  expect(ReportRowFilter.apply(rows).length,2);
 });
}
