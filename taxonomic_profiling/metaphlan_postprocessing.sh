#!/bin/bash

# Define other parameters
export path_input="/home/povp/Projects/kompas/metaphlan/"
export path_output="/home/povp/Projects/kompas/metaphlan/"
export path_project_dir="/home/povp/Projects/kompas/"
export MP_VERSION="vJun25"
export project_name="KOMPAS"

python custom_merge_metaphlan_tables.py --col_type "relative_abundance" ${path_input}/*_map${MP_VERSION}.tsv > ${path_output}/${project_name}_abundance_table.tsv
python custom_merge_metaphlan_tables.py --col_type "estimated_number_of_reads_from_the_clade" ${path_input}/*_map${MP_VERSION}.tsv > ${path_output}/${project_name}_counts_table.tsv

grep -E "s__|clade" ${path_output}/${project_name}_abundance_table.tsv \
| grep -v "t__" \
| sed "s/^.*|//g" \
| sed "s/clade_name/body_site/g" \
| sed "s/SRS[0-9]*-//g" \
> ${path_output}/${project_name}_abundance_table_species.tsv

grep -E "s__|clade" ${path_output}/${project_name}_counts_table.tsv \
| grep -v "t__" \
| sed "s/^.*|//g" \
| sed "s/clade_name/body_site/g" \
| sed "s/SRS[0-9]*-//g" \
> ${path_output}/${project_name}_counts_table_species.tsv