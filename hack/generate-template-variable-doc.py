#!/usr/bin/env python3

import json
import os
import re

whereami = os.path.abspath(__file__)
os.chdir(os.path.dirname(whereami))

boundary = '<!-- template-variable-table-boundary -->'

def update_doc(doc: str, template_path: str) -> str:
    with open(template_path) as template_file:
        template = json.load(template_file)

    all_vars = {}
    for var in template['variables']:
        all_vars[var] = None

    table_pattern = f"{boundary}([\\S\\s]*){boundary}"

    existing_table_matches = re.search(table_pattern, doc)
    if existing_table_matches is None:
        raise Exception("empty match for table pattern")
    existing_table_lines = existing_table_matches.group(1).splitlines()

    new_table_lines = [
        '| Variable | Description |',
        '| - | - |',
    ]

    existing_descriptions = {}
    for line in existing_table_lines[3:]:
        columns = line.split('|')
        var = columns[1].strip(" `")
        existing_descriptions[var] = columns[2].strip(" `")

    for var, val in all_vars.items():
        if val is not None:
            if val == "":
                val = "`\"\"`"
            else:
                val = f"```{val}```"
        else:
            val = "*None*"
        description = ""
        if var in existing_descriptions:
            description = existing_descriptions[var]
        new_table_lines.append(f"| `{var}` | {description} |")

    new_doc = re.sub(table_pattern, "\n".join([boundary, *new_table_lines, boundary]), doc)
    return new_doc

for template in ['al2', 'al2023']:
    doc_file_name = f'../doc/usage/{template}.md'
    with open(doc_file_name) as doc_file:
        doc = doc_file.read()
        doc = update_doc(doc, f'../templates/{template}/template.json')
    with open(doc_file_name, 'w') as doc_file:
        doc_file.write(doc)
