#!/usr/bin/env python3

import json
import os
import re

whereami = os.path.abspath(__file__)
os.chdir(os.path.dirname(whereami))

doc_file_name = '../doc/USER_GUIDE.md'
al2_boundary = '<!-- template-variable-table-boundary-al2 -->'
al2023_boundary = '<!-- template-variable-table-boundary-al2023 -->'

def update_doc(doc: str, boundary: str, template_path: str) -> str:
    with open(template_path + '/1.28/template.json') as template_file:
        template = json.load(template_file)

    with open(template_path + '/1.28/variables.json') as default_var_file:
        default_vars = json.load(default_var_file)

    all_vars = {}
    for var in template['variables']:
        all_vars[var] = None
    for var, default_val in default_vars.items():
        all_vars[var] = default_val

    table_pattern = f"{boundary}([\\S\\s]*){boundary}"

    existing_table_matches = re.search(table_pattern, doc)
    if existing_table_matches is None:
        raise Exception("empty match for table pattern")
    existing_table_lines = existing_table_matches.group(1).splitlines()

    new_table_lines = [
        '| Variable | Default value | Description |',
        '| - | - | - |',
    ]

    existing_descriptions = {}
    for line in existing_table_lines[3:]:
        columns = line.split('|')
        print(columns)
        var = columns[1].strip(" `")
        existing_descriptions[var] = columns[3].strip(" `")

    for var, val in all_vars.items():
        if val is not None:
            if val == "":
                val = f"`\"\"`"
            else:
                val = f"```{val}```"
        else:
            val = "*None*"
        description = ""
        if var in existing_descriptions:
            description = existing_descriptions[var]
        new_table_lines.append(f"| `{var}` | {val} | {description} |")

    new_doc = re.sub(table_pattern, "\n".join([boundary, *new_table_lines, boundary]), doc)
    return new_doc


with open(doc_file_name) as doc_file:
    doc = doc_file.read()

doc = update_doc(doc, al2_boundary, '../templates/al2')
doc = update_doc(doc, al2023_boundary, '../templates/al2023')

with open(doc_file_name, 'w') as doc_file:
    doc_file.write(doc)

