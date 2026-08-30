\bcftools view \
    -i 'GT="1/1" && QUAL>=30 && FMT/DP>=10' \
    -O v \
    -o pwk_dsnp.vcf \
    ../reference/PWK_PhJ.mgp.v5.snps.dbSNP142.vcf.gz


