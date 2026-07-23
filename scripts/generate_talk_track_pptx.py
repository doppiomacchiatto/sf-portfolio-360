from pptx import Presentation
from pptx.util import Pt
from pptx.dml.color import RGBColor


OUT = "docs/PM_Executive_Talk_Track_Callisto.pptx"

TITLE_COLOR = RGBColor(0x0F, 0x1F, 0x3D)
ACCENT_COLOR = RGBColor(0x34, 0x98, 0xDB)
BODY_COLOR = RGBColor(0x1A, 0x27, 0x45)
BG_COLOR = RGBColor(0xED, 0xF4, 0xFB)


def add_title_and_bullets(prs, title, bullets):
    slide = prs.slides.add_slide(prs.slide_layouts[1])
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = BG_COLOR

    title_shape = slide.shapes.title
    title_shape.text = title
    title_run = title_shape.text_frame.paragraphs[0].runs[0]
    title_run.font.color.rgb = ACCENT_COLOR
    title_run.font.size = Pt(34)
    title_run.font.bold = True

    body = slide.shapes.placeholders[1].text_frame
    body.clear()
    for i, item in enumerate(bullets):
        p = body.paragraphs[0] if i == 0 else body.add_paragraph()
        p.text = item
        p.level = 0
        p.font.size = Pt(24)
        p.font.color.rgb = BODY_COLOR


prs = Presentation()
prs.slide_width = prs.slide_width  # keep default 16:9

# Cover
cover = prs.slides.add_slide(prs.slide_layouts[0])
cover.background.fill.solid()
cover.background.fill.fore_color.rgb = BG_COLOR
cover.shapes.title.text = "PM Executive - Portfolio Command Center"
cover_title = cover.shapes.title.text_frame.paragraphs[0].runs[0]
cover_title.font.color.rgb = TITLE_COLOR
cover_title.font.size = Pt(44)
cover_title.font.bold = True
subtitle = cover.placeholders[1]
subtitle.text = "Use case: Executive leadership needs a single, reliable view of R&D portfolio performance."
sub_run = subtitle.text_frame.paragraphs[0].runs[0]
sub_run.font.color.rgb = ACCENT_COLOR
sub_run.font.size = Pt(22)

add_title_and_bullets(
    prs,
    "Problem Statement",
    [
        "Portfolio signals are fragmented across teams and objects.",
        "Leaders cannot quickly assess if funding aligns to mission priorities.",
        "Need-to-prototype and transition bottlenecks are hard to identify early.",
        "Existing reports are reactive instead of decision-ready.",
    ],
)

add_title_and_bullets(
    prs,
    "What PM Executive Delivers",
    [
        "One KPI-driven command center for investment, speed, transition, and operations.",
        "Pipeline visibility from ideation through demo and transition.",
        "Executive scorecards for cycle time, conversion rate, and operational index.",
        "Unified experience across app and LWR site.",
    ],
)

add_title_and_bullets(
    prs,
    "60-Second Talk Track",
    [
        "PM Executive gives leadership a real-time portfolio command center.",
        "Pipeline phases show where programs are concentrated.",
        "Scorecards highlight active programs, mission-to-funded cycle time,",
        "award-to-prototype time, transition conversion, and operational index.",
        "This replaces disconnected reporting with rapid, confident decisions.",
    ],
)

add_title_and_bullets(
    prs,
    "Business Value",
    [
        "Faster executive decision cycles.",
        "Improved portfolio transparency.",
        "Better transition confidence from prototype to mission use.",
        "Stronger alignment across executive stakeholders.",
    ],
)

add_title_and_bullets(
    prs,
    "Executive Demo Flow",
    [
        "1) Log in as Brian Smith (PM_Executive).",
        "2) Open PM Executive app and review Program Home pipeline + scorecards.",
        "3) Open LWR site /titanx and run interactive banner walkthrough:",
        "   - Active Programs -> Transition Focus -> Reset Filters.",
        "   - Click pipeline phase tile, show Drill + Clear Drill.",
        "   - Open KPI Drill (Speed/Transition), then close deep-dive drawer.",
        "   - In Open KPI Watches, filter severity and click Impacted programs.",
        "4) Highlight Portfolio Events: Sign up for Beta Testing for Titan.",
        "5) Close with governance message: proactive portfolio management with",
        "   real-time interactive oversight.",
    ],
)

prs.save(OUT)
print(f"Created {OUT}")
