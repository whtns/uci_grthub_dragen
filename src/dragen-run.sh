#!/usr/bin/env bash
set -euo pipefail

VC_FILTER_DEFAULT='SNP filter:snp:QD < 2.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0; INDEL filter:indel:QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0'

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Generalized driver for running DRAGEN on multiple samples.

Options:
  --reference PATH        Reference fasta (required)
  --input-dir PATH        Directory where FASTQ files live (optional when sample file contains full paths)
  --sample-file PATH      CSV file with lines: sample,R1,R2  (R1/R2 may be basenames or full paths)
  --output-base PATH      Base output directory (required)
  --rgid STR              Read group ID (default: Illumina_RGID)
  --vc-filter STR         Variant-caller hard filter string
  --enable-variant-caller true|false  (default: true)
  --dry-run               Print commands but do not execute
  --create-only           Only create output directories and print commands (do not run DRAGEN)
  -h, --help              Show this help

Examples:
  $(basename "$0") --reference /path/ref.fa --input-dir /data/fastq --sample-file samples.csv --output-base results

Sample file format:
  CSV with either 3 columns: sample,R1,R2  (R1/R2 can be basenames or full paths)
  Lines starting with # are ignored.

EOF
}

# defaults
INPUT_DIR=""
SAMPLE_FILE=""
REFERENCE="/staging/human/reference/hg19/hg19.fa.k_21.f_16.m_149"
OUTPUT_BASE=""
RGID="Illumina_RGID"
VC_FILTER="$VC_FILTER_DEFAULT"
ENABLE_VC=true
DRY_RUN=false
CREATE_ONLY=false
# Nirvana annotation defaults (override via environment if needed)
NIRVANA_BIN="/opt/edico/share/nirvana/Nirvana"
NIRVANA_CACHE="/staging/human/reference/hg19/annotation_data_files/Cache/GRCh37/Both"
NIRVANA_DAT="/staging/human/reference/hg19/annotation_data_files/References/Homo_sapiens.GRCh37.Nirvana.dat"
NIRVANA_SD="/staging/human/reference/hg19/annotation_data_files/SupplementaryAnnotation/GRCh37"

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --reference) REFERENCE="$2"; shift 2;;
        --input-dir) INPUT_DIR="$2"; shift 2;;
        --sample-file) SAMPLE_FILE="$2"; shift 2;;
        --output-base) OUTPUT_BASE="$2"; shift 2;;
        --rgid) RGID="$2"; shift 2;;
        --vc-filter) VC_FILTER="$2"; shift 2;;
        --enable-variant-caller) ENABLE_VC="$2"; shift 2;;
        --dry-run) DRY_RUN=true; shift;;
        --create-only) CREATE_ONLY=true; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1" >&2; usage; exit 1;;
    esac
done

if [ -z "$REFERENCE" ]; then
    echo "--reference is required" >&2
    exit 1
fi
if [ -z "$OUTPUT_BASE" ]; then
    echo "--output-base is required" >&2
    exit 1
fi
if [ -z "$SAMPLE_FILE" ]; then
    echo "--sample-file is required" >&2
    exit 1
fi

run_one() {
    local sample="$1"
    local r1="$2"
    local r2="$3"

    local outdir="$OUTPUT_BASE/$sample"
    mkdir -p "$outdir"

    local prefix="$sample"

    local cmd=(dragen -f \
        -r "$REFERENCE" \
        -1 "$r1" \
        -2 "$r2" \
        --enable-variant-caller "$ENABLE_VC" \
        --RGID "$RGID" \
        --RGSM "$sample" \
        --output-directory "$outdir" \
        --output-file-prefix "$prefix" \
	--remove-duplicates true \
        --vc-hard-filter "$VC_FILTER")

    if [ "$DRY_RUN" = true ] || [ "$CREATE_ONLY" = true ]; then
        printf "DRY: %s\n" "${cmd[*]}"
    else
        echo "Running: ${cmd[*]}"
        "${cmd[@]}"
    fi

    # Attempt to annotate the hard-filtered VCF with Nirvana (if present)
    local vcf="$outdir/${prefix}.hard-filtered.vcf.gz"

    # construct Nirvana command using defaults (these can be overridden via env)
    local nirvana_cmd=("$NIRVANA_BIN" -c "$NIRVANA_CACHE" -r "$NIRVANA_DAT" --sd "$NIRVANA_SD" -i "$vcf" -o "$outdir/${prefix}")

    if [ -x "$NIRVANA_BIN" ] && [ -e "$vcf" ]; then
        if [ "$DRY_RUN" = true ] || [ "$CREATE_ONLY" = true ]; then
            printf "DRY: %s\n" "${nirvana_cmd[*]}"
        else
            echo "Running: ${nirvana_cmd[*]}"
            "${nirvana_cmd[@]}"
        fi
    else
        if [ ! -x "$NIRVANA_BIN" ]; then
            echo "Nirvana binary not found or not executable at $NIRVANA_BIN; skipping Nirvana for $sample" >&2
        elif [ ! -e "$vcf" ]; then
            echo "VCF not found: $vcf; skipping Nirvana for $sample" >&2
        fi
    fi
}

find_fastq_pair() {
    local sample="$1"
    # try to find R1 and R2 by globbing in INPUT_DIR
    local r1match=("$INPUT_DIR/${sample}"*R1*fastq* "$INPUT_DIR/${sample}"*R1*"")
    local r2match=("$INPUT_DIR/${sample}"*R2*fastq* "$INPUT_DIR/${sample}"*R2*"")
    # pick first existing
    local r1=""
    local r2=""
    for f in "${r1match[@]}"; do
        [ -e "$f" ] && { r1="$f"; break; }
    done
    for f in "${r2match[@]}"; do
        [ -e "$f" ] && { r2="$f"; break; }
    done
    printf '%s\t%s' "$r1" "$r2"
}

while IFS= read -r line || [ -n "$line" ]; do
    # skip comments and blank
    line_trimmed="${line%%#*}"
    line_trimmed="$(echo "$line_trimmed" | tr -d '\r' | sed -e 's/^\s*//' -e 's/\s*$//')"
    [ -z "$line_trimmed" ] && continue

    IFS=',' read -r sample col2 col3 <<< "$line_trimmed"
    sample="$(echo "$sample" | tr -d '"' | sed -e 's/^\s*//' -e 's/\s*$//')"

    r1=""
    r2=""
    if [ -n "${col2:-}" ] && [ -n "${col3:-}" ]; then
        r1="$col2"
        r2="$col3"
        # if not absolute, prefix with INPUT_DIR when provided
        if [[ "$r1" != /* ]] && [ -n "$INPUT_DIR" ]; then
            r1="$INPUT_DIR/$r1"
        fi
        if [[ "$r2" != /* ]] && [ -n "$INPUT_DIR" ]; then
            r2="$INPUT_DIR/$r2"
        fi
    else
        if [ -z "$INPUT_DIR" ]; then
            echo "Cannot infer R1/R2 for sample '$sample' without --input-dir or columns in sample file" >&2
            exit 1
        fi
        # attempt to find
        read -r r1 r2 < <(find_fastq_pair "$sample")
        if [ -z "$r1" ] || [ -z "$r2" ]; then
            echo "Fastq pair not found for sample $sample in $INPUT_DIR" >&2
            exit 1
        fi
    fi

    run_one "$sample" "$r1" "$r2"
done < "$SAMPLE_FILE"

echo "Done."
