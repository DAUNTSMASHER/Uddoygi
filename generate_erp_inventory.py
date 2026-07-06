from fpdf import FPDF

class ERPInventoryPDF(FPDF):
    def header(self):
        self.set_font('helvetica', 'B', 20)
        self.set_text_color(42, 10, 75) # Brand Purple
        self.cell(0, 15, 'Uddoygi ERP: Project Logic & Inventory', 0, 1, 'C')
        self.set_font('helvetica', 'I', 10)
        self.set_text_color(100, 100, 100)
        self.cell(0, 10, 'Complete Feature Map, Logic Formulas, and Departmental Dependencies', 0, 1, 'C')
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font('helvetica', 'I', 8)
        self.cell(0, 10, f'Page {self.page_no()}', 0, 0, 'C')

    def chapter_title(self, title):
        self.set_font('helvetica', 'B', 16)
        self.set_fill_color(240, 240, 240)
        self.set_text_color(42, 10, 75)
        self.cell(0, 12, f'  {title}', 0, 1, 'L', fill=True)
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
            # Calculate max height needed for this row
            max_h = 0
            for i, text in enumerate(row):
                # Use multi_cell to calculate height
                lines = self.multi_cell(col_widths[i], 7, text, split_only=True)
                max_h = max(max_h, len(lines) * 7)
            
            # Check if row fits on page
            if self.get_y() + max_h > 270:
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
                self.multi_cell(col_widths[i], 7, text, border=1)
                self.set_xy(curr_x + col_widths[i], curr_y)
                curr_x += col_widths[i]
            self.ln(max_h)

pdf = ERPInventoryPDF()
pdf.add_page()

# --- ADMIN MODULE ---
pdf.chapter_title('1. Admin Module (The Control Center)')
admin_header = ['Page Name', 'Primary Purpose', 'Key Logic / Math', 'Dependency']
admin_data = [
    ['Admin Dashboard', 'Real-time oversight of all departments.', 'Aggregates KPIs from 5 collections.', 'Global Sync'],
    ['Net Profitability', 'Financial health analysis.', 'Revenue - Expenses = Profit.', 'Finance / Marketing'],
    ['HR Efficiency', 'Workforce productivity tracking.', '(Workforce - Leave) / WorkOrders.', 'HR / Factory'],
    ['Inventory Sync', 'BOM vs Warehouse Stock comparison.', 'Stock - BOM Requirement = Delta.', 'Factory / R&D'],
    ['Sales Pipeline', 'Monitoring leads and conversion rates.', 'Deals / Total Leads = % Rate.', 'Marketing'],
    ['Order Analysis', 'Granular tracking of production orders.', 'Time per stage / Bottleneck flag.', 'Factory'],
    ['Supplier Mgmt', 'Vetting and rating material vendors.', 'Penalty for QC failures.', 'Procurement'],
]
pdf.create_table(admin_header, admin_data, [40, 50, 60, 40])
pdf.ln(10)

# --- HR MODULE ---
pdf.chapter_title('2. HR & Employee Module (People & Payroll)')
hr_header = ['Page Name', 'Primary Purpose', 'Key Logic / Math', 'Dependency']
hr_data = [
    ['Payroll Processing', 'Monthly salary generation.', 'Net = Gross - (Loans + Tax).', 'Accounts'],
    ['Loan Management', 'Employee loan tracking & recovery.', 'Outstanding = Disbursed - Paid.', 'Finance'],
    ['Leave Management', 'Absence tracking and approvals.', 'Impacts active workforce count.', 'Admin Efficiency'],
    ['Employee Directory', 'Centralized staff profiles.', 'Secure role-based access.', 'Auth System'],
    ['Appointment Letter', 'Automatic generation of legal docs.', 'Template-based PDF creation.', 'R&D'],
    ['Incentives Screen', 'Performance-based bonus calculation.', 'KPI Target vs Actual achieved.', 'Admin Dashboard'],
]
pdf.create_table(hr_header, hr_data, [40, 50, 60, 40])
pdf.ln(10)

# --- MARKETING MODULE ---
pdf.chapter_title('3. Marketing & Sales (Revenue & Relationships)')
mark_header = ['Page Name', 'Primary Purpose', 'Key Logic / Math', 'Dependency']
mark_data = [
    ['Marketing Dashboard', 'Sales tracking and target monitoring.', 'Revenue vs Monthly Target.', 'Finance'],
    ['Invoice Mgmt', 'Billing and transaction tracking.', 'Total = Subtotal + Tax + Ship.', 'Admin Finance'],
    ['Customer CRM', 'Managing buyer relationships & tiers.', 'Gold/Silver/Bronze ranking.', 'Sales Data'],
    ['Campaign Screen', 'Trade show and bulk-offer tracking.', 'ROI = Revenue / Campaign Spend.', 'Admin'],
    ['Payment Slips', 'Validation of manual bank payments.', 'OCR Extraction -> Verified Flag.', 'AI Service'],
    ['Order Tracking', 'Real-time shipping status for customers.', 'Connected to Factory stages.', 'Factory'],
]
pdf.create_table(mark_header, mark_data, [40, 50, 60, 40])
pdf.ln(10)

# --- FACTORY & R&D ---
pdf.chapter_title('4. Operations: Factory & R&D (The Heart)')
fact_header = ['Page Name', 'Primary Purpose', 'Key Logic / Math', 'Dependency']
fact_data = [
    ['Live Floor View', 'Real-time machine and line oversight.', 'Uptime vs Down-time log.', 'Work Orders'],
    ['Work Order Screen', 'Technical specs for production lines.', 'Step-by-step progress update.', 'Marketing Orders'],
    ['Quality Control', 'Testing and defect logging.', 'Defect % vs Threshold Alert.', 'Supplier Rating'],
    ['R&D Projects', 'New product prototyping.', 'Milestone-based progress.', 'Factory Specs'],
    ['BOM Creator', 'Bill of Materials for new products.', 'Detailed list of raw materials.', 'Inventory Sync'],
    ['Resource Alloc', 'Assigning staff to production lines.', 'Load vs Capacity analysis.', 'HR Efficiency'],
]
pdf.create_table(fact_header, fact_data, [40, 50, 60, 40])
pdf.ln(10)

# --- PAYMENTS ---
pdf.chapter_title('5. Payments & Core Infrastructure')
pay_header = ['Page Name', 'Primary Purpose', 'Key Logic / Math', 'Dependency']
pay_data = [
    ['PipraPay Dashboard', 'Digital payment gateway management.', 'Balance & Settlement tracking.', 'Banking API'],
    ['Initiate Payment', 'Starting a checkout transaction.', 'Generates secure payment link.', 'PipraPay'],
    ['Transactions', 'Complete history of all digital payments.', 'Verified vs Pending status.', 'Webhook Sync'],
    ['Data Sync Service', 'Background cross-departmental updates.', 'Multi-doc Firestore Batch write.', 'Global App'],
    ['Document Extractor', 'AI module for image-to-data extraction.', 'Confidence ranking & Parser.', 'AI / OCR'],
]
pdf.create_table(pay_header, pay_data, [40, 50, 60, 40])

pdf.output('Uddoygi_ERP_Full_Inventory.pdf')
print('PDF Generated successfully.')
