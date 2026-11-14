from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
src=Path('docs/PROJECT_REPORT.md').read_text(encoding='utf-8-sig').splitlines()
doc=Document(); sec=doc.sections[0]; sec.top_margin=Inches(.7); sec.bottom_margin=Inches(.7); sec.left_margin=Inches(.78); sec.right_margin=Inches(.78)
styles=doc.styles
styles['Normal'].font.name='Aptos'; styles['Normal'].font.size=Pt(9.5); styles['Normal'].font.color.rgb=RGBColor(35,48,67)
for name,size,color in [('Title',27,'123047'),('Heading 1',18,'123047'),('Heading 2',13,'087F5B'),('Heading 3',11,'087F5B')]:
 st=styles[name]; st.font.name='Aptos Display'; st.font.size=Pt(size); st.font.bold=True; st.font.color.rgb=RGBColor.from_string(color)
# Header/footer
header=sec.header.paragraphs[0]; header.text='LINUX SYSTEM ADMINISTRATION  •  SMART CITY COMMAND CENTRE'; header.style='Caption'
footer=sec.footer.paragraphs[0]; footer.alignment=WD_ALIGN_PARAGRAPH.CENTER; footer.add_run('SEE 2026  •  Prepared project report — complete evidence fields before submission')
i=0; in_code=False; code=[]
while i<len(src):
 line=src[i]
 if line.startswith('```'):
  if not in_code: in_code=True; code=[]
  else:
   p=doc.add_paragraph(); p.paragraph_format.left_indent=Inches(.2); p.paragraph_format.space_after=Pt(5)
   r=p.add_run('\n'.join(code)); r.font.name='Consolas'; r.font.size=Pt(8); r.font.color.rgb=RGBColor(35,58,75); in_code=False
  i+=1; continue
 if in_code: code.append(line); i+=1; continue
 if line.startswith('|'):
  rows=[]
  while i<len(src) and src[i].startswith('|'):
   cells=[x.strip() for x in src[i].strip('|').split('|')]
   if not all(set(x)<=set('-: ') for x in cells): rows.append(cells)
   i+=1
  if rows:
   cols=max(map(len,rows)); table=doc.add_table(rows=0, cols=cols); table.style='Light Shading Accent 1'; table.alignment=WD_TABLE_ALIGNMENT.CENTER
   for ri,row in enumerate(rows):
    cells=table.add_row().cells
    for ci in range(cols):
     cells[ci].vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
     text=row[ci] if ci<len(row) else ''
     p=cells[ci].paragraphs[0]; p.paragraph_format.space_after=Pt(1); rr=p.add_run(text); rr.font.size=Pt(8); rr.bold=(ri==0)
   doc.add_paragraph().paragraph_format.space_after=Pt(2)
  continue
 if not line.strip(): i+=1; continue
 if line.startswith('> '):
  p=doc.add_paragraph(); p.paragraph_format.left_indent=Inches(.18); rr=p.add_run(line[2:].replace('**','')); rr.italic=True; rr.font.color.rgb=RGBColor(120,76,15); i+=1; continue
 if line.startswith('# '):
  title=line[2:]; p=doc.add_paragraph(style='Title' if i<2 else 'Heading 1'); p.add_run(title); i+=1; continue
 if line.startswith('## '): doc.add_paragraph(line[3:],style='Heading 1'); i+=1; continue
 if line.startswith('### '): doc.add_paragraph(line[4:],style='Heading 2'); i+=1; continue
 if line.startswith('- '):
  p=doc.add_paragraph(style='List Bullet'); p.paragraph_format.space_after=Pt(2); p.add_run(line[2:].replace('**','').replace('`','')); i+=1; continue
 if line[:1].isdigit() and '. ' in line[:4]:
  p=doc.add_paragraph(style='List Number'); p.add_run(line.split('. ',1)[1].replace('**','').replace('`','')); i+=1; continue
 p=doc.add_paragraph(); p.paragraph_format.space_after=Pt(5); p.add_run(line.replace('**','').replace('`','')); i+=1
out=Path('docs/PROJECT_REPORT.docx'); doc.save(out); print(out, out.stat().st_size)
