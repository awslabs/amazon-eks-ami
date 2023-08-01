#!/usr/bin/env python3

import json
import os
import re

whereami = os.path.abspath(__file__)
os.chdir(os.path.dirname(whereami))

template = {}
with open('../eks-worker-al2.json') as template_file:
    template = json.load(template_file)

default_vars = {}
with open('../eks-worker-al2-variables.json') as default_var_file:
    default_vars = json.load(default_var_file)

all_vars = {}

for var in template['variables']:
    all_vars[var] = None
for var, default_val in default_vars.items():
    all_vars[var] = default_val

doc_file_name = '../doc/USER_GUIDE.md'
doc = None
with open(doc_file_name) as doc_file:
    doc = doc_file.read()

table_boundary = '<!-- template-variable-table-boundary -->'
existing_table_pattern = f"{table_boundary}([\S\s]*){table_boundary}"
existing_table_matches = re.search(existing_table_pattern, doc)
existing_table_lines = existing_table_matches.group(1).splitlines()

new_table = f"{table_boundary}\n"
new_table += f"{existing_table_lines[1]}\n"
new_table += f"{existing_table_lines[2]}\n"

existing_descriptions = {}
for line in existing_table_lines[3:]:
    columns = line.split('|')
    var = columns[1].strip(" `")
    existing_descriptions[var] = columns[3].strip(" `")

for var, val in all_vars.items():
    if val is not None:
        if val == "":
            val = f"`\"\"`"
        else:
            val = f"```{default_val}```"
    description = ""
    if var in existing_descriptions:
        description = existing_descriptions[var]
    new_table += f"| `{var}` | {val} | {description} |\n"

new_table += table_boundary

replace_doc_pattern = f"{table_boundary}[\S\s]*{table_boundary}"
new_doc = re.sub(replace_doc_pattern, new_table, doc)

with open(doc_file_name, 'w') as doc_file:
    doc_file.write(new_doc)
