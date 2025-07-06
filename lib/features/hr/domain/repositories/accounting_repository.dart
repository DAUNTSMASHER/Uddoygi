import '../entities/ledger.dart' show LedgerModel;
import '../entities/ar_ap.dart' show ARAPModel;
import '../entities/invoice.dart' show InvoiceModel;
import '../entities/payslip.dart' show Payslip;

abstract class AccountingRepository {
  // 📒 Ledger Methods
  Future<void> addLedgerEntry(LedgerModel ledger);
  Future<void> updateLedgerEntry(String id, LedgerModel ledger);
  Future<void> deleteLedgerEntry(String id);
  Future<List<LedgerModel>> getAllLedgerEntries();
  Future<List<LedgerModel>> getLedgerByAccountType(String accountType);

  // 🔁 AR/AP Methods
  Future<void> addARAPEntry(ARAPModel arap);
  Future<void> updateARAPEntry(String id, ARAPModel arap);
  Future<void> deleteARAPEntry(String id);
  Future<List<ARAPModel>> getAllARAPEntries();
  Future<List<ARAPModel>> getARAPByType(String type); // Receivable or Payable

  // 🧾 Invoice Methods
  Future<void> addInvoice(InvoiceModel invoice);
  Future<void> updateInvoice(String id, InvoiceModel invoice);
  Future<void> deleteInvoice(String id);
  Future<List<InvoiceModel>> getAllInvoices();
  Future<List<InvoiceModel>> getInvoicesByEmployee(String employeeId);

  // 💳 Payslip Methods
  Future<void> addPayslip(Payslip payslip);
  Future<void> updatePayslip(String id, Payslip payslip);
  Future<void> deletePayslip(String id);
  Future<List<Payslip>> getPayslipsByEmployee(String employeeId);
  Future<List<Payslip>> getAllPayslips();
}
