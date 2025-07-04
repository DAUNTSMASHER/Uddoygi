import 'package:uddoygi/features/hr/domain/repositories/employee_repository.dart';
import 'package:uddoygi/features/hr/domain/repositories/attendance_repository.dart';
import 'package:uddoygi/features/hr/domain/repositories/leave_repository.dart';
import 'package:uddoygi/features/hr/domain/repositories/shift_repository.dart';
import 'package:uddoygi/features/hr/domain/repositories/payroll_repository.dart';
import 'package:uddoygi/features/hr/domain/repositories/benefit_repository.dart';
import 'package:uddoygi/features/hr/domain/repositories/accounting_repository.dart';

abstract class HRRepository
    implements
        EmployeeRepository,
        AttendanceRepository,
        LeaveRepository,
        ShiftRepository,
        PayrollRepository,
        BenefitRepository,
        AccountingRepository {}
