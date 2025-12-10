#!/usr/bin/env python

import gzip
from pathlib import Path
import argparse

parser = argparse.ArgumentParser(description="Filter variants from Nirvana JSON output based on gnomAD allele frequency.")
parser.add_argument("json_path", type=str, help="Path to the Nirvana JSON output file (.json.gz)")
args = parser.parse_args()

json_path = Path(args.json_path)

# Read Nirvana JSON output by lines

header = ''
positions = []
genes = []
is_header_line = True
is_position_line = False
is_gene_line = False
gene_section_line = '],"genes":['
end_line = ']}'
with gzip.open(json_path, 'rt') as f:
    position_count = 0
    gene_count = 0
    for line in f:
        trim_line = line.strip()
        if is_header_line:
            ## only keep the "header" field content from the line
            header = trim_line[10:-14]
            is_header_line = False
            is_position_line = True
            continue
        if trim_line == gene_section_line:
            is_gene_line = True
            is_position_line = False
            continue
        elif trim_line == end_line:
            break
        else:
            if is_position_line:
                ## remove the trailing ',' if there is
                positions.append(trim_line.rstrip(','))
                position_count += 1
            if is_gene_line:
                ## remove the trailing ',' if there is
                genes.append(trim_line.rstrip(','))
                gene_count += 1

print('header object:', header)
print('number of positions:', position_count)
print('number of genes:', gene_count)

# Retrieve variants under a gnomAD allele frequency threshold

import pandas as pd
import json

variants_field = 'variants'
gnomad_field = 'gnomad'
freq_threshold = 0.0001
freq_data = {'variant_id': [], 'gnomAD_allele_freq': []}
for position in positions:
    position_dict = json.loads(position)
    if variants_field in position_dict:
        for variant_dict in position_dict[variants_field]:
            if gnomad_field in variant_dict:
                freq = variant_dict[gnomad_field]['allAf']
                if freq < freq_threshold:
                    freq_data['variant_id'].append(variant_dict['vid'])
                    freq_data['gnomAD_allele_freq'].append(freq)

freq_df = pd.DataFrame(data=freq_data)
freq_df

# Retrieve all relevant genes and their OMIM gene names

gene_data = {'gene': [], 'OMIM_gene_name': []}
for gene in genes:
    gene_dict = json.loads(gene)
    gene_data['gene'].append(gene_dict['name'])
    omim_gene_name = ''
    if 'omim' in gene_dict:
        omim_dict = gene_dict['omim'][0]
        if 'geneName' in omim_dict:
            omim_gene_name = omim_dict['geneName']
    gene_data['OMIM_gene_name'].append(omim_gene_name)

gene_df = pd.DataFrame(data=gene_data)
gene_df

# Retrieve variants under a gnomAD allele frequency threshold

import pandas as pd
import json

variants_field = 'variants'
gnomad_field = 'gnomad'
transcripts_field = 'transcripts'
freq_threshold = 0.0001
freq_data = {'variant_id': [], 'gnomAD_allele_freq': [], 'transcripts': []}
for position in positions:
    position_dict = json.loads(position)
    if variants_field in position_dict:
        for variant_dict in position_dict[variants_field]:
            if gnomad_field in variant_dict and transcripts_field in variant_dict:
                freq = variant_dict[gnomad_field]['allAf']
                if freq < freq_threshold:
                    freq_data['variant_id'].append(variant_dict['vid'])
                    freq_data['gnomAD_allele_freq'].append(freq)
                    freq_data['transcripts'].append(variant_dict['transcripts'])

freq_df2 = pd.DataFrame(data=freq_data)

df_exploded = freq_df2.explode('transcripts')
df_unnested = pd.json_normalize(df_exploded['transcripts']).set_index(df_exploded['variant_id']).reset_index()

df_unnested.to_csv("variants_under_gnomad_0001.csv")
