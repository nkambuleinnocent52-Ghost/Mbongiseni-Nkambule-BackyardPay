from pathlib import Path
from xml.sax.saxutils import escape
import textwrap
from PIL import Image as PILImage
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, Table, TableStyle
from reportlab.lib.styles import ParagraphStyle

ROOT=Path(__file__).resolve().parents[2]
E=Path(__file__).resolve().parent/'screenshots'
OUT=ROOT/'downloads/BackyardPay-Project-Portfolio-231064977.pdf'
for n,f in [('Body','DejaVuSans.ttf'),('Bold','DejaVuSans-Bold.ttf'),('Mono','DejaVuSansMono.ttf')]:pdfmetrics.registerFont(TTFont(n,'/usr/share/fonts/truetype/dejavu/'+f))
W,H=A4; M=45; CW=W-2*M
INK=HexColor('#182126'); MUTED=HexColor('#56616A'); GOLD=HexColor('#A97A20'); LINE=HexColor('#DCE1E4'); PALE=HexColor('#F4F6F7')
c=canvas.Canvas(str(OUT),pagesize=A4)
c.setTitle('BackyardPay | Project Portfolio | 231064977')
c.setAuthor('Mbongiseni Nkambule')
c.setSubject('Application Technology IV (APT41P2): context, goals, user manual and code appendix')
styles={
 'body':ParagraphStyle('body',fontName='Body',fontSize=10.2,leading=14.4,textColor=INK,spaceAfter=7),
 'small':ParagraphStyle('small',fontName='Body',fontSize=8.4,leading=11.5,textColor=MUTED),
 'caption':ParagraphStyle('caption',fontName='Body',fontSize=8.2,leading=11,textColor=MUTED),
 'h2':ParagraphStyle('h2',fontName='Bold',fontSize=12.5,leading=17,textColor=INK),
 'table':ParagraphStyle('table',fontName='Body',fontSize=8.8,leading=12,textColor=INK),
}
page=0;y=0
GITHUB='https://github.com/nkambuleinnocent52-Ghost/Mbongiseni-Nkambule-BackyardPay'
SITE='https://quiet-pastelito-19fa50.netlify.app'

def para(text,kind='body',x=M,width=CW,after=7):
 global y
 p=Paragraph(text,styles[kind]);_,h=p.wrap(width,800)
 assert y-h>45,(page,text[:70],y,h)
 p.drawOn(c,x,y-h);y-=h+after
 return h

def heading(text):
 global y
 para(text,'h2',after=8)

def new(title,section):
 global page,y
 if page:c.showPage()
 page+=1
 c.setFillColor(GOLD);c.rect(M,H-35,35,3,fill=1,stroke=0)
 c.setFont('Bold',8);c.setFillColor(MUTED);c.drawString(M+45,H-34,'BACKYARDPAY  /  APT41P2')
 c.setFont('Body',8);c.drawRightString(W-M,H-34,section.upper())
 c.setStrokeColor(LINE);c.line(M,43,W-M,43)
 c.setFont('Body',8);c.setFillColor(MUTED);c.drawString(M,29,'Mbongiseni Nkambule  |  231064977')
 c.drawRightString(W-M,29,f'{page} / 13')
 c.bookmarkPage('page'+str(page));c.addOutlineEntry(title,'page'+str(page),0,False)
 y=H-72
 c.setFillColor(INK);c.setFont('Bold',20);c.drawString(M,y,title);y-=28

def table(rows,widths=None):
 global y
 cells=[[Paragraph(str(v),styles['table']) for v in row] for row in rows]
 t=Table(cells,colWidths=widths or [CW/len(rows[0])]*len(rows[0]))
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),PALE),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),8),('RIGHTPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),('LINEBELOW',(0,0),(-1,0),.7,LINE),('LINEBELOW',(0,1),(-1,-1),.3,LINE)]))
 _,h=t.wrap(CW,800);assert y-h>50,(page,h,y);t.drawOn(c,M,y-h);y-=h+12

def picture(name,caption,crop=None,maxh=240,width=CW,x=M):
 global y
 path=E/name
 iw,ih=PILImage.open(path).size
 left,top,right,bottom=crop or (0,0,iw,ih)
 scale=min(width/(right-left),maxh/(bottom-top));dw=(right-left)*scale;dh=(bottom-top)*scale
 assert y-dh>65,(page,name,y,dh)
 xx=x+(width-dw)/2; bottom_y=y-dh
 c.saveState();p=c.beginPath();p.rect(xx,bottom_y,dw,dh);c.clipPath(p,stroke=0,fill=0)
 c.drawImage(str(path),xx-left*scale,bottom_y-(ih-bottom)*scale,width=iw*scale,height=ih*scale,mask='auto')
 c.restoreState();c.setStrokeColor(LINE);c.rect(xx,bottom_y,dw,dh,fill=0,stroke=1)
 y-=dh+6
 para(caption,'caption',x=x,width=width,after=10)

def code(path,start,end,title):
 global y
 heading(title)
 para(f'<b>Source:</b> {escape(path)}, lines {start}–{end}.','small',after=6)
 lines=(ROOT/path).read_text().splitlines()[start-1:end]
 # Keep actual source text; long lines wrap visually with an unnumbered continuation.
 rendered=[]
 for n,line in enumerate(lines,start):
  chunks=textwrap.wrap(line,92,replace_whitespace=False,drop_whitespace=False) or ['']
  rendered.append(f'{n:>3}  '+chunks[0]);rendered.extend('     '+q for q in chunks[1:])
 h=len(rendered)*10.8+16
 assert y-h>55,(page,path,h,y)
 c.setFillColor(PALE);c.roundRect(M,y-h,CW,h,5,fill=1,stroke=0)
 c.setFillColor(INK);c.setFont('Mono',8)
 yy=y-13
 for line in rendered:c.drawString(M+9,yy,line);yy-=10.8
 y-=h+11

new('BackyardPay','Project portfolio')
y-=28
c.setFillColor(GOLD);c.roundRect(M,y-63,66,66,10,fill=1,stroke=0);c.setFillColor(white);c.setFont('Bold',26);c.drawCentredString(M+33,y-39,'BP')
y-=96
para('Shared records for backyard rentals','h2',after=14)
para('Mobile rental management and payment records for landlords and tenants in East London, Eastern Cape.',after=28)
table([['STUDENT','MODULE'],['Mbongiseni Nkambule<br/>Student number: <b>231064977</b>','Application Technology IV<br/><b>APT41P2</b>'],['PROJECT','SUBMISSION'],['Individual project<br/>Application release: 1.4.0 (build 13)','Project portfolio<br/>12 November 2026']])
heading('Project links')
para(f'<link href="{GITHUB}" color="#805A12"><b>Open the GitHub source repository</b></link>')
para(GITHUB,'small',after=12)
para(f'<link href="{SITE}" color="#805A12"><b>Open the deployed BackyardPay application</b></link>')
para(SITE,'small',after=20)
heading('Document guide')
para('Context: page 2 · Goal and objectives: page 3 · User manual: pages 4–8 · Code appendix: pages 9–12 · References: page 13.')
para('Prepared against the supplied 2026 project guideline. Functionality is documented through screenshots and steps; the class message specifies a seven-minute presentation without a live demo.','small')

new('1. Context and background','Maximum one page')
heading('The problem')
para('Backyard rental arrangements can involve cash, bank transfers and messages kept in different places. When a landlord relies on a notebook or scattered messages, it can be difficult to identify who has paid, which month a payment covers and what remains outstanding. A tenant may also struggle to retrieve an agreed payment record when a disagreement arises. A payment reported by a tenant can be mistaken for money the landlord has actually received.')
para('BackyardPay addresses this record-keeping problem by linking properties, assigned rooms, tenants and payment records in one system. Landlords and tenants see the same rental relationship through separate, authorised views. The intended benefit is clearer records and easier follow-up; the project does not claim measured reductions in disputes or results from an unperformed local field study.')
heading('Target community and users')
para('The intended setting is small backyard rental properties in East London, Eastern Cape. The landlord manages rooms, rent and deposits. The tenant checks their own rental information, reports payments already made and reports problems. A tenant account connects to a room already assigned by the landlord through a private invitation. The application is not a property-search marketplace.')
heading('Why mobile access is suitable')
para('A tenant can record a cash or bank payment from a phone, view their balance and retrieve a receipt without returning to a desktop computer. A landlord can check records at a property, acknowledge a leaking tap report and capture the property location with permission. A desktop interface can support the same accounting tasks, but normally ties use to a computer. BackyardPay adapts navigation and layout to smaller screens as well as larger browsers (Flutter, n.d.).')
heading('Scope and boundaries')
para('The current implementation is a Flutter/Dart application deployed as a responsive website on Netlify, with Supabase authentication and PostgreSQL storage. It records cash, EFT and other payment methods but does not transfer money or verify a bank account. Only landlord-confirmed rent payments reduce recorded rent balances. Deposits remain separate from rent.')
para('Rent is normally due on the 1st. A first partial month can be calculated from actual calendar days, including move-in day. The ten-day deposit deadline is the project’s agreed product policy, not a claim that South African law gives every tenant a universal ten-day grace period. Deposit deductions must be supported and do not automatically forfeit the entire deposit (Republic of South Africa, 1999).')

new('2. Goal and objectives','Half-page summary')
para('<b>Goal:</b> Provide landlords and tenants with a simple, shared and traceable record of backyard rentals, rent payments, security deposits and reported problems.')
para('<b>Objectives:</b> (1) Register users and link tenants securely to assigned rooms. (2) Manage properties, room availability and room-specific rent. (3) Calculate first-month rent and track monthly balances. (4) Report and confirm rent/deposit payments separately, with receipts. (5) Support issue acknowledgement and in-app notifications.')
table([['INPUT','PROCESS / SCREEN','OUTPUT'],['Property, room, monthly rent, deposit and move-in date','Property setup and tenant onboarding; calculate first-month charge','Available rooms and itemised move-in costs'],['Payment amount, date, method and rent month','Tenant report; landlord receipt check and confirmation','Pending/confirmed status, updated balance and receipt'],['Issue location and description','Reported problems; landlord acknowledgement and reply','Shared issue status and in-app notification']],[CW*.30,CW*.36,CW*.34])
para('Success is assessed through working task flows, calculation/access checks and responsive layouts. Automated checks support functionality; they do not replace observation of ordinary users.','small')

new('3.1 Access and role dashboards','User manual · 1 of 5')
para('Open the application link in a browser. Choose <b>Get started</b>, select Landlord or Tenant, then log in with your own email and password. A new landlord creates an account. A new tenant uses the private invitation supplied by their landlord; they do not choose a room during registration.')
picture('simple-landlord-home.png','Figure 1. Landlord home: confirmed rent, rent still due, rooms and the main management links.',crop=(270,245,1400,765),maxh=220)
para('<b>1.</b> Choose the month. <b>2.</b> Read Rent received, Rent still due and Available rooms. <b>3.</b> Use My properties, My tenants or Payment records. Pending payments appear for checking when present.')
# Phone view and explanatory text share a row.
rowtop=y
picture('simple-tenant-home-phone.png','Figure 2. Tenant home on a phone.',maxh=245,width=145,x=M)
phonebottom=y;y=rowtop
para('<b>4. Tenant view.</b> Check the assigned property/room, selected month and rent still due. A zero balance means no remaining rent for that selected month; check the monthly account for other months.',x=M+165,width=CW-165)
para('<b>5.</b> Select Record payment to report money already paid. Security deposit, Payment history, Monthly rental account and Rental details provide the supporting records.',x=M+165,width=CW-165)
para('<b>6.</b> Use the phone menu for navigation. The bell opens Notifications; Account provides Edit profile, Change password and Logout.',x=M+165,width=CW-165)
y=min(y,phonebottom)
para('Screenshot note: the illustrated manual uses release 1.4.0 and isolated demonstration accounts. Values are examples, not real transactions; dates and amounts vary between task captures. Detail crops improve readability. Test clocks were advanced for deadline behaviour.','small')

new('3.2 Properties, rooms and onboarding','User manual · 2 of 5')
para('<b>1.</b> Landlord: open My properties → Add property. Enter the address, room count, default monthly rent and separate security deposit; save. Under Room rent, select larger rooms and save a custom monthly amount. Other rooms retain the default for new tenancies.')
picture('room-availability.png','Figure 3. Property room availability: the landlord assigns an available room.',crop=(280,55,1390,575),maxh=220)
para('<b>2.</b> Choose Add tenant record, select the property and an available room, and enter the tenant’s name/contact details and actual move-in date. Check the separate first-rent and deposit amounts before saving.')
picture('onboard-tenant.png','Figure 4. Move-in cost preview: first rent and the one-off deposit are itemised before saving.',crop=(530,640,1145,915),maxh=220)
para('<b>3.</b> Open the rental’s Invite this tenant section, copy the private JOIN invitation and share it privately. The tenant creates their own login using that invitation. Existing rental history remains linked; a public property code cannot assign a room.')
para('<b>4.</b> To record GPS coordinates, open the property and choose Capture current location while at the property. Allow browser permission. Location capture needs HTTPS; entering a street address does not itself capture GPS coordinates.','small')

new('3.3 Record rent and confirm receipt','User manual · 3 of 5')
para('<b>1.</b> Pay the landlord through the usual cash or banking arrangement. In the tenant account, select Record payment and keep Payment for set to Rent. Enter the amount, payment method, date and the rent month. Bank methods require the payment reference.')
picture('plain-payment-tenant.png','Figure 5. Rent-entry detail: amount, method, date and rent month; advance months are available.',crop=(455,230,1215,690),maxh=300)
para('<b>2.</b> Check the month amount; use Paying for another month? Add it only when the same payment covers several months. Optional payment details let you name another payer. Submit payment. The report remains <b>Pending</b>, so it does not yet reduce confirmed rent owed.')
picture('plain-payment-landlord.png','Figure 6. Landlord checking the reported payment before confirming money received.',crop=(455,735,1215,845),maxh=90)
para('<b>3.</b> Landlord: open the pending payment from the dashboard or Payment records. Check actual cash received or your bank record. Check the amount and months, tick the receipt confirmation and choose Confirm received. A mistaken report can instead be rejected with an explanation. Never confirm only because a tenant submitted a report.')

new('3.4 Receipts, history and deposit','User manual · 4 of 5')
para('<b>1.</b> Open Payment history / Payment records. Select the month and All, Pending, Confirmed or Rejected. Open a confirmed payment to see the months covered and its receipt. Use Download / share receipt or Print / save PDF.')
picture('confirmed-payment.png','Figure 7. Receipt detail: rent month, amount, method, date and download/share controls.',crop=(300,305,1050,705),maxh=200)
para('<b>2.</b> Open Monthly rental account to review charges and payments across months, earlier unpaid rent and credit not yet assigned to a month. A payment for December should cover December; it must not erase an unrelated November balance.')
picture('deposit-report-tenant.png','Figure 8. A separate tenant deposit report; it is not treated as monthly rent.',crop=(455,420,1215,805),maxh=200)
para('<b>3.</b> To report a deposit, choose Record payment → Payment for → Security deposit (or the deposit link in Rental details). Enter the actual amount/date/method and send it. The landlord checks and confirms the deposit separately. New-tenancy deposits are due once within ten days of move-in; unpaid amounts trigger in-app reminders.')
para('<b>4.</b> A pending deposit report waits for review, rather than asking the tenant to pay that reported amount again. At move-out, the landlord records a return or a supported deduction and its reason. Damage does not automatically remove the entire deposit.','small')

new('3.5 Problems, notices and move-out','User manual · 5 of 5')
para('<b>1.</b> Tenant: select Report a problem / account query. Enter where the problem is and describe it, then Send issue. Report matters such as a shared leaking tap, broken gate or a missing payment record. A report does not automatically decide who must pay for damage.')
picture('report-followup.png','Figure 9. Landlord acknowledgement and follow-up: the tick and updates are visible to both parties.',crop=(405,80,1260,610),maxh=245)
para('<b>2.</b> Landlord: open Tenant reports and tick Noted by landlord to acknowledge receipt. Use Reply / send update. Keep an individual issue private; choose a property-wide update only for information relevant to everyone. Mark resolved when the issue has been addressed.')
picture('deposit-reminder-tenant.png','Figure 10. Deposit deadline warning in the tenant dashboard; report payment only if already paid.',crop=(290,510,1385,640),maxh=90)
para('<b>3.</b> Open the bell / Notifications to read messages and mark them as read. Enable browser alerts only if wanted. Notices remain in the account; browser alerts operate while the app is open. These are not SMS or remote push messages.')
para('<b>4.</b> Landlord: use Rental details → Monthly rent for an agreed future rent change; dated changes stay listed. Under Move-out, record actual room/key return. The room becomes available for a new tenancy from the following day; unpaid balances and deposit records are retained.')
para('<b>Mobile features:</b> responsive phone navigation, permission-based geolocation, in-app notices, optional active-browser alerts and PDF download/share. This submission documents a responsive web implementation; native Android delivery and background push have not been demonstrated.','small')

new('A1. Structure and role navigation','Code appendix · 1 of 4')
para('The source is organised by feature and role. main.dart initialises Supabase; app.dart handles sessions and application routing. Screens present tasks, data/ holds state and accounting, models/ defines records and services/ handles receipts, alerts and authentication callbacks.')
structure='''lib/
  main.dart / app.dart
  screens/
    auth/          login, registration, password reset
    landlord/      landlord home and tenant list
    tenant/        tenant home
    shared/        navigation, profile and common UI
    properties/    property setup, room rent, availability
    payments/      rent/deposit reports and confirmation
    rentals/       rental details, reports, deposit, move-out
  data/            store, cloud gateway, ledger calculations
  models/          account, property, tenancy, payment
  services/        receipts, alerts and auth callbacks
  ui/              theme and reusable visual components
supabase/migrations/   server rules and row-level security
test/ and tool/        automated checks and release tools'''
for line in structure.splitlines():
 c.setFillColor(INK);c.setFont('Mono',8.6);c.drawString(M+7,y,line);y-=12
 y-=0
y-=14
code('lib/screens/shared/dashboard.dart',14,26,'A1.1 Select the signed-in role')
para('StoreScope gives the widget the current account. A missing account renders an empty scaffold; otherwise the enum selects the correct dashboard. Each role page is an independent Dart library. UI routing improves usability, but it is not the security boundary: database checks must also restrict access (Supabase, n.d.).')
heading('A1.2 State and interaction')
para('StoreScope is an InheritedNotifier for AppStore. A saved action refreshes the shared snapshot, allowing related screens to display updated records. The same navigation and visual components are reused across role pages. Short task labels, a visible pending state and optional detail sections apply consistency, feedback and reduced memory-load principles from the supplied HCI slides (APT41P2 teaching materials, n.d.).')

new('A2. Financial calculations and rooms','Code appendix · 2 of 4')
code('lib/data/research_ledger.dart',69,75,'A2.1 Calendar-day first rent')
para('Amounts are integer cents, avoiding repeated floating-point money rounding. DateTime(year, month + 1, 0) gives the last day of the month. occupied includes the move-in date. Integer arithmetic rounds the final charge once, rather than rounding a daily rate first.')
table([['WORKED EXAMPLE','RESULT'],['Monthly rent R1,500; January has 31 days; move-in 15 January','31 − 15 + 1 = 17 occupied days'],['R1,500 × 17 ÷ 31','First rent R822.58'],['Separate deposit R2,000','Total initial charges R2,822.58; deposit deadline tracked separately'],['From the following full month','R1,500 rent due on the 1st']],[CW*.55,CW*.45])
code('lib/data/room_availability.dart',11,28,'A2.2 Prevent assigning an occupied room')
para('The helper filters tenancies for the selected property and builds a set of blocked room numbers. Actual room return, not a planned departure date, determines availability. The save operation also checks availability on the server, protecting against two sessions selecting the same room. Room-specific rent is copied into new tenancy terms; changing a default does not silently rewrite an existing tenant’s agreed rent.')

new('A3. Payment validation and storage','Code appendix · 3 of 4')
code('lib/screens/payments/payment_entry.dart',104,125,'A3.1 Validate month amounts and receipt confirmation')
para('Each non-zero month amount becomes one allocation. Duplicate months are rejected. The sum cannot exceed the actual payment amount. A landlord must explicitly confirm receipt; the tenant does not get this checkbox. These checks prevent a payment from being counted twice or a report from being mistaken for verified funds.')
code('lib/data/cloud_gateway.dart',29,42,'A3.2 Send the operation and refresh shared records')
para('CloudGateway calls bp_action through Supabase RPC and refreshes the snapshot after success. If saving succeeds but refresh fails, the user is told to refresh before retrying. Supabase Auth handles authentication; passwords are not stored in rental records (Supabase, n.d.).')
new('A4. Deposit follow-up and access','Code appendix · 4 of 4')
code('lib/data/deposit_reminders.dart',63,88,'A4.1 Due date, pending reports and reminders')
para('For a new tenancy, the deadline is actual move-in plus ten calendar days; explicit legacy agreements are preserved by the earlier branch. The warning becomes eligible on the deadline itself. Pending reports are not confirmed receipts, but their value is subtracted from the amount a tenant is asked to report/pay again. Ended or zero-deposit tenancies are excluded earlier in the function.')
heading('A4.2 Server permissions')
para('PostgreSQL row-level security is enabled for rental tables. A tenant can read their linked tenancy; the owning landlord can read and manage their property’s records. The notices policy restricts reads to the recipient. Server functions also check permission before mutation, so hiding a screen is not the only protection (Supabase, n.d.).')
# Exact SQL lines selected by content, retaining actual source for reproducibility.
files=sorted((ROOT/'supabase/migrations').glob('202610*.sql'))
for f in files:
 lines=f.read_text().splitlines()
 match=next((i for i,l in enumerate(lines,1) if 'create policy bp_notice_read ' in l),None)
 if match:
  code(str(f.relative_to(ROOT)),match,match,'A4.3 Recipient-only notice policy');break
heading('A4.4 Verification and limits')
para('Release 1.4.0 passed 84 Flutter tests and static analysis across 67 Dart files with zero issues. Additional navigation/session checks passed. A Chromium journey with a simulated Supabase transport covered assigned-room signup, room rates, rent confirmation, advance rent, receipts, deposit warnings/confirmation, issues and account recovery. These checks do not prove live email delivery, native-device behaviour, user satisfaction or production load capacity (Nkambule, 2026).','small')

new('References','Sources and implementation evidence')
refs=[
'Application Technology IV teaching materials (n.d.) <i>Supplied HCI lecture slides: Chapters 1–3 (Part 1), 5–7, 9 (Part 1), 12 and 13.</i> Learning, memory, interaction, navigation, usability rules, evaluation and stakeholder context. Chapter 12’s internal title refers to Chapter 21: Hypertext, multimedia and the WWW.',
'Department of Business and Application Development (2026) <i>Application Technology IV (APT41P2): Project Guidelines 2026.</i> Supplied assignment brief and marking guide. Presentation arrangements follow the later class message supplied by the student.',
'Flutter (n.d.) <i>Flutter documentation.</i> Available at: <link href="https://docs.flutter.dev/" color="#805A12">https://docs.flutter.dev/</link> (official reference for widgets, state and responsive user interfaces).',
'Supabase (n.d.) <i>Auth documentation.</i> Available at: <link href="https://supabase.com/docs/guides/auth" color="#805A12">https://supabase.com/docs/guides/auth</link>.',
'Supabase (n.d.) <i>Row Level Security.</i> Available at: <link href="https://supabase.com/docs/guides/database/postgres/row-level-security" color="#805A12">supabase.com/docs/guides/database/postgres/row-level-security</link>.',
'Baseflow (n.d.) <i>geolocator: Flutter geolocation package.</i> Available at: <link href="https://pub.dev/packages/geolocator" color="#805A12">https://pub.dev/packages/geolocator</link>.',
'pdf and printing package contributors (n.d.) <i>Dart PDF generation and Flutter printing/sharing.</i> Available at: <link href="https://pub.dev/packages/pdf" color="#805A12">https://pub.dev/packages/pdf</link> and <link href="https://pub.dev/packages/printing" color="#805A12">https://pub.dev/packages/printing</link>.',
'Republic of South Africa (1999) <i>Rental Housing Act 50 of 1999.</i> Available at: <link href="https://www.gov.za/sites/default/files/gcis_document/201409/a50-99.pdf" color="#805A12">gov.za: Rental Housing Act 50 of 1999</link>. Used for the distinction between rental security and automatic forfeiture; this project does not certify legal compliance.',
f'Nkambule, M. (2026) <i>BackyardPay source code, release 1.4.0, commit 87ce034.</i> Available at: <link href="{GITHUB}/tree/87ce034" color="#805A12">GitHub: BackyardPay release source</link>. See docs/PROJECT-STRUCTURE.md, docs/design/USABILITY-REVIEW.md and docs/releases/1.4.0-simple-dashboards.md for structure, design rationale and checks.'
]
for i,r in enumerate(refs,1):para(f'{i}. {r}',after=11)
heading('Evidence provenance')
para('The supplied screenshots show the deployed application with landlord and tenant accounts. Manual figures in this portfolio were captured from the same release using isolated demonstration accounts and a simulated backend; timestamps can reflect an advanced test clock. No real bank transfer, new local interview study or native Android test is claimed. The code excerpts are copied from the submitted repository, with file paths and source line numbers.','small')
assert page==13,page
c.save()
print(OUT)
