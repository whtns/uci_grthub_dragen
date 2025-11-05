## Data process 1. Fastq file mapping into bam file
echo "## Run BWA ##" > ${oPath}/${sName}/${sName}_status.txt
${bwaPath} mem -R '@RG\tID:foo\tSM:'${sName}'\tLB:bar\tPL:illumina\tPU:run_std' -t 4 ${shellPath}/reference/hg19/hg19.fasta  ${oPath}/${sName}/${sName}_1_sequence.sheared.txt  ${oPath}/${sName}/${sName}_2_sequence.sheared.txt|${samtoolsPath} view -bS -o ${oPath}/${sName}/${sName}.bam -

mkdir -p ${oPath}/${sName}/BAM
echo "## Run samtools ##"
${samtoolsPath} sort -n  ${oPath}/${sName}/${sName}.bam  ${oPath}/${sName}/BAM/${sName}.sorted
${samtoolsPath} fixmate ${oPath}/${sName}/BAM/${sName}.sorted.bam  ${oPath}/${sName}/BAM/${sName}.matefixed.bam
${samtoolsPath} sort  ${oPath}/${sName}/BAM/${sName}.matefixed.bam  ${oPath}/${sName}/BAM/${sName}.matefixed.sorted



## Data process 2. Bam file dedupping and recalibration
echo "## Run MarkDuplicates ##"
${gatkPath} --java-options "-Xmx8g" MarkDuplicates -I ${oPath}/${sName}/BAM/${sName}.matefixed.sorted.bam -M ${oPath}/${sName}/BAM/${sName}.metrics_file -O ${oPath}/${sName}/BAM/${sName}.rmdup.bam --VALIDATION_STRINGENCY LENIENT --VERBOSITY INFO --COMPRESSION_LEVEL 5 --CREATE_INDEX true --CREATE_MD5_FILE false --ASSUME_SORTED true --REMOVE_DUPLICATES true --TMP_DIR=/tmp
${samtoolsPath} index ${oPath}/${sName}/BAM/${sName}.rmdup.bam

mkdir -p ${oPath}/${sName}/RECALIBRATION
echo "## Run BaseRecalibrator ##"
${gatkPath} --java-options "-Xmx8g" BaseRecalibrator -R ${shellPath}/reference/hg19/hg19.fasta --known-sites ${shellPath}/reference/dbsnp/dbsnp_132.hg19.vcf -I ${oPath}/${sName}/BAM/${sName}.rmdup.bam -O ${oPath}/${sName}/RECALIBRATION/${sName}.recal_data.cvs

echo "## Run ApplyBQSR ##"
${gatkPath} --java-options "-Xmx8g" ApplyBQSR -R ${shellPath}/reference/hg19/hg19.fasta -I ${oPath}/${sName}/BAM/${sName}.rmdup.bam -bqsr ${oPath}/${sName}/RECALIBRATION/${sName}.recal_data.cvs -O ${oPath}/${sName}/RECALIBRATION/${sName}.recal.bam
${samtoolsPath} index ${oPath}/${sName}/RECALIBRATION/${sName}.recal.bam



## Data process 3. Bam file realignment
mkdir -p ${oPath}/${sName}/REALIGNMENT
#Indel realignment is no longer necessary for variant discovery if you plan to use a variant caller that performs a haplotype assembly step, such as HaplotypeCaller or MuTect2.
${samtoolsPath} sort  ${oPath}/${sName}/RECALIBRATION/${sName}.recal.bam  ${oPath}/${sName}/REALIGNMENT/${sName}.local_realigned.sorted
${samtoolsPath} index ${oPath}/${sName}/REALIGNMENT/${sName}.local_realigned.sorted.bam




## Data process 4. GATK variant haplotype calling 
echo "## Run GATK HaplotypeCaller ##" 

${gatkPath} --java-options "-Xmx8g" HaplotypeCaller -R ${shellPath}/reference/hg19/hg19.fasta -I ${oPath}/${sName}/REALIGNMENT/${sName}.local_realigned.sorted.bam -O ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.g.vcf -ERC GVCF  -bamout ${oPath}/${sName}/REALIGNMENT/${sName}.HaplotypeCaller.bam
${gatkPath} --java-options "-Xmx4g" GenotypeGVCFs -R ${shellPath}/reference/hg19/hg19.fasta --variant ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.g.vcf -O ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.vcf

${gatkPath} SelectVariants -R ${shellPath}/reference/hg19/hg19.fasta -V ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.vcf -select-type SNP -O ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.snp.vcf
${gatkPath} VariantFiltration -R ${shellPath}/reference/hg19/hg19.fasta -V ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.snp.vcf --filter-expression "QD < 2.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0" --filter-name "snp_filter" -O ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.snp.mark.vcf

${gatkPath} SelectVariants -R ${shellPath}/reference/hg19/hg19.fasta -V ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.vcf -select-type INDEL -O ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.indel.vcf
${gatkPath} VariantFiltration -R ${shellPath}/reference/hg19/hg19.fasta -V ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.indel.vcf --filter-expression "QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0" --filter-name "indel_filter" -O ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.indel.mark.vcf

${gatkPath} MergeVcfs -I ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.snp.mark.vcf -I ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.indel.mark.vcf -O ${oPath}/${sName}/${sName}.GATK.HaplotypeCaller.mark.vcf
