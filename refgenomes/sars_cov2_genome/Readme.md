Covid 19 genome files
Data sources:
gff file: https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/858/895/GCF_009858895.2_ASM985889v3/GCF_009858895.2_ASM985889v3_genomic.gff.gz
fasta file: https://www.ncbi.nlm.nih.gov/nuccore/NC_045512.2?report=fasta
To convert the gff file to gtf, the tool gffread (https://github.com/gpertea/gffread) was used.
The gtf was filtered by gene entries and the entries were renamed to "exons", the transcript_id was set to the gene_id and an exon_number field was added.
Additionally, pseudogenes were added using the antisense strand and these were denoted by adding "-minus" to the gene_id.
These additional exons entries were then concatenated to the original gtf file.
Acknowledgments: We thank Meshal Ansari for providing the files.
