#!/bin/bash

mkdir -p /staging/Dragen_Dev/results/RSA_RP82_S7
mkdir -p /staging/Dragen_Dev/results/RSA_RP_83_S8

# dragen -f \
# 	-r /staging/human/reference/hg19/hg19.fa.k_21.f_16.m_149 \
# 	-1 /staging/Dragen_Dev/data/FASTQ/RSA_RP82_S7_L004_R1_001.fastq.gz \
# 	-2 /staging/Dragen_Dev/data/FASTQ/RSA_RP82_S7_L004_R2_001.fastq.gz \
# 	--enable-variant-caller true \
# 	--RGID Illumina_RGID \
# 	--RGSM RSA_RP82_S7 \
# 	--output-directory /staging/Dragen_Dev/results/RSA_RP82_S7 \
# 	--output-file-prefix RSA_RP82_S7 \
# 	--vc-hard-filter="SNP filter:snp:QD < 2.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0; INDEL filter:indel:QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0"

dragen -f \
	-r /staging/human/reference/hg19/hg19.fa.k_21.f_16.m_149 \
	-1 /staging/Dragen_Dev/data/FASTQ/RSA_RP_83_S8_L003_R1_001.fastq.gz \
	-2 /staging/Dragen_Dev/data/FASTQ/RSA_RP_83_S8_L003_R2_001.fastq.gz \
	--enable-variant-caller true \
	--RGID Illumina_RGID \
	--RGSM RSA_RP_83_S8 \
	--output-directory /staging/Dragen_Dev/results/RSA_RP_83_S8 \
	--output-file-prefix RSA_RP_83_S8 \
	--vc-hard-filter "SNP filter:snp:QD < 2.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0; INDEL filter:indel:QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0"
