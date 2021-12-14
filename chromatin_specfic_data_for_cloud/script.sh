# blacklist slop

blacklist_region=/mnt/data/annotations/blacklist/GRch38/GRch38_unified_blacklist.bed.gz
chrom_sizes=/mnt/data/annotations/by_release/hg38/hg38.chrom.sizes
flank_size=1057

bedtools slop -i $blacklist_region -g $chrom_sizes -b $flank_size > blacklist_slop1057.bed


