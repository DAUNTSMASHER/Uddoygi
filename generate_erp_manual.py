from fpdf import FPDF

class ERPSystemManual(FPDF):
    def header(self):
        if self.page_no() == 1:
            self.set_font('helvetica', 'B', 24)
            self.set_text_color(42, 10, 75)
            self.cell(0, 40, 'Uddoygi ERP: Comprehensive System Manual', 0, 1, 'C')
            self.set_font('helvetica', 'I', 12)
            self.set_text_color(100, 100, 100)
            self.cell(0, 10, 'Complete Feature Inventory, Architecture, and Logic Maps', 0, 1, 'C')
            self.ln(20)
        else:
            self.set_font('helvetica', 'B', 10)
            self.set_text_color(150, 150, 150)
            self.cell(0, 10, 'Uddoygi ERP System Manual', 0, 1, 'R')
            self.ln(5)

    def footer(self):
        self.set_y(-15)
        self.set_font('helvetica', 'I', 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f'Confidential - Page {self.page_no()}', 0, 0, 'C')

    def section_title(self, title):
        self.add_page()
        self.set_font('helvetica', 'B', 18)
        self.set_fill_color(42, 10, 75)
        self.set_text_color(255, 255, 255)
        self.cell(0, 15, f' {title}', 0, 1, 'L', fill=True)
        self.ln(10)

    def chapter_title(self, title):
        self.set_font('helvetica', 'B', 14)
        self.set_text_color(42, 10, 75)
        self.cell(0, 10, title, 0, 1, 'L')
        self.line(self.get_x(), self.get_y(), self.get_x() + 190, self.get_y())
        self.ln(5)

    def create_table(self, header, data, col_widths):
        self.set_font('helvetica', 'B', 10)
        self.set_fill_color(42, 10, 75)
        self.set_text_color(255, 255, 255)
        
        # Header
        for i, h in enumerate(header):
            self.cell(col_widths[i], 10, h, 1, 0, 'C', fill=True)
        self.ln()
        
        # Data
        self.set_font('helvetica', '', 9)
        self.set_text_color(0, 0, 0)
        for row in data:
            # Calculate max height
            max_h = 0
            for i, text in enumerate(row):
                lines = self.multi_cell(col_widths[i], 7, str(text), split_only=True)
                max_h = max(max_h, len(lines) * 7)
            
            if self.get_y() + max_h > 260:
                self.add_page()
                # Re-add header
                self.set_font('helvetica', 'B', 10)
                self.set_fill_color(42, 10, 75)
                self.set_text_color(255, 255, 255)
                for i, h in enumerate(header):
                    self.cell(col_widths[i], 10, h, 1, 0, 'C', fill=True)
                self.ln()
                self.set_font('helvetica', '', 9)
                self.set_text_color(0, 0, 0)

            curr_x = self.get_x()
            curr_y = self.get_y()
            for i, text in enumerate(row):
                self.multi_cell(col_widths[i], 7, str(text), border=1)
                self.set_xy(curr_x + col_widths[i], curr_y)
                curr_x += col_widths[i]
            self.ln(max_h)
        self.ln(5)

pdf = ERPSystemManual()
pdf.add_page()

# --- 1. ADMIN SCREENS ---
pdf.section_title('Part 1: Administrative Feature Inventory (40+ Screens)')
admin_header = ['Screen Name', 'Details / Purpose', 'Components & Logic']
admin_data = [
    ['Admin Dashboard', 'Central oversight hub for all company metrics.', 'UCard, ActivityFeed, KPI Grids. Math: Revenue/Expense sum.'],
    ['Net Profitability', 'Deep financial analysis of company health.', 'PieChart, StatCards. Math: Revenue - (Labor+Prod+Mark).'],
    ['HR Efficiency', 'Real-time staffing optimization tool.', 'EfficiencyHero, MetricTiles. Math: Workforce / WorkOrders.'],
    ['Live Monitoring', 'Real-time oversight of factory machines.', 'MachineGrid, UtilityProgress. Math: Output vs Goal.'],
    ['Order Analysis', 'Granular tracking of production bottlenecks.', 'StageProgress, DeliveryPredictor. Math: Stage duration.'],
    ['Inventory Mgmt', 'BOM vs Warehouse Stock comparison.', 'StockTable, ShortageAlerts. Math: Stock - Requirement.'],
    ['Sales Pipeline', 'Lead tracking and conversion analytics.', 'FunnelChart, LeadTable. Math: Deals / Leads.'],
    ['Customer CRM', 'Buyer relationship and tier management.', 'CustomerList, TierPill. Ranking logic based on volume.'],
    ['QC Overview', 'Aggregated quality test reports.', 'DefectHeatmap, SupplierPenalty. Math: Defect %.'],
    ['Campaign ROI', 'Marketing spend vs return analysis.', 'CampaignGrid, ROITracker. Math: Revenue / Spend.'],
    ['Employee Mgmt', 'Admin view of all staff and roles.', 'StaffTable, RoleManager, PermissionGuard.'],
    ['Salary Overview', 'Global payroll approval and oversight.', 'SalaryList, ApprovalStatus. Syncs with Finance.'],
    ['Welfare Scheme', 'Company-wide benefits monitoring.', 'WelfareGrid, BenefitDetails.'],
    ['SMTP Settings', 'Email server configuration for notifications.', 'InputForm, TestEmailAction.'],
    ['Security Audit', 'Access logs and system permission controls.', 'LogList, UserRoles.'],
    ['All Notices', 'Global announcement management.', 'NoticeForm, TargetDepartmentPicker.'],
    ['Reports Hub', 'Centralized exports for PDF/Excel data.', 'ExportActions, DateRangePicker.'],
    ['Company Profile', 'Organization identity and branch settings.', 'ProfileEditor, BranchList.'],
    ['Complaints Hub', 'Resolution tracking for staff/customers.', 'TicketList, ResolutionWorkflow.'],
    ['Research Hub', 'Innovation tracking and R&D monitoring.', 'ProjectGrid, MilestoneTracker.'],
]
pdf.create_table(admin_header, admin_data, [40, 70, 80])

# --- 2. HR SCREENS ---
pdf.section_title('Part 2: HR & Personnel Inventory (30+ Screens)')
hr_header = ['Screen Name', 'Details / Purpose', 'Components & Logic']
hr_data = [
    ['Payroll Processor', 'Automated monthly salary generation.', 'ExpansionTile, LoanBreakdown. Math: Gross - (Loan+Tax).'],
    ['Loan Approval', 'Vetting and approving staff loan requests.', 'ApprovalWorkflow, RepaymentTerms.'],
    ['Leave Mgmt', 'Employee absence tracking and approvals.', 'CalendarView, LeaveList. Syncs with Efficiency.'],
    ['Employee Dir', 'Searchable profiles and contact details.', 'SearchField, ProfileCard.'],
    ['Appointment Gen', 'Automated legal document creation.', 'PDFExporter, TemplateEditor.'],
    ['Salary Cert', 'Generation of official income proofs.', 'DocTemplate, DigitalSignature.'],
    ['Budget Forecast', 'Financial planning for departmental spend.', 'ForecastChart, VarianceAnalysis.'],
    ['Attendance', 'Daily check-in/out tracking.', 'ShiftTracker, OvertimeCalc.'],
    ['Recruitment', 'Job posting and applicant tracking.', 'JobGrid, ApplicantStages.'],
    ['Incentives', 'KPI-based bonus calculation.', 'IncentiveFormula, RewardGrid. Math: % of target.'],
    ['General Ledger', 'Detailed accounting for HR transactions.', 'LedgerTable, EntryForm.'],
    ['Tax Management', 'Compliance and deduction tracking.', 'TaxTable, BracketEditor.'],
    ['Accounts Pay', 'Managing company debts to suppliers.', 'PayableList, PaymentDispatch.'],
    ['Balance Update', 'Manual adjustment of fund accounts.', 'AdjustmentForm, AuditTrail.'],
    ['Shift Tracker', 'Managing worker rotations and rosters.', 'ShiftGrid, SwapRequest.'],
    ['Welfare Screen', 'Staff welfare fund and activity logs.', 'ContributionTable, GrantHistory.'],
]
pdf.create_table(hr_header, hr_data, [40, 70, 80])

# --- 3. MARKETING SCREENS ---
pdf.section_title('Part 3: Marketing & Sales Inventory (25+ Screens)')
mark_header = ['Screen Name', 'Details / Purpose', 'Components & Logic']
mark_data = [
    ['Marketing Dash', 'Sales agent performance and targets.', 'TargetGauge, AgentLeaderboard.'],
    ['Invoice Creator', 'Billing generation for customers.', 'ItemPicker, TotalCalc. Math: Qty*Price + Tax.'],
    ['All Invoices', 'History and status of all transactions.', 'StatusPill, PaymentVerifier.'],
    ['Payment Slips', 'Image-to-data validation for bank slips.', 'DocumentExtractor, OCRPreview.'],
    ['Order Tracking', 'Shipping status for customer satisfaction.', 'TimelineView, CourierSync.'],
    ['Campaign Mgr', 'Digital ad and bulk-offer manager.', 'OfferForm, LeadSourceTracker.'],
    ['Products Page', 'Catalog view for sales agents.', 'ProductGrid, SpecificationView.'],
    ['Sales Report', 'Departmental revenue analytics.', 'SalesReportChart, RegionHeatmap.'],
    ['Task Assign', 'Sales task allocation for agents.', 'TaskCard, PriorityPicker.'],
    ['Address Valid', 'AI-assisted delivery address checking.', 'AddressParser, GoogleMapsSync.'],
    ['Remuneration', 'Agent commission and bonus tracking.', 'CommissionCalc, PaymentHistory.'],
]
pdf.create_table(mark_header, mark_data, [40, 70, 80])

# --- 4. FACTORY & R&D ---
pdf.section_title('Part 4: Operations & Innovation (20+ Screens)')
ops_header = ['Screen Name', 'Details / Purpose', 'Components & Logic']
ops_data = [
    ['Live Floor', 'Real-time machine and line oversight.', 'MachineStatusGrid, LiveCounter.'],
    ['Work Order', 'Production instructions and specs.', 'TechnicalSpecs, StageUpdate. Syncs with Marketing.'],
    ['QC Report', 'Material and product quality testing.', 'DefectLogger, PassRateCalc.'],
    ['R&D Dashboard', 'Prototype and innovation monitoring.', 'ProjectMilestones, R&DAnalytics.'],
    ['BOM Creator', 'Bill of Materials for new products.', 'MaterialPicker, UnitCostCalc.'],
    ['Project Req', 'Requests for new product development.', 'RequestForm, PriorityQueue.'],
    ['Milestones', 'Tracking R&D progress stages.', 'Timeline, AssetUploader.'],
    ['Daily Update', 'Worker reports from the factory floor.', 'UpdateForm, PhotoLogger.'],
    ['Resource Alloc', 'Assigning labor to production lines.', 'CapacityChart, StaffAssigner.'],
]
pdf.create_table(ops_header, ops_data, [40, 70, 80])

# --- 5. CORE SERVICES & MODELS ---
pdf.section_title('Part 5: Core Services, Models & Themes')

pdf.chapter_title('5.1 Core Services (The System Brain)')
serv_header = ['Service Name', 'Description / Responsibility', 'Key Technology']
serv_data = [
    ['DataSyncService', 'Orchestrates cross-departmental triggers.', 'Firestore Batch / Triggers'],
    ['DocumentExtractor', 'AI module for image-to-data parsing.', 'OCR / NLP / Regex'],
    ['AIService', 'Provides insights and assistant capabilities.', 'Google Gemini API'],
    ['AuthService', 'Handles login, multi-tenant company IDs.', 'Firebase Auth'],
    ['DB Service', 'Abstracted Firestore collection access.', 'Cloud Firestore SDK'],
    ['LocalStorage', 'Offline persistence and session caching.', 'Shared Preferences / Hive'],
    ['FCM Service', 'Push notifications and real-time alerts.', 'Firebase Cloud Messaging'],
    ['EmailService', 'Automated transaction and alert emails.', 'SMTP / SendGrid'],
    ['DriveStorage', 'Secure storage for invoices and files.', 'Google Drive API'],
    ['AppRulesGuard', 'Enforces business logic across modules.', 'Policy Engine'],
]
pdf.create_table(serv_header, serv_data, [40, 90, 60])

pdf.chapter_title('5.2 Data Models (Blueprints)')
mod_header = ['Model Name', 'Fields / Schema Highlights', 'Used In']
mod_data = [
    ['UserModel', 'uid, email, cid, role, dept, salary.', 'Global Auth'],
    ['LoanModel', 'employeeId, amount, emi, deducted, status.', 'HR / Finance'],
    ['InvoiceModel', 'grandTotal, items, status, agent, cid.', 'Marketing / Admin'],
    ['WorkOrderModel', 'specs, currentStage, targetQty, deadline.', 'Factory / Marketing'],
    ['BOMModel', 'productId, materials, quantityPerUnit.', 'R&D / Inventory'],
    ['PipraTxnModel', 'txnId, amount, beneficiary, status.', 'Payments'],
    ['NoticeModel', 'title, body, targetDept, timestamp.', 'Communication'],
    ['ComplaintModel', 'userId, category, description, status.', 'Common'],
]
pdf.create_table(mod_header, mod_data, [40, 90, 60])

pdf.chapter_title('5.3 Premium Themes (Aesthetics)')
theme_header = ['Theme Name', 'Primary Colors', 'Visual Style']
theme_data = [
    ['Admin Theme', 'Purple (#1E0040), White', 'Professional, Analytics-focused, Elevated.'],
    ['Marketing Theme', 'Blue (#0D47A1), Surface', 'Energetic, Sales-driven, Clean.'],
    ['HR Theme', 'Green (#25BC5F), White', 'Trustworthy, Organic, Structured.'],
    ['Factory Theme', 'Slate (#0F172A), Amber', 'Industrial, High-contrast, Functional.'],
    ['R&D Theme', 'Indigo (#4F46E5), Dark', 'Futuristic, Innovation-focused.'],
]
pdf.create_table(theme_header, theme_data, [40, 90, 60])

pdf.output('Uddoygi_ERP_System_Manual.pdf')
print('System Manual PDF Generated successfully.')
