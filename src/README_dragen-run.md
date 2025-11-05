# dragen-run.sh

Small generalized wrapper for running DRAGEN over multiple samples.

Features
- Read samples from a CSV file (sample,R1,R2) or infer FASTQ files from an input directory.
- Create output directories per-sample.
- Dry-run and create-only modes to inspect commands without running DRAGEN.

Basic usage

1. Create a `samples.csv` file. Example formats:

3-column CSV (preferred):

sample,R1,R2
RSA_RP_83_S8,RSA_RP_83_S8_L003_R1_001.fastq.gz,RSA_RP_83_S8_L003_R2_001.fastq.gz

1-column CSV + input directory:

sample
RSA_RP_83_S8

2. Run the wrapper:

```bash
./dragen-run.sh --reference /staging/human/reference/hg19/hg19.fa.k_21.f_16.m_149 \
  --input-dir /staging/Dragen_Dev/data/FASTQ \
  --sample-file samples.csv \
  --output-base /staging/Dragen_Dev/results \
  --rgid Illumina_RGID
```

Try the dry-run first:

```bash
./dragen-run.sh --reference /path/ref.fa --input-dir /data/fastq --sample-file samples.csv --output-base /tmp/out --dry-run
```

Notes
- The script prints and runs the DRAGEN command as constructed. It does not attempt to modify the filter string beyond passing it as `--vc-hard-filter`.
- If your FASTQ filenames don't follow a predictable pattern, use the 3-column CSV with explicit R1 and R2 columns.

License: drop-in replacement for local use.

